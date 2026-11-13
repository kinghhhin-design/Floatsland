import AppKit

/// 无边框、非激活、置顶的悬浮面板。
final class IslandPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

/// 每个显示器一个面板控制器，负责展开/收起动画与位置。
final class IslandPanelController: NSObject, NSWindowDelegate {
    let panel: IslandPanel
    let rootView: IslandRootView
    weak var manager: IslandManager?

    private(set) var screenNumber: NSNumber
    private(set) var isExpanded = false
    private(set) var isHovered = false
    private var transitionTimer: Timer?

    init(screen: NSScreen) {
        screenNumber = IslandMetrics.screenNumber(screen)
        panel = IslandPanel(contentRect: IslandMetrics.pillFrame(for: screen),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        rootView = IslandRootView(frame: NSRect(origin: .zero, size: IslandMetrics.pillSize))
        super.init()

        panel.contentView = rootView
        panel.delegate = self

        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Disable the window-server shadow/rim as well as the view border.
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isRestorable = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        panel.onEscape = { [weak self] in self?.collapse() }

        rootView.onPillClick = { [weak self] in
            guard let self else { return }
            self.manager?.togglePanel(self)
        }
        rootView.onHoverChange = { [weak self] hovered in
            guard let self else { return }
            self.isHovered = hovered
            self.manager?.panelHoverChanged(self, hovered: hovered)
        }
        rootView.shouldAcceptDrop = { [weak self] in
            (self?.manager?.outDragSessions ?? 0) == 0
        }
        rootView.onDragEntered = { [weak self] in
            guard let self else { return }
            self.manager?.dropEntered(self)
        }
        rootView.onDragExited = { [weak self] in
            self?.manager?.dropExited()
        }
        rootView.onDropURLs = { [weak self] urls -> Bool in
            guard let self, let manager = self.manager else { return false }
            let added = manager.shelf.add(urls: urls)
            if added > 0 {
                manager.dismissAfterDrop(self)
                return true
            }
            NSSound.beep()
            return false
        }
        rootView.onDropText = { [weak self] text -> Bool in
            guard let self, let manager = self.manager else { return false }
            let added = manager.shelf.add(text: text)
            if added > 0 {
                manager.dismissAfterDrop(self)
                return true
            }
            NSSound.beep()
            return false
        }

        let expanded = rootView.expandedView
        expanded.onClear = { [weak self] in self?.manager?.shelf.clear() }
        expanded.onCollapseClick = { [weak self] in
            guard let self else { return }
            self.manager?.togglePanel(self)
        }
        expanded.onRemoveItem = { [weak self] id in self?.manager?.shelf.remove(id: id) }
        expanded.onRevealItem = { [weak self] id in
            guard let self, let manager = self.manager else { return }
            if let item = manager.shelf.items.first(where: { $0.id == id }),
               let url = item.url {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        expanded.onCopyTextItem = { [weak self] id in
            guard let self, let manager = self.manager else { return }
            if let item = manager.shelf.items.first(where: { $0.id == id }),
               let text = item.text {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
            }
        }
        expanded.onDragStart = { [weak self] _ in self?.manager?.dragOutStarted() }
        expanded.onDragEnd = { [weak self] items, op in
            self?.manager?.dragOutEnded(operation: op, items: items)
        }

        reposition()
        panel.orderFrontRegardless()
    }

    // MARK: - 展开 / 收起

    func expand(animated: Bool = true) {
        guard !isExpanded else { return }
        isExpanded = true
        panel.level = .popUpMenu
        transition(expanded: true, animated: animated)
    }

    func collapse(animated: Bool = true) {
        guard isExpanded else { return }
        isExpanded = false
        panel.level = .statusBar
        transition(expanded: false, animated: animated)
    }

    private func transition(expanded: Bool, animated: Bool) {
        transitionTimer?.invalidate()
        let start = panel.frame
        let end = frameForCurrentScreen(expanded: expanded)
        rootView.setExpanded(expanded)
        rootView.setCornerRadius(expanded ? IslandMetrics.expandedCorner : IslandMetrics.collapsedCorner,
                                 animated: animated, squareTop: touchesScreenTop(end))
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(end, display: true)
            return
        }
        let began = ProcessInfo.processInfo.systemUptime
        let duration = expanded ? 0.40 : 0.32
        let fps = max(60, min(currentScreen()?.maximumFramesPerSecond ?? 60, 120))
        let timer = Timer(timeInterval: 1.0 / Double(fps), repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let progress = min(1, (ProcessInfo.processInfo.systemUptime - began) / duration)
            let eased = 1 - pow(1 - progress, 4)
            let frame = NSRect(x: start.minX + (end.minX - start.minX) * eased,
                               y: start.minY + (end.minY - start.minY) * eased,
                               width: start.width + (end.width - start.width) * eased,
                               height: start.height + (end.height - start.height) * eased)
            self.panel.setFrame(frame, display: true)
            if progress >= 1 { timer.invalidate(); self.transitionTimer = nil }
        }
        transitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func showDropConfirmation() {
        rootView.expandedView.showDropConfirmation()
    }

    // MARK: - 位置

    private func currentScreen() -> NSScreen? {
        NSScreen.screens.first { IslandMetrics.screenNumber($0) == screenNumber }
    }

    private func frameForCurrentScreen(expanded: Bool) -> NSRect {
        guard let screen = currentScreen() else { return panel.frame }
        return expanded ? IslandMetrics.expandedFrame(for: screen) : IslandMetrics.pillFrame(for: screen)
    }

    private func touchesScreenTop(_ frame: NSRect) -> Bool {
        guard let screen = currentScreen() else { return false }
        return frame.maxY >= screen.frame.maxY - 0.5
    }

    func reposition() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        panel.setFrame(frameForCurrentScreen(expanded: isExpanded), display: true)
        // 尺寸设置变化时同步更新圆角
        rootView.setCornerRadius(isExpanded ? IslandMetrics.expandedCorner : IslandMetrics.collapsedCorner,
                                 animated: false,
                                 squareTop: touchesScreenTop(panel.frame))
    }

    func showPanel() {
        panel.orderFrontRegardless()
    }

    func hidePanel() {
        panel.orderOut(nil)
    }

    func closePanel() {
        transitionTimer?.invalidate()
        panel.close()
    }
}
