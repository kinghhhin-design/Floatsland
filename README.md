# Floatsland

A minimal black file shelf for the macOS notch. Drop files, folders or text, then drag them to another app or desktop.

适用于 macOS 的纯黑悬浮文件中转站。拖入文件、文件夹或文字暂存，再拖到其他应用或桌面。

## Download / 下载

Download **Floatsland-2.2.1-macos-arm64.zip** from [Releases](https://github.com/kinghhhin-design/Floatsland/releases/latest), extract it and move **Floatsland.app** to Applications.

从 Releases 下载 ZIP，解压后将 **Floatsland.app** 拖入「应用程序」。若之前安装过 FloatIsland，请先退出并替换旧版，避免同时运行。

- macOS 13 or later; the prebuilt release is for **Apple Silicon (arm64)**.
- Locally ad-hoc signed; **not Apple-notarized**. macOS may require approval in System Settings → Privacy & Security before the first launch. Only approve software you trust.
- No Dock icon: use the tray icon in the menu bar for Settings and Quit.

## Features / 功能

- Pure black capsule with no text while collapsed; no bright outline or drop bounce.
- Drag files, folders and selected text onto the island.
- Drag out to copy; hold Command to allow moving (the destination determines the final operation).
- Multiple selection, marquee selection, batch dragging and Finder reveal. Start marquee selection from either narrow side gutter even when the list is full; drag to the top or bottom edge to scroll while selecting.
- Pointer inside keeps the panel open. Click the top center, collapse arrow or outside to close.
- A stationary green confirmation appears after a successful drop.
- Configurable size, position, trigger area, collapse delay, multi-display support and login launch.
- Negative vertical offsets and a “Hide capsule inside notch” preset.
- Traditional Chinese, Simplified Chinese, English, Japanese and Korean; switch in Settings → Language.
- Stored items and language choice persist across launches.
- Automatically save newly copied text and clipboard screenshots/images, with independent switches in Settings (enabled by default).
- Screenshot thumbnails; double-click any file to open it in its default app. Finder reveal remains available in the context menu.
- Newest additions appear first, including a one-time migration of existing shelf order.
- Only visible list rows are loaded; resizing animations reuse rows instead of rebuilding the entire shelf.

### Clipboard and storage / 剪贴板与存储

Copy text or take a screenshot to the clipboard while Floatsland is running; it is added automatically without rewriting the clipboard. Clipboard contents present before launch are not imported. Blank text is ignored and identical text is deduplicated. Clipboard images are saved as PNG files in `~/Library/Application Support/Floatsland/ClipboardImages`.

运行时复制文字，或将截图保存到剪贴板，即可自动暂存；设置中可分别关闭文字和图片自动暂存。截图显示缩略图；双击任意文件（包括 Word、PPT 和截图）可用系统默认应用打开，右键仍可选择“在访达中显示”。新加入的内容排在最上方。

Removing an automatically saved screenshot, or clearing the shelf, moves that screenshot to **Trash**. It remains recoverable and uses disk space until Trash is emptied. If moving it fails, the shelf entry is kept. Ordinary file references never delete or trash the original.

移除自动保存的截图或清空暂存时，截图会移到**废纸篓**；清空废纸篓后才释放其空间。普通文件只保存引用，移除暂存不会删除原文件。

**Ordinary files are references, not backups.** Removing a shelf entry does not delete the original; moving or deleting the original may invalidate the entry. Text fragments and file paths are stored locally in UserDefaults. The app has no built-in network service or analytics.

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

设置中的“展开动画时长”和“收起动画时长”可分别调整为 0.10–1.50 秒，默认分别为 0.34 秒和 0.24 秒。修改自动保存，下次动画生效，与“自动收起延迟”独立。
