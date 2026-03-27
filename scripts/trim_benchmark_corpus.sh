#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <benchmark_corpus_dir> [output_dir]" >&2
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_DIR="${2:-${SOURCE_DIR%/}_trimmed}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Corpus directory not found: $SOURCE_DIR" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required but not installed." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

for metadata in benchmark_manifest.json transcripts.json; do
    if [[ -f "$SOURCE_DIR/$metadata" ]]; then
        cp "$SOURCE_DIR/$metadata" "$OUTPUT_DIR/$metadata"
    fi
done

find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.wav' | sort | while IFS= read -r file; do
    base_name="$(basename "$file")"
    tmp="$(mktemp "${OUTPUT_DIR}/${base_name}.trimmed.XXXXXX.wav")"
    ffmpeg -hide_banner -loglevel error -y \
        -i "$file" \
        -af "silenceremove=start_periods=1:start_duration=0.05:start_threshold=-55dB:stop_periods=1:stop_duration=0.20:stop_threshold=-55dB" \
        -c:a pcm_f32le \
        "$tmp"
    mv "$tmp" "$OUTPUT_DIR/$base_name"
done

echo "Trimmed WAV files from $SOURCE_DIR into $OUTPUT_DIR"
