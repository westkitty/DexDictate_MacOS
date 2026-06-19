# DexDictate Mixed Benchmark Corpus v1.2

This is the enhanced DexDictate speech-engine benchmark corpus package.

It contains Andrew's cleaned benchmark clips, support-only synthetic clips, validation tools, and local automation for Codex to download/import public speech datasets that could not be bundled by the sandbox.

## What changed from v1.1

- Kept the strict default manifest: `transcripts.json` still contains only the 36 safest Andrew clips.
- Added public dataset automation:
  - `tools/fetch_public_datasets.sh`
  - `tools/build_public_augmented_corpus.sh`
  - `tools/import_openslr83_archive.py`
  - `tools/import_speech_commands_archive.py`
- Improved manifest selection so public manifests can be activated after import.
- Improved manifest merging with duplicate checks.
- Added public import documentation:
  - `docs/PUBLIC_DATASET_IMPORT_GUIDE.md`
  - `docs/CODEX_PUBLIC_DATASET_IMPORT_PROMPT.md`
- Updated license/source notes for public sources.
- Added empty import targets:
  - `audio/public_librispeech/`
  - `audio/public_openslr83/`
  - `audio/public_speech_commands/`
  - `downloads/`

## Default benchmark mode

The default active manifest is strict:

```text
transcripts.json -> 36 Andrew gold clips
```

Run from the DexDictate repo root:

```bash
./scripts/benchmark_speech_matrix.sh --corpus-dir benchmark_corpus_mixed_v1_2
```

## Recommended public augmentation

After unzipping into the DexDictate repo, hand the Codex prompt to Codex:

```text
docs/CODEX_PUBLIC_DATASET_IMPORT_PROMPT.md
```

Or run the automation yourself from the corpus root:

```bash
cd /Users/andrew/DexDictate_MacOS.nosync/benchmark_corpus_mixed_v1_2

tools/build_public_augmented_corpus.sh \
  --download \
  --max-librispeech 15 \
  --max-slr83 10
```

That should produce an active public-augmented `transcripts.json` containing:

- 36 Andrew gold clips
- up to 15 LibriSpeech clean read-English clips
- up to 10 OpenSLR83 accent/dialect clips

Expected total: up to 61 scoring clips.

## Optional command-word import

Speech Commands is optional because it is large and is not normal dictation. Use it only if you want command/keyword stress clips:

```bash
tools/build_public_augmented_corpus.sh \
  --download \
  --include-speech-commands \
  --max-librispeech 15 \
  --max-slr83 10 \
  --max-speech-commands 10
```

## Manifest switching

List available manifests:

```bash
python3 tools/select_manifest.py --list
```

Common modes:

```bash
python3 tools/select_manifest.py gold
python3 tools/select_manifest.py andrew-full
python3 tools/select_manifest.py synthetic
python3 tools/select_manifest.py mixed-public
```

`mixed-public` exists only after public import succeeds.

## Validate package integrity

```bash
python3 tools/validate_corpus.py .
```

## Directory layout

```text
benchmark_corpus_mixed_v1_2/
  audio/andrew_gold/              # 36 strict default clips
  audio/andrew_review/            # 9 fast-but-plausible review clips
  audio/andrew_excluded/          # 5 hard mismatch clips, not scoring
  audio/synthetic_support/        # 25 generated clips, support only
  audio/public_librispeech/       # target for local LibriSpeech import
  audio/public_openslr83/         # target for local OpenSLR83 import
  audio/public_speech_commands/   # target for optional Speech Commands import
  downloads/                      # local archive cache, empty in zip
  docs/CODEX_PUBLIC_DATASET_IMPORT_PROMPT.md
  docs/PUBLIC_DATASET_IMPORT_GUIDE.md
  docs/QA_REPORT.md
  docs/audio_sha256.csv
  transcripts.json                # active benchmark manifest, strict by default
  transcripts_default_gold.json
  transcripts_andrew_review.json
  transcripts_andrew_scored_full.json
  transcripts_andrew_excluded.json
  transcripts_synthetic_support.json
  transcripts_all.json
  tools/build_public_augmented_corpus.sh
  tools/fetch_public_datasets.sh
  tools/import_librispeech_archive.py
  tools/import_openslr83_archive.py
  tools/import_speech_commands_archive.py
  tools/merge_transcripts.py
  tools/select_manifest.py
  tools/validate_corpus.py
```

## Practical judgment

Use v1.2 as the working package. It stops making Andrew do more recording and gives Codex the annoying download/import work. The default is safe now; public augmentation is scripted; synthetic clips stay out of final engine ranking unless deliberately selected.
