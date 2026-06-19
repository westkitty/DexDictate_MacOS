# WhisperKit Benchmark Lane (exploration only)

Status: **benchmark-only.** WhisperKit is **not** wired into production DexDictate
dictation, and per the exploration boundary it must not change output insertion,
the clipboard, Accessibility insertion, secure-field handling, focus matching,
permissions, audio route recovery, CoreAudio `-10868` handling, signing,
packaging, entitlements, plist metadata, notarization, `build.sh`, the default
model, or remove SwiftWhisper.

## Why an isolated Swift package (not the production target)

WhisperKit is a Swift/CoreML package. The obvious-but-wrong move would be to add
it to the root `Package.swift`. That would pull WhisperKit + its CoreML model
machinery into the shipped, notarized app target and into `build.sh`/release.

Instead this lane lives in a **separate, self-contained package**:

```
tools/whisperkit_sidecar/
  Package.swift                              # depends on WhisperKit; root Package.swift untouched
  Sources/whisperkit-transcribe/main.swift   # benchmark CLI: audio in, JSON out
  .gitignore                                  # ignores .build/ and Package.resolved
```

The production `Package.swift` is **unchanged** (verified with
`git diff --name-only -- '*.swift'`). Nothing here can leak into the app: the app
target does not depend on this package, and `build.sh` never builds it.

## Architecture (parity with the MLX lane)

```
benchmark_whisperkit.sh
  └─ swift build -c release --package-path tools/whisperkit_sidecar   (isolated)
  └─ benchmark_whisperkit.py
        ├─ loads the 61-clip corpus (same loader as the MLX driver)
        ├─ runs whisperkit-transcribe ONCE in batch mode (model loaded once → warm)
        └─ scores WER / punctuation-aware WER / proper-noun hits / latency
           and writes summary.json with the SAME field shape as the MLX lane
```

The Swift tool loads the model a single time and transcribes the whole corpus in
one process, so per-file latency is **warm** and directly comparable to the MLX
*module-mode* numbers (not the impractical MLX wrapper/cold per-file reload).

The scoring helpers and JSON result shape in `benchmark_whisperkit.py` are
intentionally identical to `scripts/benchmark_mlx_audio.py` so SwiftWhisper, MLX,
and WhisperKit results line up field-for-field.

## Usage

```bash
# Plan only (no build, no transcription)
./scripts/benchmark_whisperkit.sh --dry-run \
  --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2

# Build the isolated tool and run a single model
./scripts/benchmark_whisperkit.sh \
  --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \
  --model openai_whisper-tiny \
  --output-dir artifacts/whisperkit/tiny

# Several models in one go
./scripts/benchmark_whisperkit.sh \
  --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \
  --model openai_whisper-tiny \
  --model openai_whisper-base \
  --model openai_whisper-small \
  --model openai_whisper-large-v3-v20240930_turbo
```

Models are WhisperKit/HuggingFace ids from `argmaxinc/whisperkit-coreml`. Common
ones: `openai_whisper-tiny`, `openai_whisper-base`, `openai_whisper-small`,
`openai_whisper-large-v3-v20240930_turbo` (turbo). WhisperKit also matches short
names like `tiny`/`base`/`small`.

## Result JSON (per run)

`summary.json` mirrors the MLX/SwiftWhisper shape:

- top level: `backend` (`whisperkit`), `backend_mode` (`swift-batch`), `model`,
  `corpus_dir`, `download_base`, `started_at` / `finished_at`, `model_load_ms`,
  `audio_count`, `processed_count`, `failed_count`, `skipped_count`, `status`,
  `results[]`, `summary{}`.
- `summary{}`: `avg_wer`, `avg_punctuation_aware_wer`, `avg_latency_ms`,
  `p95_latency_ms`, `empty_output_rate`.
- each result: `audio_path`, `id`, `category`, `source`, `expected`, `text`,
  `duration_ms`, `wer`, `punctuation_aware_wer`, `proper_noun_hits`,
  `empty_output`, `missing_first_word_proxy`, `missing_last_word_proxy`, `error`.

## Model download / cache behavior

- WhisperKit downloads CoreML model variants from `argmaxinc/whisperkit-coreml`
  on first use into the `--download-base` directory (default
  `artifacts/whisperkit-models`, which is **git-ignored**).
- Subsequent runs reuse the cache (no re-download).
- A production path must never download silently; any future integration must
  surface model download/size to the user, consistent with the existing Whisper
  model-discovery flow.

## Privacy

- Recognized and reference transcripts are written only to result files under the
  git-ignored `artifacts/` tree. Nothing is logged to app diagnostics. The Swift
  tool writes JSON to an `--out` file (not stdout) precisely so WhisperKit's own
  console logging cannot contaminate or leak transcript data into a pipe.

## Packaging implications (the real production question)

- **App size / footprint:** WhisperKit bundles CoreML model assets and the
  WhisperKit runtime. A one-time **CoreML Apple-Neural-Engine specialization** is
  needed per model/machine, costing up to ~3 min for `small`. It is now fully
  characterized **and mitigated**: `WhisperKitConfig(prewarm: true)` shifts the
  encoder compile into model load, and **one synthetic silent dummy decode** during
  prep absorbs the text-decoder residual, leaving the user's first real dictation
  warm (small ~1 s). See
  [`WHISPERKIT_PREWARM_INVESTIGATION.md`](WHISPERKIT_PREWARM_INVESTIGATION.md).
- **No Python, unlike the MLX lane:** WhisperKit is native Swift/CoreML, so —
  unlike the MLX benchmark which needs a `.venv_mlx_audio` Python environment —
  WhisperKit is a *plausible* production packaging path. That is the main reason
  this lane exists: it tests the native, shippable alternative the MLX numbers
  motivated.
- **macOS floor:** WhisperKit requires macOS 14+. DexDictate already targets
  macOS 14, so this is not a new constraint.
- **Still blocked for production** until the decision gates in
  [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md) are met and a test-only
  `DexDictateSpeechEngine` adapter (see
  [`SPEECH_ENGINE_ABSTRACTION_DRAFT.md`](SPEECH_ENGINE_ABSTRACTION_DRAFT.md)) is
  built and characterization-tested.

## Results

See the WhisperKit section of [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md) for
the measured numbers and the cross-engine comparison.
