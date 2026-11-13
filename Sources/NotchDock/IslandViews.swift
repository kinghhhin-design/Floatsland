import AppKit

// MARK: - 窗口根视图（同时是文件的拖入目标）

final class IslandRootView: NSView {
    var onPillClick: (() -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var shouldAcceptDrop: (() -> Bool)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDropURLs: (([URL]) -> Bool)?
    var onDropText: ((String) -> Bool)?

    let pillView = PillView()
    let expandedView = ExpandedView()

    private var expanded = false

    var shelfCount: Int = 0 {
        didSet { pillView.count = shelfCount }
    }
    var shelfItems: [ShelfStore.Item] = [] {
        didSet { expandedView.items = shelfItems }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.borderWidth = 1
        layer?.allowsEdgeAntialiasing = false
        layer?.edgeAntialiasingMask = []
        layer?.borderColor = NSColor.black.cgColor
        layer?.cornerRadius = IslandMetrics.collapsedCorner

        pillView.frame = bounds
        expandedView.frame = bounds
        addSubview(pillView)
        addSubview(expandedView)
        expandedView.alphaValue = 0
        expandedView.isHidden = true

        pillView.onClick = { [weak self] in self?.onPillClick?() }
        pillView.onHoverChange = { [weak self] hovered in self?.onHoverChange?(hovered) }

        registerForDraggedTypes([.fileURL, .string])
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        pillView.frame = bounds
        expandedView.frame = bounds
    }

    func setExpanded(_ flag: Bool) {
        expanded = flag
        if flag {
            expandedView.isHidden = false
        } else {
            pillView.isHidden = false
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            pillView.animator().alphaValue = flag ? 0 : 1
            expandedView.animator().alphaValue = flag ? 1 : 0
        }, completionHandler: { [weak self] in
            guard let self, self.expanded == flag else { return }
            self.pillView.isHidden = flag
            self.expandedView.isHidden = !flag
        })
    }

    /// 设置圆角；squareTop = true 时上方两个角为直角（展开面板贴屏幕顶部）。
    func setCornerRadius(_ r: CGFloat, animated: Bool, squareTop: Bool) {
        guard let layer else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let anim = CABasicAnimation(keyPath: "cornerRadius")
            anim.fromValue = layer.cornerRadius
            anim.toValue = r
            anim.duration = 0.32
            anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            layer.add(anim, forKey: "cornerRadius")
        }
        layer.cornerRadius = r
        layer.maskedCorners = squareTop
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }

    func reload() {
        pillView.count = shelfCount
        expandedView.items = shelfItems
    }

    // Keep the original capsule's central header area clickable while expanded.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let halfWidth = max(20, min(IslandMetrics.pillSize.width / 2, bounds.width / 2 - 110))
        if expanded, local.y >= bounds.height - 38, local.y <= bounds.height,
           abs(local.x - bounds.midX) <= halfWidth { return self }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        onPillClick?()
    }

    // MARK: 悬停（用于收起判定）

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    // MARK: 拖入目标（从访达拖文件、或从其他应用拖选中文字，暂存到小岛）

    private func hasAcceptableTypes(_ sender: NSDraggingInfo) -> Bool {
        guard let types = sender.draggingPasteboard.types else { return false }
        return types.contains(.fileURL) || types.contains(.string)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard shouldAcceptDrop?() ?? true else { return [] }
        guard hasAcceptableTypes(sender) else { return [] }
        layer?.borderColor = NSColor.black.cgColor
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard shouldAcceptDrop?() ?? true else { return [] }
        return hasAcceptableTypes(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.black.cgColor
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = NSColor.black.cgColor
        let pb = sender.draggingPasteboard
        // 文件优先
        let objects = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true])
        let urls = (objects as? [NSURL])?.map { $0 as URL } ?? []
        if !urls.isEmpty {
            return onDropURLs?(urls) ?? false
        }
        // 文本
        if let text = pb.string(forType: .string), !text.isEmpty {
            return onDropText?(text) ?? false
        }
        return false
    }
}

// MARK: - 收起状态的胶囊（刘海形状）

final class PillView: NSView {
    var onClick: (() -> Void)?
    var onHoverChange: ((Bool) -> Void)?

