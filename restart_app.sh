#!/bin/bash

echo "🔄 Restarting DexDictate_V2..."

# Kill the running app
pkill -f DexDictate_V2 || echo "App not running"

# Wait a moment
sleep 1

# Launch fresh
echo "🚀 Launching app..."
open ~/Applications/DexDictate_V2.app

echo ""
echo "✅ App restarted"
echo ""
echo "📋 Make sure you have granted BOTH permissions:"
echo "   1. System Settings → Privacy & Security → Accessibility → DexDictate_V2 ✓"
echo "   2. System Settings → Privacy & Security → Input Monitoring → DexDictate_V2 ✓"
echo ""
echo "The app should now work without errors."
