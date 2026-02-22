#!/bin/bash
set -euo pipefail

echo "🔧 Setting up DexDictate development environment..."

# Create directories
mkdir -p scripts templates

# Create VERSION file
if [ ! -f VERSION ]; then
    echo "1.0.0" > VERSION
fi

# Check Xcode tools
if ! xcode-select -p &>/dev/null; then
    echo "⚠️  Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Optional development certificate for stable identity-based signing.
# build.sh will still work with ad-hoc signing when this cert is absent.
if [ -f scripts/create_signing_cert.sh ]; then
    echo "ℹ️  Optional: run ./scripts/create_signing_cert.sh if you want named certificate signing."
fi

echo "✅ Development environment ready"
echo "Run: ./build.sh"
