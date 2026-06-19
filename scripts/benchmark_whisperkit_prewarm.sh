#!/bin/bash
# Benchmark-only WhisperKit first-inference / CoreML-compile prewarm investigation.
#
# Builds the ISOLATED package tools/whisperkit_sidecar (WhisperKit is never in the
# production target) and runs scripts/benchmark_whisperkit_prewarm.py in --diagnose
# mode. Never touches production dictation, settings, model defaults, signing,
# packaging, or build.sh.
#
# Examples:
#   # Measure current warm/cold + restart persistence for all three models:
#   ./scripts/benchmark_whisperkit_prewarm.sh --probe-caches --real-after-prewarm
#
#   # Reproduce a COLD compile for tiny (delete its download dir first) and locate
#   # which OS cache the compile artifacts land in:
#   ./scripts/benchmark_whisperkit_prewarm.sh --skip-build \
#     --models openai_whisper-tiny --reset-models openai_whisper-tiny \
#     --sessions 2 --probe-caches --output-dir artifacts/whisperkit-prewarm/cold-tiny
#
#   # Compare compute units (compile driver) on tiny:
#   ./scripts/benchmark_whisperkit_prewarm.sh --skip-build \
#     --models openai_whisper-tiny --reset-models openai_whisper-tiny \
#     --compute-units cpu --sessions 1 --output-dir artifacts/whisperkit-prewarm/cpu-tiny
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$REPO_ROOT/tools/whisperkit_sidecar"
TOOL_BIN="$PKG_DIR/.build/release/whisperkit-transcribe"

SKIP_BUILD=0
PASS_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=1; shift ;;
        --help|-h)
            echo "Usage: ./scripts/benchmark_whisperkit_prewarm.sh [--skip-build] [driver options]"
            echo "Driver options are forwarded to scripts/benchmark_whisperkit_prewarm.py:"
            python3 "$SCRIPT_DIR/benchmark_whisperkit_prewarm.py" --help 2>/dev/null | sed -n '/options:/,$p' || true
            exit 0
            ;;
        *) PASS_ARGS+=("$1"); shift ;;
    esac
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "PREWARM_BUILD:building isolated package at $PKG_DIR"
    swift build -c release --package-path "$PKG_DIR"
fi

if [[ ! -x "$TOOL_BIN" ]]; then
    echo "ERROR: whisperkit-transcribe not built at $TOOL_BIN" >&2
    exit 1
fi

python3 "$SCRIPT_DIR/benchmark_whisperkit_prewarm.py" --whisperkit-tool "$TOOL_BIN" "${PASS_ARGS[@]}"
