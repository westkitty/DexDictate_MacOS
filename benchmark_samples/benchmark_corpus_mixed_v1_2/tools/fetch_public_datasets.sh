#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="$ROOT/downloads"
FETCH_LIBRISPEECH=0
FETCH_SLR83=0
FETCH_SPEECH_COMMANDS=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Fetch public speech dataset archives for DexDictate benchmark augmentation.

Default: dry, explicit flags required. Archives are large.

Usage:
  tools/fetch_public_datasets.sh [options]

Options:
  --downloads-dir PATH          Where archives are saved. Default: corpus/downloads
  --librispeech-dev-clean       Download OpenSLR12 dev-clean.tar.gz (~337 MB)
  --librispeech-test-clean      Download OpenSLR12 test-clean.tar.gz (~346 MB)
  --slr83-small                 Download OpenSLR83 line index + midlands female zip (~105 MB + index)
  --speech-commands             Download Speech Commands v0.02 archive (~2.37 GiB; optional)
  --all-recommended             Download LibriSpeech dev-clean + SLR83 small; skips Speech Commands
  --dry-run                     Print commands only
  -h, --help                    Show help

Notes:
  - This script only downloads archives. It does not alter transcripts.json.
  - Run tools/build_public_augmented_corpus.sh after download/import.
EOF
}

queue=()
add_download() {
  local url="$1" out="$2"
  queue+=("$url|$out")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --downloads-dir) DOWNLOAD_DIR="$2"; shift 2 ;;
    --librispeech-dev-clean) FETCH_LIBRISPEECH=1; LIBRISPEECH_KIND="dev-clean"; shift ;;
    --librispeech-test-clean) FETCH_LIBRISPEECH=1; LIBRISPEECH_KIND="test-clean"; shift ;;
    --slr83-small) FETCH_SLR83=1; shift ;;
    --speech-commands) FETCH_SPEECH_COMMANDS=1; shift ;;
    --all-recommended) FETCH_LIBRISPEECH=1; LIBRISPEECH_KIND="dev-clean"; FETCH_SLR83=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$DOWNLOAD_DIR"
LIBRISPEECH_KIND="${LIBRISPEECH_KIND:-dev-clean}"

if [[ "$FETCH_LIBRISPEECH" == "1" ]]; then
  case "$LIBRISPEECH_KIND" in
    dev-clean) add_download "https://www.openslr.org/resources/12/dev-clean.tar.gz" "$DOWNLOAD_DIR/librispeech-dev-clean.tar.gz" ;;
    test-clean) add_download "https://www.openslr.org/resources/12/test-clean.tar.gz" "$DOWNLOAD_DIR/librispeech-test-clean.tar.gz" ;;
    *) echo "Unsupported LibriSpeech kind: $LIBRISPEECH_KIND" >&2; exit 2 ;;
  esac
  add_download "https://www.openslr.org/resources/12/md5sum.txt" "$DOWNLOAD_DIR/librispeech-md5sum.txt"
fi

if [[ "$FETCH_SLR83" == "1" ]]; then
  add_download "https://www.openslr.org/resources/83/line_index_all.csv" "$DOWNLOAD_DIR/slr83-line_index_all.csv"
  add_download "https://www.openslr.org/resources/83/midlands_english_female.zip" "$DOWNLOAD_DIR/slr83-midlands_english_female.zip"
  add_download "https://www.openslr.org/resources/83/LICENSE" "$DOWNLOAD_DIR/slr83-LICENSE"
fi

if [[ "$FETCH_SPEECH_COMMANDS" == "1" ]]; then
  add_download "https://storage.googleapis.com/download.tensorflow.org/data/speech_commands_v0.02.tar.gz" "$DOWNLOAD_DIR/speech_commands_v0.02.tar.gz"
fi

if [[ "${#queue[@]}" -eq 0 ]]; then
  echo "No datasets selected. Use --all-recommended or an explicit dataset flag." >&2
  usage
  exit 2
fi

for item in "${queue[@]}"; do
  url="${item%%|*}"
  out="${item#*|}"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "curl -L --fail --continue-at - --output '$out' '$url'"
  else
    echo "Fetching $url"
    curl -L --fail --continue-at - --output "$out" "$url"
  fi
done

if [[ "$DRY_RUN" == "0" ]]; then
  echo "Downloaded archives to: $DOWNLOAD_DIR"
fi
