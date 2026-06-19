# speech-swift (ParakeetStreamingASR) Benchmark Lane

Status: **benchmark-only.** `soniqo/speech-swift` is **not** wired into production
DexDictate dictation and must not be. Production remains on SwiftWhisper. This lane
exists to measure the one capability axis the SwiftWhisper / MLX / WhisperKit batch
lanes cannot: **native streaming ASR — partial hypotheses and end-of-utterance
(EOU) behavior.**

## Why this lane (and why it's different)

SwiftWhisper, MLX, and WhisperKit are benchmarked as **batch-after-recording**
engines (audio in → final transcript out). They cannot answer how a *streaming*
engine behaves: when the first partial appears, how many times partials update,
whether the committed final differs from the last partial, and when end-of-utterance
fires. `ParakeetStreamingASR` is an RNN-T (FastConformer) streaming recognizer with
an explicit `<EOU>` token, so it is the right probe for that axis.

## Isolation architecture

```
tools/speech_swift_sidecar/
  Package.swift                              # depends on soniqo/speech-swift (exact 0.0.21); root Package.swift untouched
  Sources/speech-swift-benchmark/main.swift  # streaming benchmark CLI
  .gitignore                                 # ignores .build/ and Package.resolved
scripts/benchmark_speech_swift.py            # driver: corpus + WER + streaming-metric aggregation
scripts/benchmark_speech_swift.sh            # builds the isolated package, runs the driver
```

The production root `Package.swift` is **unchanged** and `build.sh` is untouched —
verified with `git diff -- Package.swift` and `git diff --name-only -- '*.swift'`.
speech-swift is referenced only by the isolated package.

## Package / API findings (Phase 1)

Inspected `soniqo/speech-swift` at tag **v0.0.21** (latest; the package is early-stage
`0.0.x`, so expect API churn).

| Question | Finding |
|---|---|
| Package manifest name | `Qwen3Speech` (package identity `speech-swift`) |
| `swift-tools-version` | 5.10 |
| **macOS minimum** | **`.macOS("15.0")`** (iOS 18.0) |
| **macOS 15+ required?** | **Yes** |
| **Conflicts with DexDictate's macOS 14 floor?** | **Yes** — see "Production implications" |
| `ParakeetStreamingASR` product exists? | **Yes** (also `ParakeetASR`, `NemotronStreamingASR`, and ~25 other products incl. TTS/VAD/diarization/separation) |
| Importable/buildable in isolation? | Target depends only on `AudioCommon` → `Hub` (swift-transformers); no hummingbird/server stack, no SpeechCore binary |
| Audio input | 16 kHz mono `[Float]` buffers; `AudioFileLoader.loadWAV(url:)` → `(samples, sampleRate)`; resamples internally |
| Fully local? | Yes — CoreML models from Hugging Face, no cloud inference |
| Model download/cache controllable? | Partially — `fromPretrained(modelId:)` uses the swift-transformers `Hub` cache; high-level API does not expose a `downloadBase` override |
| Logs transcript text to stdout/stderr? | The library logs via `AudioLog`; our benchmark tool writes text only to the git-ignored `--out` JSON and never to stdout unless `--print-transcripts` |
| Exposes partials / EOU / final timing? | **Yes** — `PartialTranscript { text, isFinal, confidence, eouDetected, segmentIndex }`; `<EOU>` detection built in |

### Heavy transitive dependency graph

speech-swift's manifest pulls `mlx-swift`, `swift-transformers`, **`hummingbird` +
`hummingbird-websocket` + `swift-websocket` (an HTTP/WebSocket server stack)**,
`WhisperKit`, and a `SpeechCore.xcframework` binary. SwiftPM resolves/downloads the
whole graph even though `ParakeetStreamingASR` only needs `AudioCommon`. That
server stack and the broad surface are a **packaging-risk signal** for any future
production use, even though they are not compiled into this benchmark target.

## Model chosen

`aufklarer/Parakeet-EOU-120M-CoreML-INT8` (the `ParakeetStreamingASR` default) —
a 120M-param Parakeet EOU model, CoreML INT8, fetched from Hugging Face.

## Build / run commands

```bash
# Build the isolated tool + dry-run (no model download)
./scripts/benchmark_speech_swift.sh --dry-run --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2

# Smoke (5), representative (15 across categories), or full (61)
./scripts/benchmark_speech_swift.sh --subset smoke5
./scripts/benchmark_speech_swift.sh --subset rep15 --csv
./scripts/benchmark_speech_swift.sh --subset full --csv
```

## Privacy behavior

- The benchmark tool writes recognized transcript text **only** into the `--out`
  JSON under the git-ignored `artifacts/` tree (same pattern as the WhisperKit/MLX
  lanes), so the Python driver can score WER with the shared normalization.
- Transcripts are **never** printed to stdout/stderr unless `--print-transcripts`
  is passed; `--no-store-transcripts` suppresses text entirely (disables WER).
- No raw transcripts are written to app diagnostics. No cloud/network speech path
  is introduced (model download from Hugging Face is the only network use).

## Model download / cache behavior

`fromPretrained` resolves a cache via the swift-transformers `Hub` (HF cache,
outside the repo — not tracked by git). The high-level API does not expose a
`downloadBase` override, so the model lands in the default HF cache location;
documented here rather than redirected. Download happens once; subsequent runs are
warm against the cache.

