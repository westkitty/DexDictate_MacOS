# Corpus QA Report

## Result

PASS: file integrity and audio format validation succeeded.

## Counts

- gold_default_scoring: 36
- review_fast_plausible: 9
- hard_excluded: 5
- synthetic_support: 25
- total_wav: 75
- total_manifest_all: 75

## Format checks

- validation errors: 0
- validation warnings: 0
- all included WAVs are referenced by `transcripts_all.json`
- every default `transcripts.json` entry resolves to an existing WAV
- all included WAVs are 16 kHz mono 16-bit PCM

## Benchmark policy

- `transcripts.json` is now strict by default: 36 Andrew clips that passed duration sanity.
- `transcripts_andrew_scored_full.json` includes 45 Andrew clips: 36 gold plus 9 fast-but-plausible review clips.
- `transcripts_andrew_review.json` contains the 9 review clips only.
- `transcripts_andrew_excluded.json` contains 5 hard mismatch clips and should not be used for engine ranking.
- `transcripts_synthetic_support.json` contains 25 eSpeak support clips and should not be used for final engine selection.

## Validation warnings

- none

## Validation errors

- none

## v1.2 Enhancement QA

Added local public-data augmentation tooling. These tools were syntax-checked/help-checked where possible in the sandbox, but public dataset downloads were not performed here.

New public-data targets:

- `audio/public_librispeech/`
- `audio/public_openslr83/`
- `audio/public_speech_commands/`
- `downloads/`

New tools:

- `tools/fetch_public_datasets.sh`
- `tools/build_public_augmented_corpus.sh`
- `tools/import_openslr83_archive.py`
- `tools/import_speech_commands_archive.py`

New docs:

- `docs/PUBLIC_DATASET_IMPORT_GUIDE.md`
- `docs/CODEX_PUBLIC_DATASET_IMPORT_PROMPT.md`

Validation status after enhancement:

- Existing bundled audio remains valid.
- Default active manifest remains strict Andrew-gold only.
- Public import manifests are intentionally absent until Codex/local tooling downloads and imports public archives.
- `mixed-public` manifest mode becomes available only after local import creates `transcripts_mixed_public.json`.