    var count: Int = 0 {
        didSet { needsLayout = true }
    }

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var hovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byClipping
        addSubview(label)

        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
        setAccessibilityElement(true)
        setAccessibilityLabel(L("浮屿"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        // The collapsed island is an uninterrupted black silhouette, even with stored items.
        iconView.isHidden = true
        label.isHidden = true
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.black.cgColor
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

// MARK: - 展开后的面板

final class ExpandedView: NSView {
    var onClear: (() -> Void)?
    var onCollapseClick: (() -> Void)?
    var onRemoveItem: ((UUID) -> Void)?
    var onRevealItem: ((UUID) -> Void)?
    var onCopyTextItem: ((UUID) -> Void)?
    var onDragStart: (([ShelfStore.Item]) -> Void)?
    var onDragEnd: (([ShelfStore.Item], NSDragOperation) -> Void)?

    var items: [ShelfStore.Item] = [] {
        didSet { rebuildRows() }
    }

    private var selection: Set<UUID> = []
    private var selectionAnchor: Int?
    private var bandBaseSelection: Set<UUID> = []
    private let rowHeight: CGFloat = 48

    private let titleIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Floatsland")
    private let countLabel = NSTextField(labelWithString: "")
    private let clearButton = NSButton(title: L("清空"), target: nil, action: nil)
    private let selectAllButton = NSButton(title: L("全选"), target: nil, action: nil)
    private let collapseButton = NSButton()
    private let hintLabel = NSTextField(labelWithString: L("拖入暂存  ·  拖出复制  ·  ⌘ 拖出移动"))
    private let scrollView = NSScrollView()
    private let listContainer = ListContainerView()
    private let emptyState = EmptyStateView()

    private var rows: [ItemRowView] = []
    private var lastListWidth: CGFloat = 0
    private var confirmationReset: DispatchWorkItem?

    func showDropConfirmation() {
        confirmationReset?.cancel()
        // Only the existing footer text changes; no layer transform or layout animation.
        hintLabel.stringValue = L("✓ 已暂存")
        hintLabel.textColor = .systemMint
        let reset = DispatchWorkItem { [weak self] in
            self?.hintLabel.stringValue = L("拖入暂存  ·  拖出复制  ·  ⌘ 拖出移动")
            self?.hintLabel.textColor = NSColor.white.withAlphaComponent(0.38)
        }
        confirmationReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: reset)
    }


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        titleIcon.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill",
                                  accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        titleIcon.contentTintColor = .white
        addSubview(titleIcon)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        countLabel.font = .systemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        addSubview(countLabel)

        clearButton.target = self
        clearButton.action = #selector(clearClicked)
        clearButton.isBordered = false
        clearButton.font = .systemFont(ofSize: 11)
        clearButton.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        clearButton.setAccessibilityLabel(L("清空暂存"))
        addSubview(clearButton)

        selectAllButton.target = self
        selectAllButton.action = #selector(selectAllClicked)
        selectAllButton.isBordered = false
        selectAllButton.font = .systemFont(ofSize: 11)
        selectAllButton.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        selectAllButton.setAccessibilityLabel(L("全选"))
        addSubview(selectAllButton)

        collapseButton.target = self
        collapseButton.action = #selector(collapseClicked)
        collapseButton.isBordered = false
        collapseButton.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: L("收起"))?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        collapseButton.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        collapseButton.setAccessibilityLabel(L("收起"))
        addSubview(collapseButton)

        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.38)
        hintLabel.alignment = .center
        addSubview(hintLabel)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = listContainer
        addSubview(scrollView)

        listContainer.onBandSelectStart = { [weak self] point, extend in
            self?.bandStart(point, extend: extend)
        }
        listContainer.onBandSelectUpdate = { [weak self] rect in
            self?.bandUpdate(rect)
        }
        listContainer.onBandSelectEnd = { [weak self] in
            self?.bandEnd()
        }

        addSubview(emptyState)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let W = bounds.width
        let H = bounds.height
        let topBarY = H - 38 // 顶部工具栏区域
        let dividerY = H - 40

        titleIcon.frame = NSRect(x: 14, y: topBarY + (28 - 14) / 2, width: 14, height: 14)

