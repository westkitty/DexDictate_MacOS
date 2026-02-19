#!/bin/bash
set -e

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

# Create certificate
if [ -f scripts/create_signing_cert.sh ]; then
    chmod +x scripts/create_signing_cert.sh
    ./scripts/create_signing_cert.sh
fi

echo "✅ Development environment ready"
echo "Run: ./build.sh"
