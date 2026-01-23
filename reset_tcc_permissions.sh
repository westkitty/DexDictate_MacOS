#!/bin/bash
# DexDictate TCC Reset Protocol
# Run this BEFORE rebuilding/reinstalling the app

set -e

BUNDLE_ID="com.westkitty.dexdictate.macos"

echo "🧹 Dissolving corrupted TCC state for $BUNDLE_ID..."

# Reset Input Monitoring permission (the failing permission)
tccutil reset InputMonitoring "$BUNDLE_ID" 2>/dev/null || echo "  ⚠️  InputMonitoring was already clean"

# Reset Accessibility permission (used by EventTap APIs)
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || echo "  ⚠️  Accessibility was already clean"

echo ""
echo "✅ TCC reset complete. Next steps:"
echo "   1. Run ./build.sh to rebuild the app"
echo "   2. Launch the app from ~/Applications/DexDictate_V2.app"
echo "   3. System will prompt for Input Monitoring permission"
echo "   4. Grant the permission in System Settings"
echo ""
echo "🔄 If the prompt STILL doesn't appear, reboot your Mac."
