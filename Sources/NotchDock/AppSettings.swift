import Foundation

/// 用户设置（持久化到 UserDefaults）。
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let showOnAllScreens = "showOnAllScreens"
        static let launchAtLogin = "launchAtLogin"
        static let islandVisible = "islandVisible"
        static let expandMode = "expandMode"
        static let collapseDelay = "collapseDelay"
        static let zoneHeight = "zoneHeight"
        static let zoneHalfWidth = "zoneHalfWidth"
        static let zoneOffsetX = "zoneOffsetX"
        static let zoneOffsetY = "zoneOffsetY"
        static let previewZone = "previewZone"
        static let islandOffsetX = "islandOffsetX"
        static let islandTopMargin = "islandTopMargin"
        static let pillWidth = "pillWidth"
        static let pillHeight = "pillHeight"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
        static let removeAfterDragOut = "removeAfterDragOut"
        static let mergeZoneWithIsland = "mergeZoneWithIsland"
    }

    /// 展开方式：0 = 仅拖拽文件时展开（默认），1 = 悬停或拖拽时展开，2 = 仅点击小岛展开。
    var expandMode: Int {
        get { defaults.object(forKey: Key.expandMode) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Key.expandMode); notify() }
    }

    /// 自动收起延迟（秒）：移开鼠标/拖出后，多久自动缩回小岛，默认 0.4 秒。
    var collapseDelay: Double {
        get { defaults.object(forKey: Key.collapseDelay) as? Double ?? 0.4 }
        set { defaults.set(newValue, forKey: Key.collapseDelay); notify() }
    }

    /// 感应区域高度（菜单栏向下延伸多少 pt，默认 50）。
    var zoneHeight: Double {
        get { defaults.object(forKey: Key.zoneHeight) as? Double ?? 50 }
        set { defaults.set(newValue, forKey: Key.zoneHeight); notify() }
    }

    /// 感应区域半宽（默认 150，即总宽 300 pt）。
    var zoneHalfWidth: Double {
        get { defaults.object(forKey: Key.zoneHalfWidth) as? Double ?? 196 }
        set { defaults.set(newValue, forKey: Key.zoneHalfWidth); notify() }
    }

    /// 感应区域水平偏移（相对屏幕中央，默认 0）。
    var zoneOffsetX: Double {
        get { defaults.object(forKey: Key.zoneOffsetX) as? Double ?? 0 }
        set { defaults.set(newValue, forKey: Key.zoneOffsetX); notify() }
    }

    /// 感应区域垂直偏移：默认 0 紧贴菜单栏下方，正值向下移，负值向上移。
    var zoneOffsetY: Double {
        get { defaults.object(forKey: Key.zoneOffsetY) as? Double ?? 0 }
        set { defaults.set(newValue, forKey: Key.zoneOffsetY); notify() }
    }

    /// 是否显示感应区域虚线预览。
    var previewZone: Bool {
        get { defaults.object(forKey: Key.previewZone) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.previewZone); notify() }
    }

    /// 感应区域是否跟随小岛位置（合并）：开启后感应区水平/垂直位置由小岛位置决定。
    var mergeZoneWithIsland: Bool {
        get { defaults.object(forKey: Key.mergeZoneWithIsland) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.mergeZoneWithIsland); notify() }
    }

    /// 小岛（胶囊与展开面板）的水平偏移，相对屏幕中央，默认 0。
    var islandOffsetX: Double {
        get { defaults.object(forKey: Key.islandOffsetX) as? Double ?? 0 }
        set { defaults.set(newValue, forKey: Key.islandOffsetX); notify() }
    }

    /// 小岛的垂直偏移：默认 0 贴刘海/菜单栏，正值向下移，负值向上移。
    var islandTopMargin: Double {
        get { defaults.object(forKey: Key.islandTopMargin) as? Double ?? 0 }
        set { defaults.set(newValue, forKey: Key.islandTopMargin); notify() }
    }

    /// 胶囊宽度（默认 150 pt）。
    var pillWidth: Double {
        get { defaults.object(forKey: Key.pillWidth) as? Double ?? 196 }
        set { defaults.set(newValue, forKey: Key.pillWidth); notify() }
    }

    /// 胶囊高度（默认 34 pt）。
    var pillHeight: Double {
        get { defaults.object(forKey: Key.pillHeight) as? Double ?? 34 }
        set { defaults.set(newValue, forKey: Key.pillHeight); notify() }
    }

    /// 展开面板宽度（默认 364 pt）。
    var panelWidth: Double {
        get { defaults.object(forKey: Key.panelWidth) as? Double ?? 420 }
        set { defaults.set(newValue, forKey: Key.panelWidth); notify() }
    }

    /// 展开面板高度（默认 264 pt）。
    var panelHeight: Double {
        get { defaults.object(forKey: Key.panelHeight) as? Double ?? 310 }
        set { defaults.set(newValue, forKey: Key.panelHeight); notify() }
    }

    /// 在所有显示器上显示小岛（默认只在主屏）。
    var showOnAllScreens: Bool {
        get { defaults.object(forKey: Key.showOnAllScreens) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.showOnAllScreens); notify() }
    }

    /// 开机自动启动。
    var launchAtLogin: Bool {
        get { defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// 小岛是否可见。
    var islandVisible: Bool {
        get { defaults.object(forKey: Key.islandVisible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.islandVisible); notify() }
    }

    /// 拖出成功后是否自动移除条目（默认关：拖出=复制一份，条目保留在小岛）。
    var removeAfterDragOut: Bool {
        get { defaults.object(forKey: Key.removeAfterDragOut) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.removeAfterDragOut); notify() }
    }

    private func notify() {
        NotificationCenter.default.post(name: .settingsChanged, object: self)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("NotchDockSettingsChanged")
}
