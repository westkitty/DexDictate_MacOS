#!/bin/bash
set -e

# Configuration
APP_NAME="DexDictate"
CERT_NAME="DexDictate Development"
BUNDLE_ID="com.westkitty.dexdictate.macos"
BUILD_DIR="./.build"
INSTALL_DIR="/Applications"
SOURCES_DIR="Sources"
TEMPLATE_DIR="templates"
RESOURCES_DIR="Sources/DexDictateKit/Resources"
ENTITLEMENTS="Sources/DexDictate/DexDictate.entitlements"
VERSION_FILE="VERSION"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 Building $APP_NAME...${NC}"

# 1. Certificate Check
if ! security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo -e "${YELLOW}⚠️  Development certificate not found.${NC}"
    if [ -f "scripts/create_signing_cert.sh" ]; then
        ./scripts/create_signing_cert.sh
    else
        echo "❌ Certificate script missing. Run scripts/setup_dev_env.sh"
        exit 1
    fi
fi

# 2. Incremental Build Logic
NEEDS_COMPILE=false
LAST_BUILD_TIME=0
if [ -f "$BUILD_DIR/last_build_timestamp" ]; then
    LAST_BUILD_TIME=$(cat "$BUILD_DIR/last_build_timestamp")
fi

# Find newest source file timestamp
NEWEST_SOURCE=$(find "$SOURCES_DIR" -name "*.swift" -type f -print0 | xargs -0 stat -f "%m" | sort -rn | head -1)

if [ -z "$NEWEST_SOURCE" ]; then NEWEST_SOURCE=0; fi

if [ "$NEWEST_SOURCE" -gt "$LAST_BUILD_TIME" ] || [ ! -f "$BUILD_DIR/arm64-apple-macosx/release/DexDictate_MacOS" ]; then
    NEEDS_COMPILE=true
fi

if [ "$NEEDS_COMPILE" = true ]; then
    echo -e "${BLUE}🚀 Compiling sources...${NC}"
    swift build -c release --arch arm64 --disable-sandbox
    date +%s > "$BUILD_DIR/last_build_timestamp"
else
    echo -e "${GREEN}⚡️ Sources unchanged, skipping compilation.${NC}"
fi

# 3. Bundle Structure
BINARY="$BUILD_DIR/arm64-apple-macosx/release/DexDictate_MacOS"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# Update binary if changed
if [ "$NEEDS_COMPILE" = true ] || [ ! -f "$BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
fi

# Copy SPM resource bundle (models, profanity list, etc.)
SPM_BUNDLE="$BUILD_DIR/arm64-apple-macosx/release/DexDictate_MacOS_DexDictateKit.bundle"
if [ -d "$SPM_BUNDLE" ]; then
    echo "📦 Copying resource bundle..."
    cp -R "$SPM_BUNDLE" "$BUNDLE/Contents/Resources/"
fi

# 4. Info.plist Generation (Cache check)
VERSION=$(cat "$VERSION_FILE")
PLIST_DEST="$BUNDLE/Contents/Info.plist"
GeneratePlist=false

if [ ! -f "$PLIST_DEST" ]; then
    GeneratePlist=true
else
    # Check if template or version changed
    TEMPLATE_TIME=$(stat -f "%m" "$TEMPLATE_DIR/Info.plist.template")
    VERSION_TIME=$(stat -f "%m" "$VERSION_FILE")
    PLIST_TIME=$(stat -f "%m" "$PLIST_DEST")
    
    if [ "$TEMPLATE_TIME" -gt "$PLIST_TIME" ] || [ "$VERSION_TIME" -gt "$PLIST_TIME" ]; then
        GeneratePlist=true
    fi
fi

if [ "$GeneratePlist" = true ]; then
    echo "📄 Generating Info.plist..."
    sed -e "s/{{APP_NAME}}/$APP_NAME/g" \
        -e "s/{{EXECUTABLE_NAME}}/$APP_NAME/g" \
        -e "s/{{VERSION}}/$VERSION/g" \
        "$TEMPLATE_DIR/Info.plist.template" > "$PLIST_DEST"
fi

# 5. Asset Compilation (Cache check)
ASSETS_SRC="$RESOURCES_DIR/Assets.xcassets"
ASSETS_DEST="$BUNDLE/Contents/Resources/Assets.car"
CompileAssets=false

if [ ! -f "$ASSETS_DEST" ]; then
    CompileAssets=true
else
    # Simple check: if any file in .xcassets is newer than Assets.car
    NEWEST_ASSET=$(find "$ASSETS_SRC" -type f -print0 | xargs -0 stat -f "%m" | sort -rn | head -1)
    if [ -z "$NEWEST_ASSET" ]; then NEWEST_ASSET=0; fi
    ASSETS_TIME=$(stat -f "%m" "$ASSETS_DEST")
    
    if [ "$NEWEST_ASSET" -gt "$ASSETS_TIME" ]; then
        CompileAssets=true
    fi
fi

if [ "$CompileAssets" = true ]; then
    ACTOOL=$(xcrun --find actool 2>/dev/null || true)
    if [ -n "$ACTOOL" ]; then
        echo -e "${BLUE}🎨 Compiling Assets...${NC}"
        "$ACTOOL" \
            "$ASSETS_SRC" \
            --compile "$BUNDLE/Contents/Resources" \
            --platform macosx \
            --minimum-deployment-target 14.0 \
            --app-icon AppIcon \
            --output-partial-info-plist /tmp/assetcatalog_generated_info.plist > /dev/null
    else
        echo -e "${YELLOW}⚠️  actool requires full Xcode — skipping asset compilation (app icon will be missing).${NC}"
    fi
fi

# 6. PkgInfo
if [ ! -f "$BUNDLE/Contents/PkgInfo" ]; then
    echo "APPL????" > "$BUNDLE/Contents/PkgInfo"
fi

# 7. Code Signing (Always sign to ensure validity, but certificate is stable)
echo -e "${BLUE}🔐 Signing with stable certificate...${NC}"
codesign --force --deep \
    --sign "$CERT_NAME" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp=none \
    "$BUNDLE"

# Verify CDHash
CDHASH=$(codesign -dvv "$BUNDLE" 2>&1 | grep "CDHash=" | cut -d'=' -f2)
echo -e "${GREEN}CDHash: $CDHASH${NC}"

# 8. Install
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_DIR/$APP_NAME.app"

echo -e "${GREEN}✅ Installed to $INSTALL_DIR${NC}"
