#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path_to_audio_file.wav> [baseline_ms]" >&2
    exit 1
fi

AUDIO_FILE="$1"
BASELINE_MS="${2:-}"

ARGS=(
    --audio "$AUDIO_FILE"
    --iterations 5
    --build release
    --output-dir artifacts/benchmarks
)

if [[ -n "$BASELINE_MS" ]]; then
    ARGS+=(--baseline-ms "$BASELINE_MS" --budget-pct 10)
fi

"$(dirname "$0")/benchmark.sh" "${ARGS[@]}"
