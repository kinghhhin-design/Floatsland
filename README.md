# Floatsland

A minimal black file shelf for the macOS notch. Drop files, folders or text, then drag them to another app or desktop.

适用于 macOS 的纯黑悬浮文件中转站。拖入文件、文件夹或文字暂存，再拖到其他应用或桌面。

## Download / 下载

Download **Floatsland-2.1.1-macos-arm64.zip** from [Releases](https://github.com/kinghhhin-design/Floatsland/releases/latest), extract it and move **Floatsland.app** to Applications.

从 Releases 下载 ZIP，解压后将 **Floatsland.app** 拖入「应用程序」。若之前安装过 FloatIsland，请先退出并替换旧版，避免同时运行。

- macOS 13 or later; the prebuilt release is for **Apple Silicon (arm64)**.
- Locally ad-hoc signed; **not Apple-notarized**. macOS may require approval in System Settings → Privacy & Security before the first launch. Only approve software you trust.
- No Dock icon: use the tray icon in the menu bar for Settings and Quit.

## Features / 功能

- Pure black capsule with no text while collapsed; no bright outline or drop bounce.
- Drag files, folders and selected text onto the island.
- Drag out to copy; hold Command to allow moving (the destination determines the final operation).
- Multiple selection, marquee selection, batch dragging and Finder reveal.
- Pointer inside keeps the panel open. Click the top center, collapse arrow or outside to close.
- A stationary green confirmation appears after a successful drop.
- Configurable size, position, trigger area, collapse delay, multi-display support and login launch.
- Negative vertical offsets and a “Hide capsule inside notch” preset.
- Traditional Chinese, Simplified Chinese, English, Japanese and Korean; switch in Settings → Language.
- Stored items and language choice persist across launches.

**Files are references, not backups.** Removing a shelf entry does not delete the original; moving or deleting the original may invalidate the entry. Text fragments and file paths are stored locally in UserDefaults. The app has no built-in network service or analytics.

## Build / 编译

Requires macOS and Xcode Command Line Tools. The application itself has no third-party dependencies.

```sh
./build_app.sh
open .build/float-release/Floatsland.app
```

The build script produces an arm64 release app inside `.build`, so the development folder does not expose an extra top-level application. It does not install or launch automatically. The bundled icon is included; regenerating it with `make_icon.py` requires Pillow.

The internal Swift target remains `NotchDock` and the bundle identifier remains `com.floatisland.app` to preserve existing settings.

## Limitations

Notch geometry and available workspace are queried at runtime. Every display scaling mode, external display combination and third-party drag destination has not been tested. This build is not a universal Intel binary. On a display without a notch, the hide-inside-notch preset is unavailable.

## License

MIT. See [LICENSE](LICENSE).
