import AppKit

/// 核心协调器：管理所有显示器上的小岛、展开/收起状态机、拖入/拖出。
final class IslandManager {
    let shelf = ShelfStore()
    let settings = AppSettings.shared

    private(set) var outDragSessions = 0

    private var controllers: [NSNumber: IslandPanelController] = [:]
    private let tracker = MouseTracker()
    private let previewWindow = ZonePreviewWindow()
    private var dropActive = false
    private var manuallyCollapsed = Set<NSNumber>()
    private var collapseWorkItem: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private(set) var visible = true

    init() {
        shelf.onChange = { [weak self] in self?.refreshAll() }

        let settingsObs = NotificationCenter.default.addObserver(
            forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
                self?.applySettings()
            }
        let screensObs = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.repositionAll()
            }
        let languageObs = NotificationCenter.default.addObserver(
            forName: .languageChanged, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                let expanded = Set(self.controllers.values.filter { $0.isExpanded }.map { $0.screenNumber })
                self.controllers.values.forEach { $0.closePanel() }
                self.controllers.removeAll()
                self.rebuildPanels()
                self.refreshAll()
                for controller in self.controllers.values where expanded.contains(controller.screenNumber) {
                    controller.expand(animated: false)
                }
                if !self.settings.islandVisible { self.hideAll() }
                self.previewWindow.contentView?.needsDisplay = true
            }
        observers = [settingsObs, screensObs, languageObs]
    }

    func start() {
        rebuildPanels()
        tracker.onStateChange = { [weak self] state in self?.zoneStateChanged(state) }
        tracker.containsPanel = { [weak self] point in
            self?.controllers.values.contains { $0.panel.isVisible && $0.panel.frame.contains(point) } ?? false
        }
        tracker.start()
        installOutsideClickMonitors()
        if settings.islandVisible {
            showAll()
        } else {
            hideAll()
        }
        refreshAll()
        updatePreview()
    }

    // Observe mouse clicks without consuming the click intended for another app.
    private func installOutsideClickMonitors() {
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            self?.dismissForOutsideClick(at: NSEvent.mouseLocation)
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            guard let self else { return event }
            // Clicks on our panel (including controls) must continue to be handled normally.
            if !self.controllers.values.contains(where: { $0.panel === event.window }) {
                self.dismissForOutsideClick(at: NSEvent.mouseLocation)
            }
            return event
        }
    }

    private func dismissForOutsideClick(at point: NSPoint) {
        guard outDragSessions == 0,
              !controllers.values.contains(where: { $0.panel.isVisible && $0.panel.frame.contains(point) }) else { return }
        cancelPendingCollapse()
        dropActive = false
        for controller in controllers.values where controller.isExpanded {
            manuallyCollapsed.insert(controller.screenNumber)
            controller.collapse()
        }
    }

    deinit {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        collapseWorkItem?.cancel()
        tracker.stop()
    }

    // MARK: - 面板管理

    private func rebuildPanels() {
        let wanted: [NSScreen] = settings.showOnAllScreens
            ? NSScreen.screens
            : [NSScreen.screens.first].compactMap { $0 }

        let wantedNumbers = Set(wanted.map { IslandMetrics.screenNumber($0) })
        for (num, controller) in controllers where !wantedNumbers.contains(num) {
            controller.closePanel()
            controllers.removeValue(forKey: num)
        }
        for screen in wanted {
            let num = IslandMetrics.screenNumber(screen)
            if controllers[num] == nil {
                let controller = IslandPanelController(screen: screen)
                controller.manager = self
                controllers[num] = controller
            }
        }
    }

    func repositionAll() {
        rebuildPanels()
        for controller in controllers.values { controller.reposition() }
        refreshAll()
    }

    func refreshAll() {
        for controller in controllers.values {
            controller.rootView.shelfCount = shelf.items.count
            controller.rootView.shelfItems = shelf.items
        }
    }

    func showAll() {
        for controller in controllers.values {
            controller.showPanel()
        }
    }

    func hideAll() {
        for controller in controllers.values {
            controller.hidePanel()
        }
    }

    func setVisible(_ v: Bool) {
        visible = v
        settings.islandVisible = v
        if v {
            showAll()
        } else {
            hideAll()
        }
    }

    // MARK: - 感应区域状态机

    /// 根据用户的“展开方式”设置决定感应区域内是否自动放大。
    private func shouldAutoExpand(_ state: MouseTracker.ZoneState) -> Bool {
        switch settings.expandMode {
        case 0:  return state.dragActive   // 仅拖拽文件时展开
        case 1:  return true               // 悬停或拖拽时展开
        default: return false              // 仅点击小岛时展开
        }
    }

    private func zoneStateChanged(_ state: MouseTracker.ZoneState) {
        if !state.inZone && !state.inPanel { manuallyCollapsed.removeAll() }
        if state.inZone {
            cancelPendingCollapse()
            if shouldAutoExpand(state), !manuallyCollapsed.contains(state.screenNumber),
               let controller = controllers[state.screenNumber],
               !controller.isExpanded {
                shelf.pruneStale()
                controller.expand()
            }
        } else if state.inPanel {
            cancelPendingCollapse()
        } else {
            scheduleCollapse(delay: settings.collapseDelay)
        }
    }

    func togglePanel(_ controller: IslandPanelController) {
        cancelPendingCollapse()
        if controller.isExpanded {
            manuallyCollapsed.insert(controller.screenNumber)
            controller.collapse()
        } else {
            manuallyCollapsed.remove(controller.screenNumber)
            controller.expand()
        }
    }

    func panelHoverChanged(_ controller: IslandPanelController, hovered: Bool) {
        if hovered {
            cancelPendingCollapse()
            // 拖拽经过小岛时即使关闭了悬停展开也要放大
            if tracker.state.dragActive && !controller.isExpanded && !manuallyCollapsed.contains(controller.screenNumber) {
                shelf.pruneStale()
                controller.expand()
            }
        } else {
            scheduleCollapse(delay: settings.collapseDelay)
        }
    }

    // MARK: - 拖入（暂存）

    func dropEntered(_ controller: IslandPanelController) {
        manuallyCollapsed.remove(controller.screenNumber)
        dropActive = true
        cancelPendingCollapse()
        if !controller.isExpanded {
            shelf.pruneStale()
            controller.expand()
        }
    }

    func dropExited() {
        dropActive = false
    }

    func dismissAfterDrop(_ controller: IslandPanelController) {
        dropActive = false
        controller.showDropConfirmation()
        scheduleCollapse(delay: settings.collapseDelay)
    }

    // MARK: - 拖出（取走）

    func dragOutStarted() {
        outDragSessions += 1
        cancelPendingCollapse()
    }

    func dragOutEnded(operation: NSDragOperation, items: [ShelfStore.Item]) {
        outDragSessions = max(0, outDragSessions - 1)
        if settings.removeAfterDragOut,
           operation.contains(.move) || operation.contains(.copy) {
            // 设置开启了“拖出后自动移除”
            for item in items {
                shelf.remove(id: item.id)
            }
        } else {
            // 默认保留条目；只清理已失效的文件引用（被真正移走/删除）
            for item in items {
                if let url = item.url, !FileManager.default.fileExists(atPath: url.path) {
                    shelf.remove(id: item.id)
                }
                // 文本条目：拖出=复制，始终保留
            }
        }
        scheduleCollapse(delay: settings.collapseDelay)
    }

    // MARK: - 收起调度

    func scheduleCollapse(delay: TimeInterval) {
        guard canCollapseNow() else { return }
        collapseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.canCollapseNow() else { return }
            for controller in self.controllers.values where controller.isExpanded {
                controller.collapse()
            }
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancelPendingCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    func collapseAllNow() {
        cancelPendingCollapse()
        for controller in controllers.values where controller.isExpanded {
            controller.collapse(animated: false)
        }
    }

    private func canCollapseNow() -> Bool {
        guard outDragSessions == 0, !dropActive else { return false }
        let mouse = NSEvent.mouseLocation
        if NSScreen.screens.contains(where: { IslandMetrics.zoneRect(for: $0).contains(mouse) }) { return false }
        if controllers.values.contains(where: { $0.panel.isVisible && $0.panel.frame.contains(mouse) }) { return false }
        return true
    }

    // MARK: - 设置

    func applySettings() {
        if settings.islandVisible != visible {
            setVisible(settings.islandVisible)
        }
        rebuildPanels()
        // 小岛位置等几何设置变化时，实时移动已有面板
        for controller in controllers.values {
            controller.reposition()
        }
        refreshAll()
        updatePreview()
    }

    /// 感应区域虚线预览（跟随设置实时更新位置与大小）。
    private func updatePreview() {
        if settings.previewZone, let screen = NSScreen.screens.first {
            previewWindow.setFrame(IslandMetrics.zoneRect(for: screen), display: true)
            previewWindow.orderFrontRegardless()
        } else {
            previewWindow.orderOut(nil)
        }
    }
}