        titleLabel.sizeToFit()
        titleLabel.frame = NSRect(x: 32, y: topBarY + (28 - titleLabel.frame.height) / 2,
                                  width: titleLabel.frame.width, height: titleLabel.frame.height)

        // Keep the localized item count below the content, outside the hardware notch.
        countLabel.alignment = .left
        countLabel.frame = NSRect(x: 12, y: 26, width: W - 24, height: 16)

        collapseButton.frame = NSRect(x: W - 26, y: topBarY + (28 - 16) / 2, width: 16, height: 16)

        clearButton.sizeToFit()
        clearButton.frame = NSRect(x: W - 26 - 8 - clearButton.frame.width,
                                   y: topBarY + (28 - clearButton.frame.height) / 2,
                                   width: clearButton.frame.width, height: clearButton.frame.height)

        selectAllButton.sizeToFit()
        selectAllButton.frame = NSRect(x: clearButton.frame.minX - 8 - selectAllButton.frame.width,
                                       y: topBarY + (28 - selectAllButton.frame.height) / 2,
                                       width: selectAllButton.frame.width, height: selectAllButton.frame.height)

        hintLabel.frame = NSRect(x: 12, y: 6, width: W - 24, height: 14)

        scrollView.frame = NSRect(x: 6, y: 48, width: W - 12, height: max(0, dividerY - 48 - 6))

        emptyState.frame = scrollView.frame

        let w = scrollView.contentSize.width
        if abs(w - lastListWidth) > 1 && !items.isEmpty {
            rebuildRows()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.setFill()
        NSRect(x: 14, y: bounds.height - 41, width: bounds.width - 28, height: 1).fill()
    }

    @objc private func clearClicked() { onClear?() }
    @objc private func collapseClicked() { onCollapseClick?() }

    /// 全选按钮：全部选中时再点一下 = 取消全选。
    @objc private func selectAllClicked() {
        if selection.count == items.count, !items.isEmpty {
            selection.removeAll()
        } else {
            selection = Set(items.map { $0.id })
        }
        selectionAnchor = nil
        applySelection()
    }

    private func rebuildRows() {
        rows.forEach { $0.removeFromSuperview() }
        rows = []

        let width = max(scrollView.contentSize.width, 200)
        lastListWidth = scrollView.contentSize.width
        // 高度至少占满可视区域，保证空白处也能拖拽框选
        let neededHeight = max(CGFloat(items.count) * rowHeight,
                               scrollView.contentSize.height)
        listContainer.frame = NSRect(x: 0, y: 0, width: width, height: neededHeight)

        // 清理已不存在条目的选中状态
        selection = selection.filter { id in items.contains(where: { $0.id == id }) }

        for (i, item) in items.enumerated() {
            let row = ItemRowView(frame: NSRect(x: 0, y: CGFloat(i) * rowHeight,
                                                width: width, height: rowHeight),
                                  item: item)
            row.isSelected = selection.contains(item.id)
            row.onRemove = { [weak self] in self?.onRemoveItem?(item.id) }
            row.onReveal = { [weak self] in self?.onRevealItem?(item.id) }
            row.onCopyText = { [weak self] in self?.onCopyTextItem?(item.id) }
            row.onMouseDownRequest = { [weak self] event in
                self?.handleMouseDown(item: item, event: event)
            }
            row.onClickEnd = { [weak self] clicked in
                self?.handleClickEnd(item: clicked)
            }
            row.onRightClickRequest = { [weak self] in
                self?.handleRightClick(item: item)
            }
            row.onSelectAllRequest = { [weak self] in self?.selectAll() }
            row.onClearRequest = { [weak self] in self?.onClear?() }
            row.dragItemsProvider = { [weak self] in
                guard let self else { return [] }
                return self.items.filter { self.selection.contains($0.id) }
            }
            row.onDragStart = { [weak self] dragged in self?.onDragStart?(dragged) }
            row.onDragEnd = { [weak self] dragged, op in self?.onDragEnd?(dragged, op) }
            listContainer.addSubview(row)
            rows.append(row)
        }

        scrollView.documentView = listContainer

        emptyState.isHidden = !items.isEmpty
        scrollView.isHidden = items.isEmpty
        countLabel.stringValue = items.isEmpty ? "" : String(format: L("%d 项"), items.count)
        clearButton.isEnabled = !items.isEmpty
        selectAllButton.isEnabled = !items.isEmpty
        needsDisplay = true
    }

