import AppKit

/// Geometry is measured in points, using the current display rather than a fixed resolution.
enum IslandMetrics {
    static var pillSize: NSSize { NSSize(width: AppSettings.shared.pillWidth, height: AppSettings.shared.pillHeight) }
    static var expandedSize: NSSize { NSSize(width: AppSettings.shared.panelWidth, height: AppSettings.shared.panelHeight) }
    static var collapsedCorner: CGFloat { min(pillSize.height / 2, 18) }
    static let expandedCorner: CGFloat = 26
    static func hasNotch(_ screen: NSScreen) -> Bool { screen.safeAreaInsets.top > 1 }
    static func topEdge(_ screen: NSScreen) -> CGFloat {
        // Zero offset starts below the camera; negative offsets can move into the notch.
        min(screen.visibleFrame.maxY, screen.frame.maxY - screen.safeAreaInsets.top) - 4
    }
    static func frame(for screen: NSScreen, expanded: Bool) -> NSRect {
        let settings = AppSettings.shared
        let visible = screen.visibleFrame
        var size = expanded ? expandedSize : pillSize
        // Respect the configured capsule size so it can fit entirely inside the notch.
        size.width = min(max(size.width, expanded ? 320 : 80), visible.width - 24)
        size.height = min(max(size.height, expanded ? 200 : 20), visible.height - 24)
        let x = min(max(screen.frame.midX + settings.islandOffsetX - size.width / 2, visible.minX + 12), visible.maxX - size.width - 12)
        let top = min(screen.frame.maxY, topEdge(screen) - settings.islandTopMargin)
        let y = max(visible.minY + 12, top - size.height)
        let scale = screen.backingScaleFactor
        return NSRect(x: (x * scale).rounded() / scale, y: (y * scale).rounded() / scale, width: size.width, height: size.height)
    }
    static func pillFrame(for screen: NSScreen) -> NSRect { frame(for: screen, expanded: false) }
    static func expandedFrame(for screen: NSScreen) -> NSRect { frame(for: screen, expanded: true) }
    static func zoneRect(for screen: NSScreen) -> NSRect {
        let s = AppSettings.shared
        if s.mergeZoneWithIsland { return pillFrame(for: screen) }
        let width = min(s.zoneHalfWidth * 2, screen.frame.width)
        let rect = NSRect(x: screen.frame.midX + s.zoneOffsetX - width / 2,
                          y: topEdge(screen) - s.zoneHeight - s.zoneOffsetY,
                          width: width, height: s.zoneHeight)
        return rect.intersection(screen.frame)
    }
    static func screenNumber(_ screen: NSScreen) -> NSNumber {
        screen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? NSNumber ?? 0
    }
}
