#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./scripts/benchmark.sh <path_to_audio_file.wav> [model_name]
  ./scripts/benchmark.sh --audio <path> [--model tiny.en] [--decode-profile accuracy] [--iterations 5] [--build release] [--output-dir artifacts/benchmarks] [--baseline-ms 500] [--budget-pct 10]
  ./scripts/benchmark.sh --corpus-dir <path> [--model tiny.en] [--decode-profile accuracy] [--build release]

Options:
  --audio <path>         Audio file to benchmark.
  --corpus-dir <path>    Directory containing wav files plus transcripts.json.
  --model <name>         Whisper model name without .bin suffix. Default: tiny.en
  --decode-profile <p>    Whisper decode profile: accuracy, balanced, or speed. Default: accuracy
  --iterations <count>   Number of benchmark runs to execute. Default: 1
  --build <mode>         Swift build mode: debug or release. Default: release
  --output-dir <path>    Directory for JSON benchmark artifacts. Default: artifacts/benchmarks
  --baseline-ms <value>  Optional latency baseline to compare against.
  --budget-pct <value>   Allowed regression percentage above baseline. Default: 10
EOF
}

AUDIO_FILE=""
CORPUS_DIR=""
MODEL_NAME="tiny.en"
DECODE_PROFILE="accuracy"
ITERATIONS=1
BUILD_MODE="release"
OUTPUT_DIR="artifacts/benchmarks"
BASELINE_MS=""
BUDGET_PCT=10

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

if [[ $# -ge 1 && "${1:-}" != --* ]]; then
    AUDIO_FILE="$1"
    shift
    if [[ $# -ge 1 && "${1:-}" != --* ]]; then
        MODEL_NAME="$1"
        shift
    fi
fi

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
        --model)
            MODEL_NAME="$2"
            shift 2
            ;;
        --decode-profile)
            DECODE_PROFILE="$2"
            shift 2
            ;;
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --build)
            BUILD_MODE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --baseline-ms)
            BASELINE_MS="$2"
            shift 2
            ;;
        --budget-pct)
            BUDGET_PCT="$2"
            shift 2
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

if [[ -z "$AUDIO_FILE" ]]; then
    if [[ -z "$CORPUS_DIR" ]]; then
        echo "Missing audio file or corpus directory." >&2
        usage
        exit 1
    fi
fi

if [[ -n "$CORPUS_DIR" ]]; then
    if [[ ! -d "$CORPUS_DIR" ]]; then
        echo "Corpus directory not found: $CORPUS_DIR" >&2
        exit 1
    fi
    if [[ ! -f "$CORPUS_DIR/transcripts.json" ]]; then
        echo "Corpus transcripts not found at $CORPUS_DIR/transcripts.json" >&2
        exit 1
    fi
fi

if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
    echo "Unsupported build mode: $BUILD_MODE" >&2
    exit 1
fi

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -lt 1 ]]; then
    echo "Iterations must be a positive integer." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ -n "$CORPUS_DIR" ]]; then
    python3 "$(dirname "$0")/benchmark.py" --corpus-dir "$CORPUS_DIR" --model "$MODEL_NAME" --decode-profile "$DECODE_PROFILE" --build "$BUILD_MODE"
    exit 0
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
    echo "Audio file not found: $AUDIO_FILE" >&2
    exit 1
fi

echo "Building VerificationRunner in $BUILD_MODE mode..."
swift build -c "$BUILD_MODE" --product VerificationRunner
BIN_PATH="$(swift build -c "$BUILD_MODE" --show-bin-path)"
RUNNER="$BIN_PATH/VerificationRunner"

if [[ ! -x "$RUNNER" ]]; then
    echo "Benchmark runner not found at $RUNNER" >&2
    exit 1
fi

declare -a LATENCIES=()
TRANSCRIPT=""
LAST_OUTPUT=""

for ((i = 1; i <= ITERATIONS; i++)); do
    echo "Benchmark iteration $i/$ITERATIONS..."
    OUTPUT="$("$RUNNER" --benchmark "$AUDIO_FILE" --model "$MODEL_NAME" --decode-profile "$DECODE_PROFILE")"
    LAST_OUTPUT="$OUTPUT"
    LATENCY="$(printf '%s\n' "$OUTPUT" | awk -F: '/^BENCHMARK_LATENCY_MS:/{print $2; exit}')"
    TRANSCRIPT_LINE="$(printf '%s\n' "$OUTPUT" | sed -n 's/^BENCHMARK_RESULT://p' | tail -n 1)"

    if [[ -z "$LATENCY" ]]; then
        printf '%s\n' "$OUTPUT"
        echo "Failed to parse BENCHMARK_LATENCY_MS from benchmark output." >&2
        exit 1
    fi

    LATENCIES+=("$LATENCY")
    if [[ -n "$TRANSCRIPT_LINE" ]]; then
        TRANSCRIPT="$TRANSCRIPT_LINE"
    fi
