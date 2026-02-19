#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P)"
cd "$ROOT_DIR"

echo "[quality] swift build"
swift build

echo "[quality] swift run VerificationRunner"
swift run VerificationRunner

echo "[quality] complete"
