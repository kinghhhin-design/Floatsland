import AppKit
import ServiceManagement

// MARK: - 感应区域虚线预览窗口

final class ZonePreviewWindow: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 120, height: 60),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = ZonePreviewView()
    }
}

final class ZonePreviewView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.06).setFill()
        path.fill()
        path.lineWidth = 1.5
        let dash: [CGFloat] = [6, 4]
        path.setLineDash(dash, count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.45).setStroke()
        path.stroke()

        let text = L("感应区域")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                            y: (bounds.height - size.height) / 2),
                                withAttributes: attrs)
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - 设置窗口

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settings = AppSettings.shared

    private var modePopup: NSPopUpButton!
    private var languagePopup: NSPopUpButton!
    private var collapseDelaySlider: NSSlider!
    private var collapseDelayLabel: NSTextField!
    private var heightSlider: NSSlider!
    private var heightLabel: NSTextField!
    private var widthSlider: NSSlider!
    private var widthLabel: NSTextField!
    private var offsetSlider: NSSlider!
    private var offsetLabel: NSTextField!
    private var zoneYSlider: NSSlider!
    private var zoneYLabel: NSTextField!
    private var mergeZoneCheck: NSButton!
    private var islandXSlider: NSSlider!
    private var islandXLabel: NSTextField!
    private var islandYSlider: NSSlider!
    private var islandYLabel: NSTextField!
    private var pillWSlider: NSSlider!
    private var pillWLabel: NSTextField!
    private var pillHSlider: NSSlider!
    private var pillHLabel: NSTextField!
    private var panelWSlider: NSSlider!
    private var panelWLabel: NSTextField!
    private var panelHSlider: NSSlider!
    private var panelHLabel: NSTextField!
    private var previewCheck: NSButton!
    private var screensCheck: NSButton!
    private var loginCheck: NSButton!
    private var removeCheck: NSButton!

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 800),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = L("浮屿设置")
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showSettings() {
        loadValues()
        showWindow(nil)
        if let screen = NSScreen.main, let window {
            window.setContentSize(NSSize(width: 620, height: min(800, screen.visibleFrame.height - 100)))
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // 关闭设置窗口时自动隐藏感应区域预览
        if settings.previewZone {
            settings.previewZone = false
        }
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
        ])

        languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        languagePopup.addItems(withTitles: AppLanguage.allCases.map { $0.nativeName })
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        languagePopup.setAccessibilityLabel(L("语言"))
        stack.addArrangedSubview(labeledRow(rowLabel(L("语言")), languagePopup))

        // 展开方式
        modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        modePopup.addItems(withTitles: [L("仅拖拽文件时展开"), L("悬停或拖拽时展开"), L("仅点击小岛时展开")])
        modePopup.target = self
        modePopup.action = #selector(modeChanged(_:))
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.widthAnchor.constraint(equalToConstant: 300).isActive = true
        stack.addArrangedSubview(labeledRow(rowLabel(L("展开方式")), modePopup))

        // 自动收起延迟
        collapseDelaySlider = makeSlider(min: 0.2, max: 3.0)
        collapseDelaySlider.target = self
        collapseDelaySlider.action = #selector(collapseDelayChanged(_:))
        collapseDelayLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("自动收起延迟")), collapseDelaySlider, collapseDelayLabel))

        // 感应区域标题
        let zoneTitle = NSTextField(labelWithString: L("感应区域（触发放大的范围与位置，实时生效）"))
        zoneTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(zoneTitle)

        // 感应高度
        heightSlider = makeSlider(min: 20, max: 260)
        heightSlider.target = self
        heightSlider.action = #selector(heightChanged(_:))
        heightLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("感应高度")), heightSlider, heightLabel))

        // 感应宽度
        widthSlider = makeSlider(min: 120, max: 800)
        widthSlider.target = self
        widthSlider.action = #selector(widthChanged(_:))
        widthLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("感应宽度")), widthSlider, widthLabel))

        // 感应水平偏移
        offsetSlider = makeSlider(min: -300, max: 300)
        offsetSlider.target = self
        offsetSlider.action = #selector(offsetChanged(_:))
        offsetLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("感应水平偏移")), offsetSlider, offsetLabel))

        // 感应垂直偏移
        zoneYSlider = makeSlider(min: -100, max: 300)
        zoneYSlider.target = self
        zoneYSlider.action = #selector(zoneYChanged(_:))
        zoneYLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("感应垂直偏移")), zoneYSlider, zoneYLabel))

        mergeZoneCheck = NSButton(checkboxWithTitle: L("感应区域与小岛重合（合并）"),
                                  target: self, action: #selector(mergeZoneChanged(_:)))
        stack.addArrangedSubview(mergeZoneCheck)

        previewCheck = NSButton(checkboxWithTitle: L("显示感应区域预览（虚线框）"),
                                target: self, action: #selector(previewChanged(_:)))
        stack.addArrangedSubview(previewCheck)

        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        separator1.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(separator1)

        let sizeTitle = NSTextField(labelWithString: L("小岛大小（实时生效）"))
        sizeTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(sizeTitle)

        // 胶囊宽度
        pillWSlider = makeSlider(min: 80, max: 400)
        pillWSlider.target = self
        pillWSlider.action = #selector(pillWChanged(_:))
        pillWLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("胶囊宽度")), pillWSlider, pillWLabel))

        // 胶囊高度
        pillHSlider = makeSlider(min: 20, max: 60)
        pillHSlider.target = self
        pillHSlider.action = #selector(pillHChanged(_:))
        pillHLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("胶囊高度")), pillHSlider, pillHLabel))

        // 面板宽度
        panelWSlider = makeSlider(min: 320, max: 600)
        panelWSlider.target = self
        panelWSlider.action = #selector(panelWChanged(_:))
        panelWLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("面板宽度")), panelWSlider, panelWLabel))

        // 面板高度
        panelHSlider = makeSlider(min: 200, max: 480)
        panelHSlider.target = self
        panelHSlider.action = #selector(panelHChanged(_:))
        panelHLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("面板高度")), panelHSlider, panelHLabel))

        let islandTitle = NSTextField(labelWithString: L("小岛位置（胶囊与展开面板一起移动，实时生效）"))
        islandTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(islandTitle)

        // 小岛水平偏移
        islandXSlider = makeSlider(min: -400, max: 400)
        islandXSlider.target = self
        islandXSlider.action = #selector(islandXChanged(_:))
        islandXLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("小岛水平偏移")), islandXSlider, islandXLabel))

        // 小岛垂直偏移
        islandYSlider = makeSlider(min: -150, max: 150)
        islandYSlider.target = self
        islandYSlider.action = #selector(islandYChanged(_:))
        islandYLabel = valueLabel()
        stack.addArrangedSubview(labeledRow(rowLabel(L("小岛垂直偏移")), islandYSlider, islandYLabel))
        islandYSlider.toolTip = L("负值向上，可移入刘海区域；正值向下")
        let notchButton = NSButton(title: L("收起时藏入刘海"), target: self, action: #selector(fitInsideNotch))
        notchButton.bezelStyle = .rounded
        notchButton.isEnabled = NSScreen.screens.first.map { IslandMetrics.hasNotch($0) } ?? false
        stack.addArrangedSubview(notchButton)


        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        separator2.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(separator2)

        screensCheck = NSButton(checkboxWithTitle: L("在所有显示器显示小岛"),
                                target: self, action: #selector(screensChanged(_:)))
        stack.addArrangedSubview(screensCheck)

        loginCheck = NSButton(checkboxWithTitle: L("开机自动启动"),
                              target: self, action: #selector(loginChanged(_:)))
        stack.addArrangedSubview(loginCheck)

        removeCheck = NSButton(checkboxWithTitle: L("拖出成功后自动移除条目（默认关：条目保留在小岛）"),
                               target: self, action: #selector(removeAfterDragOutChanged(_:)))
        stack.addArrangedSubview(removeCheck)

        let hint = NSTextField(wrappingLabelWithString: L("把文件拖到感应区域即可放大暂存；点击小岛展开，点击箭头收起。感应范围有虚线预览，小岛位置移动时屏幕上的胶囊会实时跟着动。"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(hint)
    }

    private func rowLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        label.toolTip = text
        return label
    }

    private func valueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 66).isActive = true
        return label
    }

    private func makeSlider(min: Double, max: Double) -> NSSlider {
        let slider = NSSlider(value: 0, minValue: min, maxValue: max, target: nil, action: nil)
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 230).isActive = true
        return slider
    }

    private func labeledRow(_ views: NSView...) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    // MARK: - 事件

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard AppLanguage.allCases.indices.contains(index) else { return }
        let language = AppLanguage.allCases[index]
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Localization.language = language
            self.window?.title = L("浮屿设置")
            self.window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
            self.buildUI()
            self.loadValues()
        }
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        settings.expandMode = sender.indexOfSelectedItem
    }

    @objc private func collapseDelayChanged(_ sender: NSSlider) {
        settings.collapseDelay = sender.doubleValue
        updateLabels()
    }

    @objc private func heightChanged(_ sender: NSSlider) {
        settings.zoneHeight = sender.doubleValue
        updateLabels()
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        settings.zoneHalfWidth = sender.doubleValue / 2
        updateLabels()
    }

    @objc private func offsetChanged(_ sender: NSSlider) {
        settings.zoneOffsetX = sender.doubleValue
        updateLabels()
    }

    @objc private func zoneYChanged(_ sender: NSSlider) {
        settings.zoneOffsetY = sender.doubleValue
        updateLabels()
    }

    @objc private func mergeZoneChanged(_ sender: NSButton) {
        settings.mergeZoneWithIsland = sender.state == .on
        applyMergeState()
    }

    @objc private func islandXChanged(_ sender: NSSlider) {
        settings.islandOffsetX = sender.doubleValue
        updateLabels()
    }

    @objc private func fitInsideNotch() {
        guard let screen = NSScreen.screens.first,
              IslandMetrics.hasNotch(screen),
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return }
        // Inset from the hardware cutout edges to avoid a visible rim.
        settings.pillWidth = max(80, min(400, right.minX - left.maxX - 4))
        settings.pillHeight = max(20, min(60, screen.safeAreaInsets.top - 4))
        settings.islandOffsetX = (left.maxX + right.minX) / 2 - screen.frame.midX
        settings.islandTopMargin = IslandMetrics.topEdge(screen) - screen.frame.maxY
        loadValues()
    }

    @objc private func islandYChanged(_ sender: NSSlider) {
        settings.islandTopMargin = sender.doubleValue
        updateLabels()
    }

    @objc private func pillWChanged(_ sender: NSSlider) {
        settings.pillWidth = sender.doubleValue
        updateLabels()
    }

    @objc private func pillHChanged(_ sender: NSSlider) {
        settings.pillHeight = sender.doubleValue
        updateLabels()
    }

    @objc private func panelWChanged(_ sender: NSSlider) {
        settings.panelWidth = sender.doubleValue
        updateLabels()
    }

    @objc private func panelHChanged(_ sender: NSSlider) {
        settings.panelHeight = sender.doubleValue
        updateLabels()
    }

    @objc private func previewChanged(_ sender: NSButton) {
        settings.previewZone = sender.state == .on
    }

    @objc private func screensChanged(_ sender: NSButton) {
        settings.showOnAllScreens = sender.state == .on
    }

    @objc private func loginChanged(_ sender: NSButton) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                settings.launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                settings.launchAtLogin = true
            }
        } catch {
            sender.state = settings.launchAtLogin ? .on : .off
            let alert = NSAlert()
            alert.messageText = L("无法设置开机自动启动")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func removeAfterDragOutChanged(_ sender: NSButton) {
        settings.removeAfterDragOut = sender.state == .on
    }

    private func updateLabels() {
        collapseDelayLabel.stringValue = String(format: L("%.1f 秒"), collapseDelaySlider.doubleValue)
        heightLabel.stringValue = "\(Int(heightSlider.doubleValue)) pt"
        widthLabel.stringValue = "\(Int(widthSlider.doubleValue)) pt"
        offsetLabel.stringValue = "\(Int(offsetSlider.doubleValue)) pt"
        zoneYLabel.stringValue = "\(Int(zoneYSlider.doubleValue)) pt"
        islandXLabel.stringValue = "\(Int(islandXSlider.doubleValue)) pt"
        islandYLabel.stringValue = "\(Int(islandYSlider.doubleValue)) pt"
        pillWLabel.stringValue = "\(Int(pillWSlider.doubleValue)) pt"
        pillHLabel.stringValue = "\(Int(pillHSlider.doubleValue)) pt"
        panelWLabel.stringValue = "\(Int(panelWSlider.doubleValue)) pt"
        panelHLabel.stringValue = "\(Int(panelHSlider.doubleValue)) pt"
    }

    // MARK: - 值同步

    /// 合并开启时，感应区的所有尺寸/位置滑杆置灰（由小岛完全接管）。
    private func applyMergeState() {
        let merged = settings.mergeZoneWithIsland
        heightSlider.isEnabled = !merged
        widthSlider.isEnabled = !merged
        offsetSlider.isEnabled = !merged
        zoneYSlider.isEnabled = !merged
    }

    private func loadValues() {
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: Localization.language) ?? 1)
        modePopup.selectItem(at: max(0, min(2, settings.expandMode)))
        collapseDelaySlider.doubleValue = settings.collapseDelay
        heightSlider.doubleValue = settings.zoneHeight
        widthSlider.doubleValue = settings.zoneHalfWidth * 2
        offsetSlider.doubleValue = settings.zoneOffsetX
        zoneYSlider.doubleValue = settings.zoneOffsetY
        islandXSlider.doubleValue = settings.islandOffsetX
        islandYSlider.doubleValue = settings.islandTopMargin
        pillWSlider.doubleValue = settings.pillWidth
        pillHSlider.doubleValue = settings.pillHeight
        panelWSlider.doubleValue = settings.panelWidth
        panelHSlider.doubleValue = settings.panelHeight
        previewCheck.state = settings.previewZone ? .on : .off
        screensCheck.state = settings.showOnAllScreens ? .on : .off
        loginCheck.state = settings.launchAtLogin ? .on : .off
        removeCheck.state = settings.removeAfterDragOut ? .on : .off
        mergeZoneCheck.state = settings.mergeZoneWithIsland ? .on : .off
        applyMergeState()
        updateLabels()
    }
}
