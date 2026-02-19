#!/bin/bash
# DexDictate install script
# Builds, installs to /Applications, and codesigns with entitlements.
# Entitlements MUST be embedded or macOS will silently deny mic + input monitoring.
set -e

PROJ="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="/Applications/DexDictate.app"
ENTITLEMENTS="$PROJ/Sources/DexDictate/DexDictate.entitlements"

echo "→ Building release binary..."
cd "$PROJ"
swift build -c release

echo "→ Stopping running instance..."
killall DexDictate 2>/dev/null || true
sleep 0.5

echo "→ Installing binary..."
cp .build/arm64-apple-macosx/release/DexDictate_MacOS "$BUNDLE/Contents/MacOS/DexDictate"

echo "→ Refreshing resource bundle..."
cp -R .build/arm64-apple-macosx/release/DexDictate_MacOS_DexDictateKit.bundle \
      "$BUNDLE/Contents/Resources/"

echo "→ Codesigning with entitlements..."
codesign --force --deep --sign - \
  --entitlements "$ENTITLEMENTS" \
  "$BUNDLE"

echo "→ Verifying entitlements..."
codesign -dv --entitlements :- "$BUNDLE" 2>&1 | grep -E "(audio-input|input-monitoring|Identifier)" || true

echo "✅ DexDictate installed and signed at $BUNDLE"
echo "   Open from Finder or run: open $BUNDLE"
