#!/bin/bash
# DexDictate install script
# Wrapper around build.sh so there is one canonical build/install flow.
set -euo pipefail

PROJ="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJ"

echo "→ Running canonical build/install script..."
./build.sh