    // MARK: - 多选

    /// 全选所有条目（由“全选”按钮和右键菜单调用）。
    func selectAll() {
        selection = Set(items.map { $0.id })
        selectionAnchor = nil
        applySelection()
    }

    /// 点按行为：普通点=单选，⌘ 点=增删，⇧ 点=范围选择。
    private func handleMouseDown(item: ShelfStore.Item, event: NSEvent) {
        guard let idx = items.firstIndex(of: item) else { return }
        if event.modifierFlags.contains(.command) {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
            selectionAnchor = idx
        } else if event.modifierFlags.contains(.shift), let anchor = selectionAnchor {
            let lo = min(anchor, idx), hi = max(anchor, idx)
            for i in lo...hi where i < items.count {
                selection.insert(items[i].id)
            }
        } else {
            // 已选中时保持多选不变（用户可能要拖出整批）；
            // 单击未选中行才切换为单选，单击后的收起在 mouseUp 时处理。
            if !selection.contains(item.id) {
                selection = [item.id]
                selectionAnchor = idx
            }
        }
        applySelection()
    }

    /// 单击结束（未发生拖拽）：多选状态下收起为单选该行。
    private func handleClickEnd(item: ShelfStore.Item) {
        guard selection.count > 1, selection.contains(item.id) else { return }
        selection = [item.id]
        selectionAnchor = items.firstIndex(of: item)
        applySelection()
    }

    private func applySelection() {
        for (i, item) in items.enumerated() {
            rows[i].isSelected = selection.contains(item.id)
        }
    }

    /// 右键行为：未选中则只选中该行；已选中则保持多选不变。
    private func handleRightClick(item: ShelfStore.Item) {
        if !selection.contains(item.id) {
            selection = [item.id]
            selectionAnchor = items.firstIndex(of: item)
            applySelection()
        }
    }

    // MARK: 空白处拖拽框选

    private func bandStart(_ point: NSPoint, extend: Bool) {
        bandBaseSelection = extend ? selection : []
        selection = bandBaseSelection
        selectionAnchor = nil
        applySelection()
    }

    private func bandUpdate(_ rect: NSRect) {
        var newSelection = bandBaseSelection
        for (i, item) in items.enumerated() {
            let rowRect = NSRect(x: 0, y: CGFloat(i) * rowHeight,
                                 width: listContainer.bounds.width, height: rowHeight)
            if rect.intersects(rowRect) {
                newSelection.insert(item.id)
            }
        }
        selection = newSelection
        applySelection()
    }

