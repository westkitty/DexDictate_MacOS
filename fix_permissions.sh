#!/bin/bash
set -e

APP_ID="com.westkitty.dexdictate.macos"
APP_PATH="$HOME/Applications/DexDictate_V2.app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 SCORCHED EARTH: TCC & LaunchServices Reset"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Unregister app specifically (if it exists)
if [ -d "$APP_PATH" ]; then
    echo "1️⃣  Unregistering app from LaunchServices..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -u "$APP_PATH"
    echo "   ✅ App unregistered"
else
    echo "1️⃣  App not found at $APP_PATH (skipping unregister)"
fi

# Step 2: Reset LaunchServices database for user domain
echo "2️⃣  Resetting LaunchServices database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -r -domain local -domain user

echo "   ✅ LaunchServices database reset"

# Step 3: Reset TCC permissions
echo "3️⃣  Resetting TCC permissions for $APP_ID..."
sudo tccutil reset All $APP_ID
echo "   ✅ TCC permissions reset"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Reset Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo "   1. Delete old app: rm -rf ~/Applications/DexDictate_V2.app"
echo "   2. Rebuild: ./build.sh"
echo "   3. Launch: open ~/Applications/DexDictate_V2.app"
echo "   4. Grant permissions when prompted"
echo ""
echo "⚠️  If permissions still loop, reboot and try again."
echo ""
