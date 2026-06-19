# Source and License Notes

This corpus package contains several classes of audio. Treat them differently.

## Included in this zip

### Andrew recording clips

- Source: user-provided video recording `BetterCapture_2026-06-18-21.59.34.mov`.
- Status: user-owned/local benchmark material.
- Use: DexDictate primary-user benchmark and project-specific vocabulary testing.
- Redistribution: do not redistribute publicly unless Andrew explicitly chooses to.

### Synthetic support clips

- Source: locally generated `espeak` support clips created in the sandbox.
- Status: support-only, not default scoring.
- Use: plumbing checks, proper-noun stress, command stress.
- Limitation: synthetic speech is not a substitute for real human public speech.

## Not bundled, imported locally by Codex/tools

### LibriSpeech / OpenSLR12

- Official source: `https://www.openslr.org/12/`
- Recommended archive for this corpus: `dev-clean.tar.gz`
- License listed by OpenSLR: CC BY 4.0
- Why used: clean read English speech, 16 kHz, segmented and aligned.
- Tool: `tools/import_librispeech_archive.py`

### OpenSLR83 English dialect corpus

- Official source: `https://www.openslr.org/83/`
- Recommended starter archive: `midlands_english_female.zip`
- Required index: `line_index_all.csv`
- License listed by OpenSLR: Attribution-ShareAlike 4.0 International
- Why used: transcribed English speech from dialect groups in the UK and Ireland.
- Tool: `tools/import_openslr83_archive.py`

### Speech Commands

- Official TensorFlow Datasets page: `https://www.tensorflow.org/datasets/catalog/speech_commands`
- Optional direct archive used by tooling: `https://storage.googleapis.com/download.tensorflow.org/data/speech_commands_v0.02.tar.gz`
- Why used: one-word command/keyword stress testing.
- Limitation: keyword spotting samples are not normal dictation sentences.
- Tool: `tools/import_speech_commands_archive.py`

## Redistribution caution

Do not publish a corpus that includes imported public clips until source-specific license obligations are reviewed. This package is designed for local benchmark work first.
