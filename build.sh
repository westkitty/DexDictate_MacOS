#!/bin/bash
set -euo pipefail

APP_NAME="DexDictate"
EXECUTABLE_NAME="DexDictate"
SWIFT_PRODUCT="DexDictate_MacOS"
CERT_NAME="DexDictate Development"
BUILD_DIR=".build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
ENTITLEMENTS="Sources/DexDictate/DexDictate.entitlements"
ICON_SOURCE="Sources/DexDictate/AppIcon.icns"
INFO_TEMPLATE="templates/Info.plist.template"
VERSION_FILE="VERSION"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔨 Building $APP_NAME...${NC}"
echo -e "${BLUE}🚀 Compiling sources...${NC}"
swift build -c release --disable-sandbox

BIN_PATH="$(swift build -c release --show-bin-path)"
BINARY="$BIN_PATH/$SWIFT_PRODUCT"
RESOURCE_BUNDLE="$BIN_PATH/${SWIFT_PRODUCT}_DexDictateKit.bundle"

if [ ! -f "$BINARY" ]; then
    echo "❌ Missing binary: $BINARY"
    exit 1
fi

if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "❌ Missing SwiftPM resource bundle: $RESOURCE_BUNDLE"
    exit 1
fi

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp -f "$BINARY" "$BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
rm -rf "$BUNDLE/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"
cp -R "$RESOURCE_BUNDLE" "$BUNDLE/Contents/Resources/"
cp -f "$ICON_SOURCE" "$BUNDLE/Contents/Resources/AppIcon.icns"

VERSION="$(cat "$VERSION_FILE")"
echo "📄 Generating Info.plist..."
sed -e "s/{{APP_NAME}}/$APP_NAME/g" \
    -e "s/{{EXECUTABLE_NAME}}/$EXECUTABLE_NAME/g" \
    -e "s/{{VERSION}}/$VERSION/g" \
    "$INFO_TEMPLATE" > "$BUNDLE/Contents/Info.plist"

echo "APPL????" > "$BUNDLE/Contents/PkgInfo"

if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo -e "${BLUE}🔐 Signing with '$CERT_NAME'...${NC}"
    codesign --force --deep \
        --sign "$CERT_NAME" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp=none \
        "$BUNDLE"
else
    echo -e "${YELLOW}⚠️  '$CERT_NAME' not found. Using ad-hoc signing (-).${NC}"
    codesign --force --deep \
        --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$BUNDLE"
fi

CDHASH="$(codesign -dvv "$BUNDLE" 2>&1 | awk -F= '/CDHash=/{print $2; exit}')"
if [ -n "$CDHASH" ]; then
    echo -e "${GREEN}CDHash: $CDHASH${NC}"
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
fi

echo -e "${GREEN}✅ Installed to $INSTALL_DIR/$APP_NAME.app${NC}"
echo "Open with: open \"$INSTALL_DIR/$APP_NAME.app\""
