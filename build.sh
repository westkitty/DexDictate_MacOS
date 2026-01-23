#!/bin/bash
set -e
APP_NAME="DexDictate_V2"
BUILD_DIR="./.build"
INSTALL_DIR="$HOME/Applications"

echo "🔨 Building DexDictate_MacOS..."
swift build -c release --arch arm64 --disable-sandbox

BINARY="$BUILD_DIR/arm64-apple-macosx/release/DexDictate_MacOS"
BUNDLE="$BUILD_DIR/$APP_NAME.app"

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"

echo "🎨 Compiling Assets..."
/Applications/Xcode.app/Contents/Developer/usr/bin/actool Sources/DexDictate/Resources/Assets.xcassets --compile "$BUNDLE/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist /tmp/assetcatalog_generated_info.plist

# Info.plist for M1 Permissions
cat <<PLIST > "$BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>com.westkitty.dexdictate.macos</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>This app needs microphone access to transcribe your speech.</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>This app uses speech recognition to convert your voice to text.</string>
    <key>NSAccessibilityUsageDescription</key><string>This app needs accessibility access to monitor global keyboard/mouse events.</string>
</dict>
</plist>
PLIST

# Sign with entitlements (Required for EventTap)
# Note: Entitlements path must match where we created it in Step 5
ENTITLEMENTS="Sources/DexDictate/DexDictate.entitlements"
# Sign the bundle with --deep to cover all contents atomically
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$BUNDLE"

rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
echo "✅ Installed to $INSTALL_DIR"
