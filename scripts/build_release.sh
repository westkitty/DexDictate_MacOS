#!/bin/bash
set -e

# Configuration
RELEASE_DIR="_releases"
APP_NAME="DexDictate"
BUILD_OUTPUT=".build/$APP_NAME.app"
ZIP_NAME="DexDictate_MacOS.zip"
DMG_NAME="DexDictate_MacOS.dmg"

# Ensure Release Directory
mkdir -p "$RELEASE_DIR"

echo "🚀 Starting Release Build..."

# 1. Run the main build script
# This handles cleaning, building, assets, plist, and signing.
./build.sh

# 2. Check if build was successful
if [ ! -d "$BUILD_OUTPUT" ]; then
    echo "❌ Build failed. $BUILD_OUTPUT not found."
    exit 1
fi

echo "📦 Packaging Release..."

# 3. Zip the application
# We cd into .build to zip the app cleanly without full paths
(cd .build && zip -r -q "../$RELEASE_DIR/$ZIP_NAME" "$APP_NAME.app")

# 4. Build DMG
STAGING_DIR=$(mktemp -d)
cp -R "$BUILD_OUTPUT" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$RELEASE_DIR/$DMG_NAME"
hdiutil create -volname "DexDictate" -srcfolder "$STAGING_DIR" -ov -format UDZO "$RELEASE_DIR/$DMG_NAME" >/dev/null
rm -rf "$STAGING_DIR"

echo "✅ Build Complete. Upload '$ZIP_NAME' or '$DMG_NAME' to GitHub Releases."
