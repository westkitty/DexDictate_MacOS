#!/bin/bash
# Benchmark-only soniqo/speech-swift ParakeetStreamingASR (streaming ASR) lane.
#
# Builds the ISOLATED package tools/speech_swift_sidecar (speech-swift is NEVER in
# the production target) and runs scripts/benchmark_speech_swift.py against the
# shared corpus. Never touches production dictation, settings, model defaults,
# signing, packaging, or build.sh.
#
# NOTE: soniqo/speech-swift requires macOS 15+. This lane is benchmark-only; it
# does not change DexDictate's macOS 14 production floor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$REPO_ROOT/tools/speech_swift_sidecar"
TOOL_BIN="$PKG_DIR/.build/release/speech-swift-benchmark"

usage() {
    cat <<'EOF'
Usage:
  ./scripts/benchmark_speech_swift.sh [options]

Options:
  --corpus-dir <path>     Corpus dir (default: benchmark_samples/benchmark_corpus_mixed_v1_2)
  --output-dir <path>     Result dir (default: artifacts/speech-swift/<timestamp>)
  --model <hf-id>         Model id (default: tool default Parakeet-EOU-120M-CoreML-INT8)
  --subset <s>            smoke5 | rep15 | full (default: full)
  --chunk-ms <n>          Streaming chunk size (default: model config)
  --warmup                Silent warmup decode before timing
  --csv                   Also write results.csv
  --dry-run               Print plan + tool status; do not build or run
  --skip-build            Do not rebuild the isolated Swift tool
  --help, -h              Show this help

speech-swift lives only in tools/speech_swift_sidecar/Package.swift, never in the
production Package.swift.
EOF
}

CORPUS_DIR="benchmark_samples/benchmark_corpus_mixed_v1_2"
OUTPUT_DIR=""
MODEL=""
SUBSET="full"
CHUNK_MS=""
WARMUP=0
CSV=0
DRY_RUN=0
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus-dir) CORPUS_DIR="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --subset) SUBSET="$2"; shift 2 ;;
        --chunk-ms) CHUNK_MS="$2"; shift 2 ;;
        --warmup) WARMUP=1; shift ;;
        --csv) CSV=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    PY=(python3 "$SCRIPT_DIR/benchmark_speech_swift.py" --dry-run --corpus-dir "$CORPUS_DIR" --subset "$SUBSET")
    [[ -x "$TOOL_BIN" ]] && PY+=(--speech-swift-tool "$TOOL_BIN")
    "${PY[@]}"
    exit 0
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "SPEECH_SWIFT_BUILD:building isolated package at $PKG_DIR"
    if ! swift build -c release --package-path "$PKG_DIR"; then
        echo "ERROR: isolated speech-swift package failed to build. See output above." >&2
        exit 1
    fi
fi

if [[ ! -x "$TOOL_BIN" ]]; then
    echo "ERROR: speech-swift-benchmark not built at $TOOL_BIN" >&2
    exit 1
fi

TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUT="${OUTPUT_DIR:-artifacts/speech-swift/$TIMESTAMP}"

PY=(python3 "$SCRIPT_DIR/benchmark_speech_swift.py"
    --corpus-dir "$CORPUS_DIR"
    --speech-swift-tool "$TOOL_BIN"
    --subset "$SUBSET"
    --output-dir "$OUT")
[[ -n "$MODEL" ]] && PY+=(--model "$MODEL")
[[ -n "$CHUNK_MS" ]] && PY+=(--chunk-ms "$CHUNK_MS")
[[ "$WARMUP" -eq 1 ]] && PY+=(--warmup)
[[ "$CSV" -eq 1 ]] && PY+=(--csv)

echo "SPEECH_SWIFT_RUN:subset=$SUBSET output=$OUT"
"${PY[@]}"
