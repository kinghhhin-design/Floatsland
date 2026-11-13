import AppKit

/// 全局鼠标跟踪（无需辅助功能权限）：
/// 定时轮询鼠标位置，判断是否进入顶部感应区域，并猜测当前是否正在拖拽文件。
final class MouseTracker {
    struct ZoneState: Equatable {
        var inZone: Bool = false
        var inPanel: Bool = false
        var screenNumber: NSNumber = 0
        var dragActive: Bool = false
    }

    private(set) var state = ZoneState()
    var onStateChange: ((ZoneState) -> Void)?
    var containsPanel: ((NSPoint) -> Bool)?

    private var timer: Timer?
    private let dragPasteboard = NSPasteboard(name: .drag)

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // 加入 common 模式，保证拖拽事件循环期间依然轮询。
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        var newState = ZoneState()
        newState.inPanel = containsPanel?(mouse) ?? false

        for screen in NSScreen.screens where screen.frame.contains(mouse) {
            newState.screenNumber = IslandMetrics.screenNumber(screen)
            newState.inZone = IslandMetrics.zoneRect(for: screen).contains(mouse)
            break
        }

        // 拖拽判定：系统拖拽剪贴板有内容，且鼠标左键按住。
        let hasDragData = !(dragPasteboard.types?.isEmpty ?? true)
        let leftDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        newState.dragActive = hasDragData && leftDown

        if newState != state {
            state = newState
            onStateChange?(newState)
        }
    }
}
