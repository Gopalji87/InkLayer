#!/bin/bash
# Builds a universal InkLayer.app (menu-bar app, no Dock icon) into ./build
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/InkLayer"

APP="build/InkLayer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/InkLayer"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>InkLayer</string>
    <key>CFBundleDisplayName</key><string>InkLayer</string>
    <key>CFBundleIdentifier</key><string>com.inklayer.app</string>
    <key>CFBundleExecutable</key><string>InkLayer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Built: $(pwd)/$APP"
echo "Run:   open \"$(pwd)/$APP\""

# ---- Make DMG ----
DMG_DIR="build/dmg"
rm -rf "$DMG_DIR" build/InkLayer.dmg
mkdir -p "$DMG_DIR"
cp -R "$APP" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "InkLayer" -srcfolder "$DMG_DIR" -ov -format UDZO build/InkLayer.dmg >/dev/null
echo "DMG:   $(pwd)/build/InkLayer.dmg"
