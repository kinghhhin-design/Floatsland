import AppKit

/// 菜单栏图标与菜单。
final class StatusBarController: NSObject, NSMenuDelegate {
    private var languageObserver: NSObjectProtocol?
    private let statusItem: NSStatusItem
    private weak var manager: IslandManager?
    private let store: ShelfStore
    private let settings = AppSettings.shared
    private let settingsWindow = SettingsWindowController()

    init(manager: IslandManager, store: ShelfStore) {
        self.manager = manager
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.full.fill",
                                   accessibilityDescription: L("浮屿"))
        }
        statusItem.menu = buildMenu()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageChanged, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.statusItem.menu = self.buildMenu()
                self.statusItem.button?.setAccessibilityLabel(L("浮屿"))
            }
    }

    deinit {
        if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let visibleItem = NSMenuItem(title: settings.islandVisible ? L("隐藏浮屿") : L("显示浮屿"),
                                     action: #selector(toggleVisible), keyEquivalent: "")
        visibleItem.target = self
        menu.addItem(visibleItem)

        let settingsItem = NSMenuItem(title: L("设置…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: L("清空暂存"), action: #selector(clearShelf), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !store.items.isEmpty
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: L("关于 浮屿"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: L("退出 浮屿"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        // 打开菜单前刷新状态，并收起小岛避免遮挡
        statusItem.menu = buildMenu()
        manager?.collapseAllNow()
    }

    @objc private func toggleVisible() {
        manager?.setVisible(!settings.islandVisible)
    }

    @objc private func openSettings() {
        settingsWindow.showSettings()
    }

    @objc private func clearShelf() {
        store.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L("浮屿 FloatIsland")
        alert.informativeText = L("about.body")
        alert.addButton(withTitle: L("好的"))
        alert.runModal()
    }
}
