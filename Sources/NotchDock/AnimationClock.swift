import AppKit
import CoreVideo

/// Delivers at most one pending UI update, paced by the panel's display.
/// No display-link callback touches AppKit or queues a backlog of old frames.
final class AnimationClock {
    private var stopModernLink: (() -> Void)?
    private var displayLink: CVDisplayLink?
    private var updates: DispatchSourceUserDataAdd?
    private var fallback: Timer?
    private(set) var isDisplaySynchronized = false

    init(displayID: CGDirectDisplayID, fallbackFPS: Int, tick: @escaping () -> Void) {
        if #available(macOS 14.0, *),
           let screen = NSScreen.screens.first(where: { IslandMetrics.screenNumber($0).uint32Value == displayID }) {
            let target = DisplayLinkTarget(tick: tick)
            let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.update(_:)))
            let maximum = Float(min(120, max(30, screen.maximumFramesPerSecond)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
            link.add(to: .main, forMode: .common)
            stopModernLink = { link.invalidate() }
            isDisplaySynchronized = true
            return
        }
        // Compatibility path for macOS 13.
        var link: CVDisplayLink?
        if CVDisplayLinkCreateWithCGDisplay(displayID, &link) == kCVReturnSuccess,
           let link {
            let source = DispatchSource.makeUserDataAddSource(queue: .main)
            source.setEventHandler { [weak self] in
                guard self?.updates != nil else { return }
                tick()
            }
            source.resume()
            updates = source
            let result = CVDisplayLinkSetOutputHandler(link) { _, _, _, _, _ in
                source.add(data: 1)
                return kCVReturnSuccess
            }
            if result == kCVReturnSuccess, CVDisplayLinkStart(link) == kCVReturnSuccess {
                displayLink = link
                isDisplaySynchronized = true
                return
            }
            source.cancel()
            updates = nil
        }
        let timer = Timer(timeInterval: 1 / Double(max(30, fallbackFPS)), repeats: true) { _ in tick() }
        fallback = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidate() {
        stopModernLink?()
        stopModernLink = nil
        if let displayLink { CVDisplayLinkStop(displayLink) }
        displayLink = nil
        updates?.cancel()
        updates = nil
        fallback?.invalidate()
        fallback = nil
        isDisplaySynchronized = false
    }

    deinit { invalidate() }
}

/// A critically damped response with a finite, motionless endpoint.
/// Time warping allows the configured duration to remain the actual duration.
enum IslandAnimationCurve {
    static func geometry(_ progress: Double) -> CGFloat {
        let t = min(1, max(0, progress))
        guard t < 1 else { return 1 }
        let response = 2.6 * t / (1 - t)
        return CGFloat(1 - (1 + response) * exp(-response))
    }

    static func opacity(_ progress: Double) -> CGFloat {
        let t = min(1, max(0, progress))
        return CGFloat(t * t * t * (t * (t * 6 - 15) + 10))
    }
}

@available(macOS 14.0, *)
private final class DisplayLinkTarget: NSObject {
    private let tick: () -> Void
    init(tick: @escaping () -> Void) { self.tick = tick }
    @objc func update(_ sender: CADisplayLink) { tick() }
}
