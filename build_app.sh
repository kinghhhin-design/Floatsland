#!/bin/bash
# 一键构建 FloatIsland.app（编译 → 打包 → 签名）
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 1/3 编译 (swiftc · release)"
mkdir -p .build/float-release .build/ModuleCache
xcrun swiftc -O -target arm64-apple-macosx13.0 -module-cache-path "$PWD/.build/ModuleCache" Sources/NotchDock/*.swift -o .build/float-release/NotchDock

APP=".build/float-release/Floatsland.app"
echo "==> 2/3 打包 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/float-release/NotchDock "$APP/Contents/MacOS/NotchDock"

if [ ! -f AppIcon.icns ]; then
    echo "    生成图标..."
    PY="${DSH_BUNDLED_PYTHON:-python3}"
    "$PY" make_icon.py || echo "    图标生成失败，跳过（不影响功能）"
fi
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>NotchDock</string>
    <key>CFBundleIdentifier</key>
    <string>com.floatisland.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Floatsland</string>
    <key>CFBundleDisplayName</key>
    <string>Floatsland</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.1.1</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "==> 3/3 签名"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"

echo "✅ 完成: $PWD/$APP"
echo "运行: open $APP"

# 构建仅在此副本内完成，不修改 /Applications 中的原应用。
