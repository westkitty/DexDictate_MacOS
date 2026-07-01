# Speech Engine Exploration

This directory is for benchmark-only speech engine experiments. It is not production
architecture, not a replacement for SwiftWhisper, and not a change to dictation output
behavior.

## Boundary

Allowed here:

- Compare local speech-to-text engines against the existing SwiftWhisper benchmark path.
- Record latency, word error rate (WER), command phrase behavior, punctuation behavior,
  and failure modes.
- Prototype MLX-Audio as an external, benchmark-only command or sidecar candidate.

Not allowed here:

- Changing production output insertion, clipboard delivery, Accessibility insertion, or
  focused-field matching.
- Changing secure-field behavior.
- Changing audio route recovery, CoreAudio recovery, or `-10868` handling.
- Changing signing, release packaging, entitlements, plist files, notarization, or
  `build.sh`.
- Changing the default model, removing SwiftWhisper, adding cloud speech APIs, adding
  telemetry, or routing live dictation through an experimental engine.

Those systems are separate on purpose. Mixing them with engine exploration makes
results harder to trust and failures harder to diagnose. Dull, but correct.

## Existing Source Of Truth

- `BIBLE.md` and `docs/DEXDICTATE_BIBLE.md` remain the architecture philosophy.
- `docs/DEXDICTATE_FILE_MAP.md` is the repository map.
- `docs/DexDictate_Strict_Experiment_Matrix.md` is the strict recovery matrix for
  production speech-to-text work.
- This directory is a sidecar for exploratory benchmark evidence only.

## Scripts

### SwiftWhisper Baseline

Current baseline command:

```bash
./scripts/benchmark.sh --corpus-dir sample_corpus --model tiny.en --decode-profile accuracy --build release
```

Structured JSON/CSV output:

```bash
python3 scripts/benchmark.py \
  --corpus-dir sample_corpus \
  --model tiny.en \
  --decode-profile accuracy \
  --build release \
  --json-output artifacts/speech-matrix/swiftwhisper-tiny.en.json \
  --csv-output artifacts/speech-matrix/swiftwhisper-tiny.en.csv
```

### Matrix Runner

Dry-run the local matrix:

```bash
./scripts/benchmark_speech_matrix.sh --dry-run --corpus-dir sample_corpus
```

Run the SwiftWhisper lanes and skip MLX-Audio unless configured:

```bash
./scripts/benchmark_speech_matrix.sh --corpus-dir sample_corpus
```

Include MLX-Audio when an external command is configured:

```bash
DEXDICTATE_MLX_AUDIO_CMD='python -m mlx_audio.transcribe --model {model} {audio}' \
  ./scripts/benchmark_speech_matrix.sh --corpus-dir sample_corpus --include-mlx
```

The exact MLX-Audio command is intentionally supplied by environment variable. The
project should not bake an unstable third-party command-line interface into production
code.

### MLX-Audio Adapter

> **Environment note.** The default `python3` here is **Python 3.14**, but the
> MLX tooling currently requires **`python3.13`**. Use the isolated
> **`.venv_mlx_audio`** environment (`scripts/setup_mlx_audio_env.sh`) and run
> wrapper commands with **`.venv_mlx_audio/bin/python`**, not the system
> `python3`. `.venv_mlx_audio/` is git-ignored via `.venv*/`, and artifacts go
> under the git-ignored `artifacts/`.

Dry-run only:

```bash
python3 scripts/benchmark_mlx_audio.py --dry-run --corpus-dir sample_corpus
```

Run one configured MLX-Audio command against a corpus:

```bash
DEXDICTATE_MLX_AUDIO_CMD='python -m mlx_audio.transcribe --model {model} {audio}' \
  python3 scripts/benchmark_mlx_audio.py \
    --corpus-dir sample_corpus \
    --model mlx-community/whisper-tiny \
    --output-dir artifacts/speech-matrix/mlx-audio
```

The command template must contain `{audio}`. `{model}` is optional but recommended.
The adapter captures stdout/stderr, parses common JSON transcript fields when present,
computes WER when a reference transcript is available, and writes result JSON.

