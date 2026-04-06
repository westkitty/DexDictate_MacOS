#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT_DIR/Sources/DexDictateKit/Resources"
DEST_PATH="$DEST_DIR/tiny.en.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin?download=true"
MODEL_SHA256="921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f"

compute_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

mkdir -p "$DEST_DIR"

if [ -f "$DEST_PATH" ]; then
    EXISTING_SHA="$(compute_sha256 "$DEST_PATH")"
    if [ "$EXISTING_SHA" = "$MODEL_SHA256" ]; then
        printf 'Model already present and verified at %s\n' "$DEST_PATH"
        exit 0
    fi

    printf 'Checksum mismatch for existing model at %s; re-downloading.\n' "$DEST_PATH" >&2
    rm -f "$DEST_PATH"
fi

TEMP_PATH="$(mktemp "$DEST_DIR/tiny.en.bin.download.XXXXXX")"
cleanup() {
    rm -f "$TEMP_PATH"
}
trap cleanup EXIT

printf 'Downloading tiny.en model from %s\n' "$MODEL_URL"
curl \
    --fail \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --output "$TEMP_PATH" \
    "$MODEL_URL"

DOWNLOADED_SHA="$(compute_sha256 "$TEMP_PATH")"
if [ "$DOWNLOADED_SHA" != "$MODEL_SHA256" ]; then
    printf 'Checksum mismatch for downloaded model.\nExpected: %s\nActual:   %s\n' "$MODEL_SHA256" "$DOWNLOADED_SHA" >&2
    exit 1
fi

mv "$TEMP_PATH" "$DEST_PATH"
chmod 0644 "$DEST_PATH"
printf 'Model downloaded and verified at %s\n' "$DEST_PATH"
