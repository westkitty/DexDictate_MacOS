# Public Dataset Import Guide

This package is intentionally split into two layers:

1. **Bundled layer:** Andrew-specific benchmark clips and local synthetic support clips.
2. **Local import layer:** public speech clips that Codex should download/import on Andrew's Mac.

The sandbox that created this package could not download public audio archives, so the package includes tools and instructions rather than pretending public clips were bundled. Correct. Annoying, but correct.

## Recommended first public augmentation

Run this from the corpus root after unzipping the package into the DexDictate repo:

```bash
cd /Users/andrew/DexDictate_MacOS.nosync/benchmark_corpus_mixed_v1_2

tools/build_public_augmented_corpus.sh \
  --download \
  --max-librispeech 15 \
  --max-slr83 10
```

This will:

1. Download LibriSpeech `dev-clean.tar.gz` from OpenSLR12.
2. Download OpenSLR83 `line_index_all.csv`, `LICENSE`, and `midlands_english_female.zip`.
3. Import a small number of clips into:
   - `audio/public_librispeech/`
   - `audio/public_openslr83/`
4. Write public manifests:
   - `transcripts_public_librispeech.json`
   - `transcripts_public_openslr83.json`
5. Merge them with `transcripts_default_gold.json` into:
   - `transcripts_mixed_public.json`
6. Activate the merged manifest as `transcripts.json`.
7. Run corpus validation.

## Optional Speech Commands import

Speech Commands is useful for one-word command stress testing, but it is large. TensorFlow Datasets lists its download size as 2.37 GiB and extracted dataset size as 8.17 GiB.

Only include it if you have space and want keyword/command clips:

```bash
cd /Users/andrew/DexDictate_MacOS.nosync/benchmark_corpus_mixed_v1_2

tools/build_public_augmented_corpus.sh \
  --download \
  --include-speech-commands \
  --max-librispeech 15 \
  --max-slr83 10 \
  --max-speech-commands 10
```

## Dry run first

```bash
tools/build_public_augmented_corpus.sh --download --dry-run
```

## Expected resulting manifest sizes

Without Speech Commands:

- 36 Andrew gold clips
- up to 15 LibriSpeech clips
- up to 10 OpenSLR83 accent clips
- expected total: up to 61 scoring clips

With Speech Commands:

- same as above
- plus up to 10 command-word clips
- expected total: up to 71 scoring clips

## Why these sources

- **LibriSpeech/OpenSLR12:** clean read English speech, 16 kHz, carefully segmented and aligned.
- **OpenSLR83:** UK/Ireland English dialect speech with transcriptions and dialect variety.
- **Speech Commands:** one-word keyword/command stress testing, not full dictation.

## Do not use random internet videos

Random online videos usually lack exact transcripts, licensing clarity, stable segmentation, or clean file boundaries. They make benchmark numbers look scientific while quietly making them garbage.

## After import

Run:

```bash
python3 tools/validate_corpus.py .
python3 tools/select_manifest.py --list
```

Then from the DexDictate repo root:

```bash
./scripts/benchmark_speech_matrix.sh --corpus-dir benchmark_corpus_mixed_v1_2
```