### WhisperKit Lane (native Swift/CoreML, benchmark-only)

WhisperKit lives in an **isolated** package (`tools/whisperkit_sidecar`), never in
the production `Package.swift`. Build it and benchmark against the shared corpus:

```bash
./scripts/benchmark_whisperkit.sh \
  --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \
  --model openai_whisper-tiny --model openai_whisper-small
```

Results use the same JSON shape as the SwiftWhisper and MLX lanes. See
[`WHISPERKIT_BENCHMARK.md`](WHISPERKIT_BENCHMARK.md) for architecture and packaging
notes, and [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md) for the cross-engine
comparison.

## Next benchmark candidates

Roadmap only — **not implemented**, not wired into production, not added to the
production root `Package.swift`.

### `soniqo/speech-swift` (ParakeetStreamingASR) — lane built, **benchmark BLOCKED**

> **Update:** the isolated lane now exists (`tools/speech_swift_sidecar/`,
> `scripts/benchmark_speech_swift.{py,sh}`), but the benchmark **did not run**: the
> isolated package **stalls in `swift build` planning** (after a full successful
> dependency resolution, before compiling anything). That build stall — plus the
> lack of runtime evidence and the dependency weight — is the **real blocker**.
> speech-swift requires **macOS 15+**, which for this 2-user private tool is an
> **acceptable, explicit production decision if the streaming capability earns it
> — not a rejection reason by itself**. Active work: unblock the build (narrower
> package / vendoring / tag bump), not reject over the OS version. Full findings +
> blocker analysis: [`SPEECH_SWIFT_BENCHMARK.md`](SPEECH_SWIFT_BENCHMARK.md).
> WhisperKit remains the lead candidate for *batch* dictation; speech-swift is
> specifically about *streaming/partials/EOU*.

- `soniqo/speech-swift` should be evaluated as a **future isolated benchmark lane**.
- It is relevant because it is a **Swift Package Manager-native, Apple Silicon
  speech stack** with local ASR, streaming ASR, VAD, diarization, and related
  speech modules — i.e. a native path like WhisperKit, but with streaming.
- It must **not** be integrated into production now, and must **not** be added to
  the production root `Package.swift`.
- A future test should live in an **isolated package**, likely
  `tools/speech_swift_sidecar/` (mirroring `tools/whisperkit_sidecar/`).
- **Test one module first, not the whole toolkit.**
  - **First candidate: `ParakeetStreamingASR`** — it tests streaming dictation,
    partial hypotheses, and end-of-utterance behavior (a different axis than the
    batch-after-recording engines benchmarked so far).
  - **Second candidate (later): `SpeechVAD`** — keep VAD separate from ASR
    accuracy testing so the two concerns don't confound each other.
- **macOS requirement (resolved decision):** speech-swift requires **macOS 15+**.
  For this 2-user private tool, raising DexDictate's floor to macOS 15 is an
  **acceptable explicit decision if the capability is proven** — it is a
  compatibility note, not a blocker by itself.

This note is documentation for the roadmap; the build-unblock investigation is
active (see [`SPEECH_SWIFT_BENCHMARK.md`](SPEECH_SWIFT_BENCHMARK.md)).

## Evidence Required Before Production Consideration

MLX-Audio is not production-ready for DexDictate until there is evidence for all of
the following:

- Same corpus, same machine, same build source as the SwiftWhisper baseline.
- p95 transcription latency and average WER are better than the current production
  candidate or explain a clear tradeoff.
- Command-only phrases are not preserved as ordinary dictation text at an unacceptable
  rate.
- Punctuation behavior is measured, not guessed.
- Failure behavior is boring: no hangs, no partial writes to user targets, no hidden
  network dependency, and no persistent service started by accident.
- Results are repeatable across at least one cold run and one repeat run.

Until then, the only reasonable integration shape is an optional benchmark sidecar.
The smallest safe next step after promising numbers would be an internal protocol and
adapter boundary in test code, not a live dictation path change.