done

SORTED_LATENCIES="$(printf '%s\n' "${LATENCIES[@]}" | sort -n)"
MEDIAN_MS="$(printf '%s\n' "$SORTED_LATENCIES" | awk '
    { values[NR] = $1 }
    END {
        if (NR == 0) exit 1
        if (NR % 2 == 1) {
            print values[(NR + 1) / 2]
        } else {
            printf "%.0f\n", (values[NR / 2] + values[(NR / 2) + 1]) / 2
        }
    }'
)"

MEAN_MS="$(printf '%s\n' "${LATENCIES[@]}" | awk '{ sum += $1 } END { if (NR == 0) exit 1; printf "%.2f\n", sum / NR }')"
MIN_MS="$(printf '%s\n' "$SORTED_LATENCIES" | head -n 1)"
MAX_MS="$(printf '%s\n' "$SORTED_LATENCIES" | tail -n 1)"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
COMMIT_SHA="$(git rev-parse HEAD)"
ARTIFACT_BASENAME="benchmark-$(date -u +"%Y%m%dT%H%M%SZ")"
ARTIFACT_PATH="$OUTPUT_DIR/$ARTIFACT_BASENAME.json"
LATEST_PATH="$OUTPUT_DIR/latest.json"

{
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$TIMESTAMP"
    printf '  "commit": "%s",\n' "$COMMIT_SHA"
    printf '  "build_mode": "%s",\n' "$BUILD_MODE"
    printf '  "audio_file": "%s",\n' "$AUDIO_FILE"
    printf '  "model": "%s",\n' "$MODEL_NAME"
    printf '  "iterations": %s,\n' "$ITERATIONS"
    printf '  "latency_ms": {\n'
    printf '    "median": %s,\n' "$MEDIAN_MS"
    printf '    "mean": %s,\n' "$MEAN_MS"
    printf '    "min": %s,\n' "$MIN_MS"
    printf '    "max": %s\n' "$MAX_MS"
    printf '  },\n'
    printf '  "samples": [%s],\n' "$(printf '%s\n' "${LATENCIES[@]}" | paste -sd, -)"
    printf '  "transcript": %s\n' "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
    printf '}\n'
} > "$ARTIFACT_PATH"

cp "$ARTIFACT_PATH" "$LATEST_PATH"

echo "BENCHMARK_BUILD_MODE:$BUILD_MODE"
echo "BENCHMARK_ITERATIONS:$ITERATIONS"
echo "BENCHMARK_MEDIAN_MS:$MEDIAN_MS"
echo "BENCHMARK_MEAN_MS:$MEAN_MS"
echo "BENCHMARK_MIN_MS:$MIN_MS"
echo "BENCHMARK_MAX_MS:$MAX_MS"
echo "BENCHMARK_ARTIFACT:$ARTIFACT_PATH"
echo "BENCHMARK_LATEST:$LATEST_PATH"

if [[ -n "$BASELINE_MS" ]]; then
    ALLOWED_MS="$(awk -v baseline="$BASELINE_MS" -v pct="$BUDGET_PCT" 'BEGIN { printf "%.2f", baseline * (100 + pct) / 100 }')"
    echo "BENCHMARK_BASELINE_MS:$BASELINE_MS"
    echo "BENCHMARK_ALLOWED_MS:$ALLOWED_MS"

    if awk -v median="$MEDIAN_MS" -v allowed="$ALLOWED_MS" 'BEGIN { exit !(median > allowed) }'; then
        echo "BENCHMARK_REGRESSION:FAIL"
        echo "Median latency $MEDIAN_MS ms exceeded allowed budget $ALLOWED_MS ms." >&2
        exit 1
    fi

    echo "BENCHMARK_REGRESSION:PASS"
fi

if [[ -n "$LAST_OUTPUT" ]]; then
    printf '%s\n' "$LAST_OUTPUT"
fi
