#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="$ROOT/downloads"
DOWNLOAD=0
DRY_RUN=0
INCLUDE_SPEECH_COMMANDS=0
MAX_LIBRISPEECH=15
MAX_SLR83=10
MAX_SPEECH_COMMANDS=10

usage() {
  cat <<'EOF'
Build a public-augmented DexDictate benchmark manifest on a local Mac.

This script imports public dataset clips that could not be bundled in the sandbox.
It keeps production DexDictate untouched.

Usage:
  tools/build_public_augmented_corpus.sh [options]

Options:
  --download                    Download recommended archives first
  --downloads-dir PATH          Archive/cache directory. Default: corpus/downloads
  --include-speech-commands     Include Speech Commands one-word clips; downloads huge archive if --download is used
  --max-librispeech N           Default 15
  --max-slr83 N                 Default 10
  --max-speech-commands N       Default 10
  --dry-run                     Print what would run
  -h, --help                    Show help

Recommended local command:
  tools/build_public_augmented_corpus.sh --download --max-librispeech 15 --max-slr83 10

After this succeeds:
  ./scripts/benchmark_speech_matrix.sh --corpus-dir benchmark_corpus_mixed_v1_2
EOF
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download) DOWNLOAD=1; shift ;;
    --downloads-dir) DOWNLOAD_DIR="$2"; shift 2 ;;
    --include-speech-commands) INCLUDE_SPEECH_COMMANDS=1; shift ;;
    --max-librispeech) MAX_LIBRISPEECH="$2"; shift 2 ;;
    --max-slr83) MAX_SLR83="$2"; shift 2 ;;
    --max-speech-commands) MAX_SPEECH_COMMANDS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$DOWNLOAD_DIR"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required for import. Install with: brew install ffmpeg" >&2
  exit 1
fi

if [[ "$DOWNLOAD" == "1" ]]; then
  fetch_args=("$ROOT/tools/fetch_public_datasets.sh" "--downloads-dir" "$DOWNLOAD_DIR" "--all-recommended")
  if [[ "$INCLUDE_SPEECH_COMMANDS" == "1" ]]; then
    fetch_args+=("--speech-commands")
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    # Execute the fetch helper in dry-run mode so it prints the actual curl commands.
    "${fetch_args[@]}" --dry-run
  else
    "${fetch_args[@]}"
  fi
fi

LIBRI="$DOWNLOAD_DIR/librispeech-dev-clean.tar.gz"
SLR83_INDEX="$DOWNLOAD_DIR/slr83-line_index_all.csv"
SLR83_ZIP="$DOWNLOAD_DIR/slr83-midlands_english_female.zip"
SPEECH_COMMANDS="$DOWNLOAD_DIR/speech_commands_v0.02.tar.gz"

if [[ -f "$LIBRI" ]]; then
  run python3 "$ROOT/tools/import_librispeech_archive.py" --archive "$LIBRI" --output-dir "$ROOT" --max-clips "$MAX_LIBRISPEECH"
else
  echo "Skipping LibriSpeech import; missing $LIBRI"
fi

if [[ -f "$SLR83_INDEX" && -f "$SLR83_ZIP" ]]; then
  run python3 "$ROOT/tools/import_openslr83_archive.py" --line-index "$SLR83_INDEX" --archive "$SLR83_ZIP" --output-dir "$ROOT" --max-clips "$MAX_SLR83"
else
  echo "Skipping OpenSLR83 import; missing index or archive"
fi

if [[ "$INCLUDE_SPEECH_COMMANDS" == "1" ]]; then
  if [[ -f "$SPEECH_COMMANDS" ]]; then
    run python3 "$ROOT/tools/import_speech_commands_archive.py" --archive "$SPEECH_COMMANDS" --output-dir "$ROOT" --max-clips "$MAX_SPEECH_COMMANDS"
  else
    echo "Skipping Speech Commands import; missing $SPEECH_COMMANDS"
  fi
fi

merge_inputs=("$ROOT/transcripts_default_gold.json")
for candidate in \
  "$ROOT/transcripts_public_librispeech.json" \
  "$ROOT/transcripts_public_openslr83.json" \
  "$ROOT/transcripts_public_speech_commands.json"; do
  if [[ -f "$candidate" ]]; then
    merge_inputs+=("$candidate")
  fi
done

run python3 "$ROOT/tools/merge_transcripts.py" --output "$ROOT/transcripts_mixed_public.json" "${merge_inputs[@]}"
run python3 "$ROOT/tools/select_manifest.py" --root "$ROOT" mixed-public
run python3 "$ROOT/tools/validate_corpus.py" "$ROOT"

if [[ "$DRY_RUN" == "0" ]]; then
  echo "Public-augmented manifest is active: $ROOT/transcripts.json"
fi
