#!/bin/bash
# Benchmark-only WhisperKit lane for DexDictate speech-engine exploration.
#
# Builds the ISOLATED Swift package under tools/whisperkit_sidecar (which is the
# only place WhisperKit is referenced — never the production app target), then
# runs scripts/benchmark_whisperkit.py against the shared 61-clip corpus and
# writes JSON results comparable to the SwiftWhisper and MLX lanes.
#
# This never touches production dictation, app settings, model defaults, signing,
# packaging, or build.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$REPO_ROOT/tools/whisperkit_sidecar"

usage() {
    cat <<'EOF'
Usage:
  ./scripts/benchmark_whisperkit.sh --corpus-dir <dir> [options]

Options:
  --corpus-dir <path>     Corpus directory (default: benchmark_samples/benchmark_corpus_mixed_v1_2)
  --model <name>          WhisperKit model id. May be repeated. Default: openai_whisper-tiny
                          Examples: openai_whisper-tiny, openai_whisper-base, openai_whisper-small,
                                    openai_whisper-large-v3-v20240930_turbo
  --output-dir <path>     Result directory. Default: artifacts/whisperkit/<timestamp>
  --download-base <path>  WhisperKit CoreML model cache. Default: artifacts/whisperkit-models
  --limit <n>             Process at most N clips.
  --dry-run               Print the plan and tool status; do not build or transcribe.
  --skip-build            Do not rebuild the Swift tool (use an existing binary).
  --help, -h              Show this help.

The WhisperKit dependency lives only in tools/whisperkit_sidecar/Package.swift,
never in the production Package.swift.
EOF
}

CORPUS_DIR="benchmark_samples/benchmark_corpus_mixed_v1_2"
OUTPUT_DIR=""
DOWNLOAD_BASE="artifacts/whisperkit-models"
LIMIT=""
DRY_RUN=0
SKIP_BUILD=0
MODELS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus-dir) CORPUS_DIR="$2"; shift 2 ;;
        --model) MODELS+=("$2"); shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --download-base) DOWNLOAD_BASE="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ "${#MODELS[@]}" -eq 0 ]]; then
    MODELS=("openai_whisper-tiny")
fi

TOOL_BIN="$PKG_DIR/.build/release/whisperkit-transcribe"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "WHISPERKIT_LANE_DRY_RUN:1"
    echo "WHISPERKIT_LANE_MODELS:${MODELS[*]}"
    PY_DRY=(python3 "$SCRIPT_DIR/benchmark_whisperkit.py" --dry-run --corpus-dir "$CORPUS_DIR" --model "${MODELS[0]}")
    [[ -x "$TOOL_BIN" ]] && PY_DRY+=(--whisperkit-tool "$TOOL_BIN")
    [[ -n "$LIMIT" ]] && PY_DRY+=(--limit "$LIMIT")
    "${PY_DRY[@]}"
    exit 0
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "WHISPERKIT_BUILD:building isolated package at $PKG_DIR"
    # Build only the isolated benchmark package; the production app is untouched.
    swift build -c release --package-path "$PKG_DIR"
fi

if [[ ! -x "$TOOL_BIN" ]]; then
    echo "ERROR: whisperkit-transcribe was not built at $TOOL_BIN" >&2
    exit 1
fi

TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
for model in "${MODELS[@]}"; do
    safe_model="${model//[^A-Za-z0-9_.-]/_}"
    if [[ -n "$OUTPUT_DIR" ]]; then
        out="$OUTPUT_DIR/$safe_model"
    else
        out="artifacts/whisperkit/$TIMESTAMP/$safe_model"
    fi
    echo "WHISPERKIT_RUN:model=$model output=$out"
    PY=(python3 "$SCRIPT_DIR/benchmark_whisperkit.py"
        --corpus-dir "$CORPUS_DIR"
        --model "$model"
        --whisperkit-tool "$TOOL_BIN"
        --download-base "$DOWNLOAD_BASE"
        --output-dir "$out")
    [[ -n "$LIMIT" ]] && PY+=(--limit "$LIMIT")
    "${PY[@]}"
done
