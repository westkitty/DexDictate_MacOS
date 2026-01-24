#!/bin/bash
set -e

# Configuration
RELEASE_DIR="_releases"
APP_NAME="DexDictate_V2"
BUILD_OUTPUT=".build/$APP_NAME.app"
ZIP_NAME="DexDictate_MacOS.zip"

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

echo "✅ Build Complete. Upload '$ZIP_NAME' to GitHub Releases."
