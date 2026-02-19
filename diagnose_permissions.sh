#!/bin/bash

echo "🔍 DexDictate Permission Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APP_PATH="$HOME/Applications/DexDictate_V2.app"
APP_ID="com.westkitty.dexdictate.macos"

# 1. Check if app exists
echo "1️⃣  App Bundle:"
if [ -d "$APP_PATH" ]; then
    echo "   ✅ Found: $APP_PATH"
else
    echo "   ❌ Not found: $APP_PATH"
    exit 1
fi

# 2. Check code signature
echo ""
echo "2️⃣  Code Signature:"
CERT=$(codesign -dvv "$APP_PATH" 2>&1 | grep "Authority=" | head -1 | cut -d= -f2)
CDHASH=$(codesign -dvvv "$APP_PATH" 2>&1 | grep "^CDHash=" | cut -d= -f2)
echo "   Certificate: $CERT"
echo "   CDHash: $CDHASH"

# 3. Check bundle ID
echo ""
echo "3️⃣  Bundle Info:"
BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIdentifier)
echo "   Bundle ID: $BUNDLE_ID"

if [ "$BUNDLE_ID" != "$APP_ID" ]; then
    echo "   ⚠️  WARNING: Bundle ID mismatch!"
    echo "   Expected: $APP_ID"
    echo "   Found: $BUNDLE_ID"
fi

# 4. Check if app is running
echo ""
echo "4️⃣  Running Process:"
PID=$(pgrep -f DexDictate_V2)
if [ -n "$PID" ]; then
    echo "   ✅ Running (PID: $PID)"
    RUNNING_PATH=$(ps -p $PID -o command= | awk '{print $1}')
    echo "   Path: $RUNNING_PATH"

    if [ "$RUNNING_PATH" != "$APP_PATH/Contents/MacOS/DexDictate_V2" ]; then
        echo "   ⚠️  WARNING: Running from different location!"
    fi
else
    echo "   ❌ Not running"
fi

# 5. Check entitlements
echo ""
echo "5️⃣  Entitlements:"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -A1 "com.apple.security.device" || echo "   ❌ No entitlements found"

# 6. System permissions check
echo ""
echo "6️⃣  System Accessibility Check:"
# Create a small Swift script to check AXIsProcessTrusted
cat > /tmp/check_ax.swift << 'EOF'
import ApplicationServices
let trusted = AXIsProcessTrusted()
print("AXIsProcessTrusted: \(trusted)")
EOF

swiftc /tmp/check_ax.swift -o /tmp/check_ax 2>/dev/null
if [ -f /tmp/check_ax ]; then
    /tmp/check_ax
    rm /tmp/check_ax /tmp/check_ax.swift
else
    echo "   ⚠️  Could not compile check script"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Recommendations:"
echo ""

if [ -n "$PID" ]; then
    echo "   1. Kill running app: pkill -f DexDictate_V2"
    echo "   2. Rebuild app: ./build.sh"
    echo "   3. Launch fresh: open $APP_PATH"
else
    echo "   1. Launch app: open $APP_PATH"
fi

echo ""