    private func bandEnd() {
        bandBaseSelection = []
        selectionAnchor = items.firstIndex(where: { selection.contains($0.id) })
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        // 点击面板空白处取消选择
        if !selection.isEmpty {
            selection.removeAll()
            selectionAnchor = nil
            applySelection()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let selectAllItem = NSMenuItem(title: L("全选"), action: #selector(ctxSelectAll), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        let deselectItem = NSMenuItem(title: L("取消全选"), action: #selector(ctxDeselect), keyEquivalent: "")
        deselectItem.target = self
        menu.addItem(deselectItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: L("清空暂存"), action: #selector(ctxClear), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    @objc private func ctxSelectAll() { selectAll() }
    @objc private func ctxDeselect() {
        selection.removeAll()
        selectionAnchor = nil
        applySelection()
    }
    @objc private func ctxClear() { onClear?() }
}

// MARK: - 暂存条目行（支持拖出、双击定位、移除）

final class ItemRowView: NSView, NSDraggingSource {
    let item: ShelfStore.Item
    var isSelected = false {
        didSet { applyVisuals() }
    }
    var onRemove: (() -> Void)?
    var onReveal: (() -> Void)?
    var onCopyText: (() -> Void)?
    var onMouseDownRequest: ((NSEvent) -> Void)?
    var onClickEnd: ((ShelfStore.Item) -> Void)?
    var onRightClickRequest: (() -> Void)?
    var onSelectAllRequest: (() -> Void)?
    var onClearRequest: (() -> Void)?
    var dragItemsProvider: (() -> [ShelfStore.Item])?
    var onDragStart: (([ShelfStore.Item]) -> Void)?
    var onDragEnd: (([ShelfStore.Item], NSDragOperation) -> Void)?

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let removeButton = NSButton()
    private var hovered = false
    private var downLocation: NSPoint?
    private var lastDraggedItems: [ShelfStore.Item] = []

    init(frame frameRect: NSRect, item: ShelfStore.Item) {
        self.item = item
        super.init(frame: frameRect)
        wantsLayer = true

        if let url = item.url {
            iconView.image = NSWorkspace.shared.icon(forFile: url.path)
            nameLabel.stringValue = url.lastPathComponent
            nameLabel.toolTip = url.path
            removeButton.setAccessibilityLabel(String(format: L("移除 %@"), url.lastPathComponent))
        } else if let text = item.text {
            iconView.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
            iconView.contentTintColor = .white
            let oneLine = text.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            nameLabel.stringValue = oneLine.isEmpty ? L("(空白)") : oneLine
            nameLabel.toolTip = text
            removeButton.setAccessibilityLabel(L("移除文本"))
        }
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(nameLabel)

        removeButton.isBordered = false
        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                     accessibilityDescription: L("移除"))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        removeButton.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        removeButton.target = self
        removeButton.action = #selector(removeClicked)
        removeButton.alphaValue = 0
        addSubview(removeButton)

        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(x: 12, y: (bounds.height - 26) / 2, width: 26, height: 26)
        nameLabel.frame = NSRect(x: 46, y: (bounds.height - 18) / 2,
                                 width: bounds.width - 46 - 34, height: 18)
        removeButton.frame = NSRect(x: bounds.width - 28, y: (bounds.height - 18) / 2,
                                    width: 18, height: 18)
    }

    private func applyVisuals() {
        if isSelected {
            layer?.backgroundColor = NSColor(calibratedWhite: 0.23, alpha: 1.0).cgColor
        } else if hovered {
            layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        layer?.cornerRadius = 10
        layer?.borderWidth = isSelected ? 0.5 : 0
        layer?.borderColor = NSColor.black.cgColor
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        applyVisuals()
        removeButton.animator().alphaValue = 1
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        applyVisuals()
        removeButton.animator().alphaValue = 0
    }

    @objc private func removeClicked() {
        onRemove?()
    }

    // MARK: 右键：选中 + 弹出菜单

    override func rightMouseDown(with event: NSEvent) {
        window?.makeKey()
        onRightClickRequest?()
        showContextMenu(with: event)
    }

    private func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()

        if item.isText {
            let copyItem = NSMenuItem(title: L("复制文本"), action: #selector(menuCopyText), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)
        } else {
            let revealItem = NSMenuItem(title: L("在访达中显示"), action: #selector(menuReveal), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
        }

        let removeItem = NSMenuItem(title: L("移除"), action: #selector(menuRemove), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(.separator())

        let selectAllItem = NSMenuItem(title: L("全选"), action: #selector(menuSelectAll), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        let clearItem = NSMenuItem(title: L("清空暂存"), action: #selector(menuClear), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    @objc private func menuReveal() { onReveal?() }
    @objc private func menuCopyText() { onCopyText?() }
    @objc private func menuRemove() { onRemove?() }
    @objc private func menuSelectAll() { onSelectAllRequest?() }
    @objc private func menuClear() { onClearRequest?() }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        downLocation = convert(event.locationInWindow, from: nil)
        onMouseDownRequest?(event)
        if event.clickCount == 2 {
            // 文件双击 = 在访达中显示；文本双击 = 复制到剪贴板
            if item.isText {
                onCopyText?()
            } else {
                onReveal?()
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = downLocation else { return }
        let p = convert(event.locationInWindow, from: nil)
        guard abs(p.x - down.x) > 3 || abs(p.y - down.y) > 3 else { return }
        downLocation = nil
        startDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        // 未发生拖拽（downLocation 仍在）说明是单击，通知上层收起多选
        if downLocation != nil && event.modifierFlags.intersection([.command, .shift]).isEmpty {
            onClickEnd?(item)
        }
        downLocation = nil
    }

    private func startDrag(with event: NSEvent) {
        // 多选时：从任一选中行拖出 = 一次性拖走所有选中项
        var items: [ShelfStore.Item]
        if isSelected {
            let provided = dragItemsProvider?() ?? []
            items = provided.count > 1 ? provided : [item]
        } else {
            items = [item]
        }
        // 过滤失效的文件条目（文本始终有效）
        let valid = items.filter { it in
            if let url = it.url {
                return FileManager.default.fileExists(atPath: url.path)
            }
            return true
        }
        guard !valid.isEmpty else {
            NSSound.beep()
            return
        }

        let pointer = convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (i, it) in valid.enumerated() {
            let writer: NSPasteboardWriting
            let icon: NSImage
            if let url = it.url {
                writer = url as NSURL
                icon = NSWorkspace.shared.icon(forFile: url.path).copy() as! NSImage
            } else {
                writer = (it.text ?? "") as NSString
                icon = DragPreview.textImage()
            }
            let previewSize = it.isText ? NSSize(width: 36, height: 36) : NSSize(width: 28, height: 28)
            icon.size = previewSize
            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            draggingItem.setDraggingFrame(DragPreview.frame(at: pointer, size: previewSize,
                                                            index: i, flipped: isFlipped),
                                          contents: icon)
            draggingItems.append(draggingItem)
        }

        lastDraggedItems = valid
        onDragStart?(valid)
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        // Preserve our cursor-relative offsets instead of letting AppKit re-stack them.
        session.draggingFormation = .none
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // 中转站语义：默认“复制”（原文件保留在文件夹1）；
        // 按住 ⌘ 再拖出时才允许“移动”。
        if NSEvent.modifierFlags.contains(.command) {
            return [.copy, .move]
        }
        return [.copy]
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        onDragEnd?(lastDraggedItems, operation)
        lastDraggedItems = []
    }
}

// MARK: - 空状态视图

final class EmptyStateView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: L("让文件在这里停留片刻"))
    private let subtitleLabel = NSTextField(labelWithString: L("拖入文件、文件夹或文字 · 随时带到下一处"))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill",
                                 accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 26, weight: .regular))
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.86)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.48)
        subtitleLabel.alignment = .center
        addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let W = bounds.width
        iconView.frame = NSRect(x: (W - 30) / 2, y: bounds.height / 2 + 18, width: 30, height: 30)
        titleLabel.frame = NSRect(x: 16, y: bounds.height / 2 - 14, width: W - 32, height: 18)
        subtitleLabel.frame = NSRect(x: 16, y: bounds.height / 2 - 34, width: W - 32, height: 15)
    }
}

// MARK: - 列表容器（从上往下排，支持空白处拖拽框选）

final class ListContainerView: NSView {
    override var isFlipped: Bool { true }

    /// 框选回调：开始（点 + 是否 ⌘ 扩展）/ 更新（框矩形）/ 结束。
    var onBandSelectStart: ((NSPoint, Bool) -> Void)?
    var onBandSelectUpdate: ((NSRect) -> Void)?
    var onBandSelectEnd: (() -> Void)?

    private var bandStartPoint: NSPoint?
    private var isBanding = false
    private let bandLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        bandLayer.fillColor = NSColor.white.withAlphaComponent(0.10).cgColor
        bandLayer.strokeColor = NSColor.black.cgColor
        bandLayer.lineWidth = 1
        layer?.addSublayer(bandLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        bandStartPoint = p
        isBanding = true
        onBandSelectStart?(p, event.modifierFlags.contains(.command))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isBanding, let start = bandStartPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        let rect = NSRect(x: min(start.x, p.x),
                          y: min(start.y, p.y),
                          width: abs(p.x - start.x),
                          height: abs(p.y - start.y))
        bandLayer.path = CGPath(rect: rect, transform: nil)
        onBandSelectUpdate?(rect)
    }

    override func mouseUp(with event: NSEvent) {
        guard isBanding else { return }
        isBanding = false
        bandStartPoint = nil
        bandLayer.path = nil
        onBandSelectEnd?()
    }
}
