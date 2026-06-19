#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./scripts/benchmark_speech_matrix.sh --corpus-dir sample_corpus [options]
  ./scripts/benchmark_speech_matrix.sh --audio path/to/file.wav [options]

Options:
  --corpus-dir <path>       Corpus directory with audio and transcripts.json.
  --audio <path>            Single wav file.
  --output-dir <path>       Result directory. Default: artifacts/speech-matrix/<timestamp>
  --swift-model <name>      SwiftWhisper model id to test. May be repeated.
  --decode-profile <name>   SwiftWhisper decode profile. Default: accuracy
  --build <mode>            Swift build mode. Default: release
  --mlx-model <name>        MLX-Audio model passed to {model}. Default: mlx-community/whisper-tiny
  --include-mlx             Include MLX-Audio when DEXDICTATE_MLX_AUDIO_CMD is configured.
  --require-mlx             Fail if MLX-Audio command is not configured.
  --skip-mlx                Skip MLX-Audio explicitly.
  --dry-run                 Print commands without executing them.
  --help, -h                Show this help.

MLX-Audio is external and benchmark-only. Configure it with:
  DEXDICTATE_MLX_AUDIO_CMD='python -m mlx_audio.transcribe --model {model} {audio}'
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"

AUDIO_FILE=""
CORPUS_DIR=""
OUTPUT_DIR="artifacts/speech-matrix/$TIMESTAMP"
DECODE_PROFILE="accuracy"
BUILD_MODE="release"
MLX_MODEL="mlx-community/whisper-tiny"
INCLUDE_MLX="auto"
REQUIRE_MLX=0
DRY_RUN=0
SWIFT_MODELS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --audio)
            AUDIO_FILE="$2"
            shift 2
            ;;
        --corpus-dir)
            CORPUS_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --swift-model)
            SWIFT_MODELS+=("$2")
            shift 2
            ;;
        --decode-profile)
            DECODE_PROFILE="$2"
            shift 2
            ;;
        --build)
            BUILD_MODE="$2"
            shift 2
            ;;
        --mlx-model)
            MLX_MODEL="$2"
            shift 2
            ;;
        --include-mlx)
            INCLUDE_MLX="yes"
            shift
            ;;
        --require-mlx)
            INCLUDE_MLX="yes"
            REQUIRE_MLX=1
            shift
            ;;
        --skip-mlx)
            INCLUDE_MLX="no"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$AUDIO_FILE" && -z "$CORPUS_DIR" ]]; then
    echo "Provide --audio or --corpus-dir." >&2
    usage
    exit 1
fi

if [[ -n "$AUDIO_FILE" && -n "$CORPUS_DIR" ]]; then
    echo "Use --audio or --corpus-dir, not both." >&2
    exit 1
fi

if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
    echo "Unsupported build mode: $BUILD_MODE" >&2
    exit 1
fi

if [[ "$DECODE_PROFILE" != "accuracy" && "$DECODE_PROFILE" != "balanced" && "$DECODE_PROFILE" != "speed" ]]; then
    echo "Unsupported decode profile: $DECODE_PROFILE" >&2
    exit 1
fi

if [[ -n "$CORPUS_DIR" ]]; then
    if [[ ! -d "$CORPUS_DIR" ]]; then
        echo "Corpus directory not found: $CORPUS_DIR" >&2
        exit 1
    fi
    if [[ ! -f "$CORPUS_DIR/transcripts.json" && ! -f "$CORPUS_DIR/benchmark_manifest.json" ]]; then
        echo "Corpus must contain transcripts.json or benchmark_manifest.json: $CORPUS_DIR" >&2
        exit 1
    fi
fi

if [[ -n "$AUDIO_FILE" && ! -f "$AUDIO_FILE" ]]; then
    echo "Audio file not found: $AUDIO_FILE" >&2
    exit 1
fi

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

run_logged() {
    local log_path="$1"
    shift
    echo "+ $(quote_command "$@")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi
    "$@" 2>&1 | tee "$log_path"
}

model_file_exists() {
    local model="$1"
    [[ -f "$REPO_ROOT/Sources/DexDictateKit/Resources/$model.bin" ]] && return 0
    [[ -f "$HOME/Library/Application Support/DexDictate/Models/$model.bin" ]] && return 0
    [[ -f "$HOME/Library/Application Support/DexDictate/Models/ggml-$model.bin" ]] && return 0
    return 1
}

if [[ "${#SWIFT_MODELS[@]}" -eq 0 ]]; then
    for model in tiny.en base base.en small small.en; do
        if model_file_exists "$model"; then
            SWIFT_MODELS+=("$model")
        fi
    done
fi

if [[ "${#SWIFT_MODELS[@]}" -eq 0 ]]; then
    echo "No SwiftWhisper models found." >&2
    exit 1
fi

echo "SPEECH_MATRIX_OUTPUT_DIR:$OUTPUT_DIR"
echo "SPEECH_MATRIX_SWIFT_MODELS:${SWIFT_MODELS[*]}"
echo "SPEECH_MATRIX_DECODE_PROFILE:$DECODE_PROFILE"
echo "SPEECH_MATRIX_BUILD:$BUILD_MODE"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$OUTPUT_DIR/swiftwhisper" "$OUTPUT_DIR/mlx-audio"
fi

for model in "${SWIFT_MODELS[@]}"; do
    safe_model="${model//[^A-Za-z0-9_.-]/_}"
    if [[ -n "$CORPUS_DIR" ]]; then
        run_logged "$OUTPUT_DIR/swiftwhisper/$safe_model.log" \
            python3 "$SCRIPT_DIR/benchmark.py" \
                --corpus-dir "$CORPUS_DIR" \
                --model "$model" \
                --decode-profile "$DECODE_PROFILE" \
                --build "$BUILD_MODE" \
                --json-output "$OUTPUT_DIR/swiftwhisper/$safe_model.json" \
                --csv-output "$OUTPUT_DIR/swiftwhisper/$safe_model.csv"
    else
        run_logged "$OUTPUT_DIR/swiftwhisper/$safe_model.log" \
            "$SCRIPT_DIR/benchmark.sh" \
                --audio "$AUDIO_FILE" \
                --model "$model" \
                --decode-profile "$DECODE_PROFILE" \
                --build "$BUILD_MODE" \
                --output-dir "$OUTPUT_DIR/swiftwhisper/$safe_model"
    fi
done

MLX_CONFIGURED=0
if [[ -n "${DEXDICTATE_MLX_AUDIO_CMD:-}" ]]; then
    MLX_CONFIGURED=1
fi

if [[ "$INCLUDE_MLX" == "no" ]]; then
    echo "SPEECH_MATRIX_MLX:skipped"
elif [[ "$MLX_CONFIGURED" -eq 0 ]]; then
    echo "SPEECH_MATRIX_MLX:skipped DEXDICTATE_MLX_AUDIO_CMD is not set"
    if [[ "$REQUIRE_MLX" -eq 1 ]]; then
        exit 2
    fi
else
    MLX_ARGS=(python3 "$SCRIPT_DIR/benchmark_mlx_audio.py" --model "$MLX_MODEL" --output-dir "$OUTPUT_DIR/mlx-audio")
    if [[ -n "$CORPUS_DIR" ]]; then
        MLX_ARGS+=(--corpus-dir "$CORPUS_DIR")
    else
        MLX_ARGS+=(--audio "$AUDIO_FILE")
    fi
    run_logged "$OUTPUT_DIR/mlx-audio/mlx-audio.log" "${MLX_ARGS[@]}"
fi

echo "SPEECH_MATRIX_DONE:$OUTPUT_DIR"

