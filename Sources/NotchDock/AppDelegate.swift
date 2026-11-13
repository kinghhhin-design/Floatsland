import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: IslandManager!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        manager = IslandManager()
        statusBar = StatusBarController(manager: manager, store: manager.shelf)
        manager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.shelf.save()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