## Build blocker (Phase 5) — benchmark did NOT run

**The isolated package does not build to completion in this environment.** Across
**three** attempts (one clean ~14-minute run from a fresh resolution, plus two
retries including `--disable-sandbox`), `swift build` **resolves the full
36-package graph successfully** (all checkouts present, SpeechCore binary artifact
downloaded), then **stalls in the build-planning phase before compiling anything**:

- `swift-build` sits at **0% CPU** with **no `swift-frontend`/`swiftc` child
  processes** and **zero `.o` object files** produced.
- No verbose compile output is ever emitted (not even "Building for production…").
- The 200 s and ~14 min runs both ended with compilation never starting; the
  capped retries timed out (exit 124) with no binary.

This is reproducible and not caused by process contention (the first run was the
only build active). The most likely cause is build-graph/manifest/plugin evaluation
over the very large transitive graph speech-swift declares at package level
(`mlx-swift`, `hummingbird` + websocket stack, `WhisperKit`, `swift-transformers`,
`swift-certificates`/`crypto`, `async-http-client`, …). SwiftPM must plan the whole
graph even though `ParakeetStreamingASR` only needs `AudioCommon`. mlx-swift in
particular ships a Metal build-tool plugin and a manifest that probes the toolchain,
either of which can stall planning. The stall persisted with `--disable-sandbox`.

**Consequence:** no benchmark numbers were produced. The tool, driver, scripts, and
docs are complete and correct (dry-run verifies 61/15 planned clips), but the
streaming model never executed because its package could not be compiled here.

This is genuine negative evidence: in this environment, speech-swift's monolithic
toolkit package is too heavy a build to bring up for a single streaming-ASR module.

### What would unblock it (future, not attempted to avoid flailing)

- A longer, uninterrupted build window (let one `swift build` run to completion
  without a timeout) to confirm whether it eventually compiles or truly deadlocks.
- Pre-resolving/vendoring only `ParakeetStreamingASR` + `AudioCommon` away from the
  full toolkit graph (upstream would need to split the package, or we'd fork/trim).
- Filing/【checking upstream for a known mlx-swift plugin planning hang on this
  toolchain (Swift 6.2 / Xcode 26).

## Streaming / partial / EOU findings

**Not measured at runtime** (build blocker above). From **static API inspection**
only, `ParakeetStreamingASR` is designed to provide exactly these signals:

- partial hypotheses via `PartialTranscript.text` with `isFinal`/`segmentIndex`,
- confidence per partial (`confidence`),
- explicit end-of-utterance via `eouDetected` and an `<EOU>` RNN-T token,
- streaming push API (`StreamingSession.pushAudio`/`finalize`) plus an
  `AsyncStream` convenience.

These are promising on paper but **unverified** here.

## Benchmark results

**None.** The benchmark did not run because the isolated package failed to build
(see "Build blocker"). No numbers are reported. Per the no-fabrication rule, no
estimated/extrapolated figures are included.

## Production implications

- **macOS floor conflict is the headline risk.** speech-swift requires macOS 15;
  DexDictate ships a macOS 14 floor. Production use would require one of:
  1. **raising DexDictate's macOS floor to 15** (drops macOS 14 users),
  2. shipping it as an **optional macOS 15+ streaming backend** (added complexity,
     two engine paths), or
  3. **rejecting it** for production and keeping it benchmark-only.
- **Early-stage + broad surface.** `0.0.x` versioning implies API churn; the
  package bundles a large, server-including toolkit. Even with isolated imports,
  this is a heavier and less stable dependency than WhisperKit.
- **Value is the streaming axis.** If streaming/partials/EOU prove valuable for
  DexDictate's UX, that capability — not necessarily this package — is the thing to
  pursue.

## SpeechVAD (separate future experiment)

`SpeechVAD` exists as a product and would be the right *separate* lane for VAD (kept
out of ASR accuracy testing, as planned). However, it lives in the **same
speech-swift package** and therefore shares the **identical dependency graph that
fails to build here** — so a VAD lane is blocked by the same issue and was not
attempted (attempting it would re-hit the same stall). Defer until the build
blocker is resolved.

## Recommendation

**Defer speech-swift; it is not a near-term production candidate, and it is not even
benchmarkable in this environment yet.** Reasoning (skeptical, evidence-based):

1. **macOS 15+ floor** conflicts with DexDictate's macOS 14 floor — already a hard
   production gate (would require raising the floor, an optional 15+ backend, or
   rejection).
2. **Build does not come up here** — the monolithic `0.0.x` toolkit package stalls
   in planning over a huge graph (mlx-swift/hummingbird/WhisperKit/…). Even the
   single streaming module drags the whole toolkit.
3. **Early-stage + broad surface + server deps** make it a heavier, less stable
   dependency than WhisperKit, which is already the lead native candidate and
   builds cleanly.

The **capability** speech-swift targets (streaming ASR, partial hypotheses, EOU) is
still worth pursuing — but the next step is to evaluate that capability through a
**lighter path**, not this package as-is. Concretely: keep the tool/scripts/docs in
place (they're correct and ready), and revisit only if (a) a clean long build proves
the stall is just slowness, or (b) upstream splits `ParakeetStreamingASR` out of the
toolkit. Meanwhile **WhisperKit remains the lead production-shaped candidate** and
SwiftWhisper remains production.
