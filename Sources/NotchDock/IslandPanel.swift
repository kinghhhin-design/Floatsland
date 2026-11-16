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
    private var transitionTimer: AnimationClock?

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
        expanded.onOpenItem = { [weak self] id in
            guard let self, let manager = self.manager,
                  let url = manager.shelf.items.first(where: { $0.id == id })?.url else { return }
            if !NSWorkspace.shared.open(url) { NSSound.beep() }
        }
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
        let startOpacity = rootView.expandedView.alphaValue
        let endOpacity: CGFloat = expanded ? 1 : 0
        let startCorner = rootView.layer?.cornerRadius ?? IslandMetrics.collapsedCorner
        let endCorner = expanded ? IslandMetrics.expandedCorner : IslandMetrics.collapsedCorner
        let squareTop = touchesScreenTop(end)
        rootView.setExpanded(expanded)
        let contentFrame = frameForCurrentScreen(expanded: true)
        rootView.prepareTransition(contentSize: contentFrame.size, screenFrame: contentFrame)
        let backingScale = currentScreen()?.backingScaleFactor ?? 2
        let apply: (CGFloat, CGFloat, Bool) -> Void = { [weak self] progress, opacityProgress, finished in
            guard let self else { return }
            let interpolated = NSRect(x: start.minX + (end.minX - start.minX) * progress,
                               y: start.minY + (end.minY - start.minY) * progress,
                               width: start.width + (end.width - start.width) * progress,
                               height: start.height + (end.height - start.height) * progress)
            // Commit window geometry, content positioning and visual state together.
            // Drawing before repositioning content can expose a stale text position.
            func pixel(_ value: CGFloat) -> CGFloat { (value * backingScale).rounded() / backingScale }
            let frame = NSRect(x: pixel(interpolated.minX), y: pixel(interpolated.minY),
                               width: pixel(interpolated.maxX) - pixel(interpolated.minX),
                               height: pixel(interpolated.maxY) - pixel(interpolated.minY))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if self.panel.frame != frame {
                self.panel.setFrame(frame, display: false)
                self.rootView.needsLayout = true
                self.rootView.layoutSubtreeIfNeeded()
            }
            self.rootView.applyTransition(
                opacity: startOpacity + (endOpacity - startOpacity) * opacityProgress,
                cornerRadius: startCorner + (endCorner - startCorner) * progress,
                squareTop: squareTop, finished: finished)
            self.rootView.layoutSubtreeIfNeeded()
            self.rootView.displayIfNeeded()
            CATransaction.commit()
        }
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            transitionTimer = nil
            apply(1, 1, true)
            return
        }
        let began = ProcessInfo.processInfo.systemUptime
        // Overlap the fade with the silhouette animation; the content itself
        // keeps its full-size layout while its composited layers gently scale in.
        let configuredDuration = expanded ? AppSettings.shared.expandAnimationDuration
                                          : AppSettings.shared.collapseAnimationDuration
        let geometryDuration: Double = start == end ? 0 : configuredDuration * (expanded ? 0.80 : 1)
        let fadeDuration: Double = abs(endOpacity - startOpacity) < 0.001 ? 0 : configuredDuration * (expanded ? 1 : 0.75)
        let duration = max(geometryDuration, fadeDuration)
        func phase(_ elapsed: Double, length: Double) -> Double {
            length > 0 ? min(1, max(0, elapsed / length)) : 1
        }
        transitionTimer = AnimationClock(displayID: screenNumber.uint32Value,
                                         fallbackFPS: currentScreen()?.maximumFramesPerSecond ?? 60) { [weak self] in
            guard let self else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - began
            let geometry = IslandAnimationCurve.geometry(phase(elapsed, length: geometryDuration))
            let opacity = IslandAnimationCurve.opacity(phase(elapsed, length: fadeDuration))
            let finished = elapsed >= duration
            apply(geometry, opacity, finished)
            if finished {
                self.transitionTimer?.invalidate()
                self.transitionTimer = nil
            }
        }
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

    /// Use stable interaction bounds as well as the animated window, including
    /// screen-top edges that NSRect.contains otherwise treats as outside.
    func containsPointer(_ point: NSPoint) -> Bool {
        guard panel.isVisible else { return false }
        var regions = [panel.frame, frameForCurrentScreen(expanded: false)]
        if isExpanded { regions.append(frameForCurrentScreen(expanded: true)) }
        let tolerance = 1 / (currentScreen()?.backingScaleFactor ?? 2)
        return regions.contains { rect in
            point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance &&
            point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
        }
    }

    private func touchesScreenTop(_ frame: NSRect) -> Bool {
        guard let screen = currentScreen() else { return false }
        return frame.maxY >= screen.frame.maxY - 0.5
    }

    func reposition() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        panel.setFrame(frameForCurrentScreen(expanded: isExpanded), display: true)
        rootView.applyTransition(opacity: isExpanded ? 1 : 0,
                                 cornerRadius: isExpanded ? IslandMetrics.expandedCorner : IslandMetrics.collapsedCorner,
                                 squareTop: touchesScreenTop(panel.frame), finished: true)
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
