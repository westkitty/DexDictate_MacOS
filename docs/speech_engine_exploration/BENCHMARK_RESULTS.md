# Speech Engine Benchmark Results

Exploration-only. No production dictation behavior was changed to produce these
numbers. Recognized/reference transcripts live only in git-ignored
`artifacts/` result files.

- **Corpus:** `benchmark_samples/benchmark_corpus_mixed_v1_2` — 61 active scored
  clips (validated: 0 errors, 0 warnings via `tools/validate_corpus.py`).
- **Machine:** Apple Silicon (arm64), macOS 26.x, 8 CPU.
- **Date:** 2026-06-18.
- **WER metric:** lowercased, punctuation-stripped word error rate (Levenshtein
  over tokens), identical normalization across both engines.

> **Read latency carefully.** Absolute latency is sensitive to machine load and
> warm/cold state. WER is deterministic for a fixed model+corpus and is the
> trustworthy cross-engine axis. Where two latency figures exist for the same
> config they are both shown.

## Environment note (read before running MLX tooling)

- In this repo environment, the default `python3` is **Python 3.14**.
- The MLX benchmark tooling currently requires **`python3.13`** (MLX wheels are
  not published for 3.14 yet).
- The isolated MLX environment is **`.venv_mlx_audio`** (created by
  `scripts/setup_mlx_audio_env.sh`, which auto-selects `python3.13`).
- Run MLX benchmark wrapper commands with **`.venv_mlx_audio/bin/python`**, not
  the system `python3`.
- `.venv_mlx_audio/` is ignored by git through the `.venv*/` rule.
- Benchmark artifacts go under **`artifacts/`**, which is also git-ignored.

## SwiftWhisper (production engine, baseline)

Run via `scripts/benchmark.py` against the production-style `VerificationRunner`,
decode-profile `accuracy`, release build.

| Model | Files | Avg WER | Avg latency (ms) | p95 latency (ms) | Verified this session |
|---|---:|---:|---:|---:|---|
| `tiny.en` | 61 | **0.37749** | 615 (this session) / 1609 (Codex) | 947 / 2628 | ✅ WER re-run, matches Codex to 8 dp |
| `base` | 61 | **0.35781** | 3191 (Codex) | 5451 | ⏳ Codex-reported, not re-run |
| `small` | 61 | **0.32695** | 5543 (Codex) | 7739 | ⏳ Codex-reported, not re-run |

Notes:
- The `tiny.en` WER reproduced **exactly** (`0.37748548…`), which independently
  validates Codex's SwiftWhisper WER methodology and the 61-file corpus.
- `tiny.en` latency differed (615 ms vs Codex's 1609 ms) purely from machine
  state; treat absolute latency as machine-relative, WER as portable.
- `base`/`small` were left as Codex-reported to save ~9 minutes of re-run; their
  WER ordering (small < base < tiny.en) is the relevant fact and is consistent.

## MLX-Audio (candidate, benchmark-only)

Engine: `mlx-whisper` 0.4.3 (mlx 0.31.2) in an isolated `.venv_mlx_audio`
(CPython 3.13). Model: `mlx-community/whisper-tiny`. Fully local; the model
downloaded once into the Hugging Face cache and all scored runs were warm.

| Run | Model | Mode | Files | Avg WER | Avg latency (ms) | p95 latency (ms) | Empty rate | Failures |
|---|---|---|---:|---:|---:|---:|---:|---:|
| smoke-5 | whisper-tiny | wrapper (cold) | 5 | 0.17024 | 12163 | 49955 | 0% | 0 |
| smoke-5 | whisper-tiny | python-module (warm) | 5 | 0.17024 | 769 | 2502 | 0% | 0 |
| **full-61** | **whisper-tiny** | **python-module (warm)** | **61** | **0.35537** | **334** | **429** | **0%** | **0** |
| **full-61** | **whisper-large-v3-turbo** | **python-module (warm)** | **61** | **0.26693** | **11386** | **11290** | **0%** | **0** |

- The `smoke-5` wrapper latency is dominated by cold model download + per-file
  Python process spawn + per-call model load. It is **not** comparable to warm
  in-process latency and is shown only to document cold-start cost.
- The `full-61` warm module-mode runs are the comparable figures.

### About the `whisper-large-v3-turbo` run

- **Model:** `mlx-community/whisper-large-v3-turbo` (~1.6 GB).
- **Clips:** 61 (full corpus). **Processed 61, failed 0, empty-output rate 0%.**
- **Avg WER 0.26693**, punctuation-aware WER 0.312.
- **Avg latency 11386 ms, p95 11290 ms** (warm, in-process module mode).
- **Cold vs warm:** the scored numbers are **warm** — the model was already
  resident in the Hugging Face cache and loaded once for the whole 61-file run.
- **Model download during the run:** the 1.6 GB model **was downloaded once**, on
  the first (abandoned) cold attempt below; the scored module run reused the
  cache and did **not** re-download.
- **Wrapper/cold mode was abandoned as impractical.** A wrapper-mode (per-file
  process spawn + per-file 1.6 GB model reload) run reached only 7/61 files in
  ~14 minutes (~2 min/file) and was killed. This is itself a finding: a large
  model is unusable through per-request subprocess spawning; a warm, resident
  process (module mode, or a persistent helper) is mandatory for large models —
  reinforcing the sidecar graduation path in
  [`MLX_SIDECAR_CONTRACT.md`](MLX_SIDECAR_CONTRACT.md).

### turbo full-61 by category

| Category | n | Avg WER (turbo) | Avg WER (tiny) |
|---|---:|---:|---:|
| command_like | 5 | 0.014 | 0.090 |
| public_accent_read_speech | 10 | 0.017 | 0.164 |
| silence_clipping | 4 | 0.031 | 0.138 |
| normal_dictation | 8 | 0.036 | 0.155 |
| public_clean_read_speech | 15 | 0.071 | 0.128 |
| proper_nouns | 5 | 0.258 | 0.419 |
| fast_speech | 3 | 0.460 | 0.544 |
| technical | 5 | 0.957 | 1.000 |
| punctuation_heavy | 2 | 1.029 | 1.147 |
| quiet_speech | 2 | 1.150 | 1.150 |
| background_noise | 2 | 1.369 | 1.278 |

- Proper-noun token hit rate: **313/345 = 0.91** (up from tiny's 0.82).
- On real dictation categories turbo is excellent (command 0.014, normal 0.036,
  clean 0.071, accent 0.017). The 0.267 average is held up almost entirely by the
  adversarial tail (background-noise, quiet, technical, punctuation-heavy), where
  the Whisper family hallucinates on near-silence/noise regardless of size.

### MLX full-61 by category

| Category | n | Avg WER | Empty |
|---|---:|---:|---:|
| command_like | 5 | 0.090 | 0 |
| public_clean_read_speech | 15 | 0.128 | 0 |
| silence_clipping | 4 | 0.138 | 0 |
| normal_dictation | 8 | 0.155 | 0 |
| public_accent_read_speech | 10 | 0.164 | 0 |
| proper_nouns | 5 | 0.419 | 0 |
| fast_speech | 3 | 0.544 | 0 |
| technical | 5 | 1.000 | 0 |
| punctuation_heavy | 2 | 1.147 | 0 |
| quiet_speech | 2 | 1.150 | 0 |
| background_noise | 2 | 1.278 | 0 |

- Proper-noun token hit rate: **282/345 = 0.82**.
- Empty-output rate **0%** — no silent drops.
- The high-WER tail (technical, punctuation-heavy, quiet, background-noise) is the
  expected weakness of a *tiny* model on intentionally adversarial clips and is
  what inflates the 0.355 average; clean/normal/command speech is strong.

## WhisperKit (candidate, benchmark-only, native Swift/CoreML)

Engine: WhisperKit 1.0.0 via the **isolated** package `tools/whisperkit_sidecar`
(not the production target). Driven by `scripts/benchmark_whisperkit.sh` →
`scripts/benchmark_whisperkit.py`. The Swift tool loads the model once and
transcribes all 61 clips in one process, so per-file latency is **warm**, like
the MLX module-mode numbers. Models are CoreML variants from
`argmaxinc/whisperkit-coreml`, cached under the git-ignored
`artifacts/whisperkit-models`. See
[`WHISPERKIT_BENCHMARK.md`](WHISPERKIT_BENCHMARK.md) for the architecture.

| Model | Files | Avg WER | PA-WER | Median lat (ms) | p95 lat (ms) | Empty rate | Failures |
|---|---:|---:|---:|---:|---:|---:|---:|
| `openai_whisper-tiny` | 61 | **0.37477** | 0.440 | 135 | 269 | 3.3% | 0 |
| `openai_whisper-base` | 61 | **0.34430** | 0.400 | 219 | 455 | 3.3% | 0 |
| `openai_whisper-small` | 61 | **0.32530** | 0.393 | 782 | 1464 | 3.3% | 0 |

> **Latency caveat — report median/p95, not avg.** WhisperKit triggers a one-time
> CoreML on-device compile on the **first inference** (not captured by
> `model_load_ms`). That first clip is an extreme outlier — tiny ~5.0 s, base
> ~65.6 s, **small ~192.6 s** — which inflates the summary `avg_latency_ms`
> (tiny 228, base 1315, small 3957). After the first inference, steady state is
> the median/p95 above. CoreML caches the compiled model afterward, so the
> compile is a **one-time, per-model, per-machine cold-start cost** — but it is a
> real production UX concern (a 3-minute first-use stall for `small` is
> unacceptable without pre-warming).

- **Model download:** each variant downloaded once from `argmaxinc/whisperkit-coreml`
  into `artifacts/whisperkit-models` (git-ignored); later runs reused the cache.
- **Empty-output rate 3.3%** = 2/61 clips (adversarial silence/noise) — slightly
  worse than MLX's 0%, otherwise no silent drops.
- **`small` by category:** strong on real dictation (normal 0.054, accent 0.053,
  clean 0.100, silence-clipping 0.031); proper-noun hit rate 0.87; command-like
  surprisingly mixed (0.414 on 5 clips); adversarial tail high as usual
  (background-noise 1.369, quiet 1.195, technical 0.985).

### First-inference compile — investigated (the production blocker)

Full investigation: [`WHISPERKIT_PREWARM_INVESTIGATION.md`](WHISPERKIT_PREWARM_INVESTIGATION.md).
Tooling: `scripts/benchmark_whisperkit_prewarm.sh` + the `--diagnose` mode of the
isolated Swift tool. Key results:

- **The cost is the first `transcribe()`, not model load (flat ~2 s) or download.**
  It is **CoreML Apple-Neural-Engine specialization**. Cold first-inference:
  tiny ~29 s, base ~59 s, **small ~184 s**; warm steady-state thereafter.
- **Compute units are the driver.** Cold first-inference for tiny: **CPU 1.7 s**,
  GPU 7.2 s, **ANE 27 s** — but ANE has the best warm latency (69 ms vs CPU 126 ms).
- **Warm state persists across process restart** (small 184 s → 2.4 s on the next
  fresh process), cached in `~/Library/Caches/whisperkit-transcribe` (~176 MB) —
  **but** macOS can purge it, and re-downloading the model invalidates it, so both
  reproduce the full recompile.
- **A synthetic silent prewarm clip absorbs the entire compile**; the next real
  clip runs warm (small 900 ms). Prewarm is measurable and separable.
- **WhisperKit's built-in `WhisperKitConfig(prewarm: true)` shifts the encoder
  compile into model load** (no audio needed): tiny load 2.5 s → 32.7 s with
  first-inference 29 s → 1.0 s; base 62 s → 1.2 s. It **relocates, not eliminates**.
  A **text-decoder residual** remains and lands on the first *decode*: without prep
  the first real clip pays it (small **~35 s**, base ~8 s, tiny ~1.3 s).
- **Two-stage prep solves it:** `prewarm: true` at load **+ one synthetic silent
  dummy decode** absorbs the residual (the silent decode is cheap — small ~2.3 s),
  so the first real dictation is warm: **small ~1.0 s, base ~0.2 s, tiny ~0.1 s**.
  Full detail in
  [`WHISPERKIT_PREWARM_INVESTIGATION.md`](WHISPERKIT_PREWARM_INVESTIGATION.md).
- **Compute units (small, prewarm+dummy):** CPU prep ~25–45 s / GPU ~31 s vs ANE
  ~190 s, but warm latency CPU ~1.4 s / GPU ~2.4 s vs ANE ~0.4–0.7 s — confirming a
  CPU-first (fast prep) / ANE-background (best steady-state) split.
- **Production-shaped prep:** (1) `prewarm: true` at model prep, (2) one silent
  dummy decode, (3) mark ready — never on the user's first dictation; detect warmth
  to skip the redundant ~2x warm-cache load.
- Privacy: built-in prewarm uses **no audio**; the silent-clip alternative uses
  synthetic silence; the tool stores only booleans, never transcript text; all
  artifacts git-ignored. (WhisperKit hallucinates tokens on silence — harmless, no
  user data, but means "empty output" is not a warmth test.)

## Cross-engine summary (same 61-clip corpus, same machine)

WER is the trustworthy cross-engine axis (deterministic); latency is warm
steady-state (median/p95) except where noted.

| Engine | Model | WER | Warm latency note | Native packaging? |
|---|---|---:|---|---|
| SwiftWhisper | tiny.en | 0.377 | ~615 ms avg (this session) | ✅ (production today) |
| SwiftWhisper | base | 0.358 | ~3191 ms (Codex) | ✅ |
| SwiftWhisper | small | 0.327 | ~5543 ms (Codex) | ✅ |
| MLX | whisper-tiny | 0.355 | 334 ms avg / 429 p95 | ❌ Python venv |
| MLX | large-v3-turbo | **0.267** | ~11.4 s/file | ❌ Python venv |
| WhisperKit | whisper-tiny | 0.375 | 135 ms median / 269 p95 | ✅ Swift/CoreML |
| WhisperKit | whisper-base | 0.344 | 219 ms median / 455 p95 | ✅ Swift/CoreML |
| WhisperKit | whisper-small | 0.325 | 782 ms median / 1464 p95 | ✅ Swift/CoreML |
| speech-swift | ParakeetStreamingASR | — not benchmarked — | — | build stall (real blocker); macOS 15+ acceptable |

> **speech-swift (ParakeetStreamingASR) — not yet benchmarked.** A full isolated
> streaming-ASR lane was built (`tools/speech_swift_sidecar/`,
> `scripts/benchmark_speech_swift.{py,sh}`), but **no numbers were produced**: the
> isolated package **stalls in `swift build` planning** (after a clean dependency
> resolution, before any compilation), so the streaming model never executed —
> that build stall is the **real blocker**. speech-swift requires **macOS 15+**,
> which for this 2-user private tool is an **acceptable explicit decision if the
> capability is proven**, not a blocker by itself. No estimated figures are given.
> Streaming/partials/EOU is a different axis than the batch lanes above. See
> [`SPEECH_SWIFT_BENCHMARK.md`](SPEECH_SWIFT_BENCHMARK.md).

## Interpretation

Same corpus, same machine, WER directly comparable:

- **`tiny.en` is the fastest SwiftWhisper lane** but the least accurate
  (WER 0.377).
- **`small` is the most accurate so far** (WER 0.327) but ~9× the latency of MLX
  and the slowest lane overall.
- **`base` is the middle** (WER 0.358) and is **not** automatically worth its
  ~3 s latency given the alternatives.
- **MLX `whisper-tiny` matches `base`'s accuracy (0.355 ≈ 0.358), beats `tiny.en`
  on WER (0.355 < 0.377), and is the fastest engine measured** (334 ms avg /
  429 ms p95 warm — roughly half `tiny.en`'s same-session latency and a small
  fraction of `base`/`small`).
- MLX also handled command-like phrases best of any category (WER 0.090) and
  produced zero empty outputs.

Adding the larger model closes the accuracy question:

- **MLX `whisper-large-v3-turbo` beats `small` on WER** (0.267 < 0.327), with a
  91% proper-noun hit rate and **near-perfect real-dictation accuracy** (command
  0.014, normal 0.036, accent 0.017, clean 0.071). But it is **slow** here
  (~11.4 s/file), ~2× `small`'s latency — the accuracy/latency tradeoff inverts
  relative to tiny.

The bar for MLX was: *match/beat `small` WER, OR beat `tiny.en` latency with
acceptable WER, OR uniquely improve hard clips.* MLX now clears **two** gates:

- `whisper-tiny` clears the **latency** gate decisively (faster **and** more
  accurate than `tiny.en`; ties `base` WER).
- `whisper-large-v3-turbo` clears the **accuracy** gate (beats `small` WER) and
  uniquely improves proper-noun clips (0.258 vs `tiny.en` lane behavior; 91% hit
  rate), at a real latency cost.

Neither MLX model fixes the adversarial tail (background-noise/quiet/technical) —
that is a Whisper-family hallucination trait, not a size problem, and is the same
weakness SwiftWhisper would show.

**WhisperKit changes the packaging calculus — this is the key new result.**
WhisperKit is native Swift/CoreML with **no Python**, so unlike MLX it is a
genuinely shippable path. And it is accurate:

- **WhisperKit `small` matches SwiftWhisper `small`** (WER 0.325 ≈ 0.327) while
  being faster in steady state (782 ms median / 1464 ms p95 vs SwiftWhisper
  `small`'s multi-second lane), and **WhisperKit `base` beats SwiftWhisper `base`**
  (0.344 < 0.358).
- **WhisperKit `tiny` ties SwiftWhisper `tiny.en`** (0.375 ≈ 0.377) at the lowest
  steady-state latency of any engine (135 ms median / 269 ms p95).
- The one serious WhisperKit caveat is the **first-inference CoreML compile**
  (tiny ~5 s, base ~66 s, small ~193 s, one-time per model/machine). Production
  use would require pre-warming/pre-compiling at install or idle, never on the
  user's first dictation.

So accuracy parity with `small` is reachable two ways now — MLX `turbo` (best WER
0.267 but Python + slow) and WhisperKit `small` (matches `small`, native, fast
steady-state). For DexDictate's product shape, **WhisperKit is the path that can
actually ship.**

## Go / No-Go decision gates

| Gate | Required | MLX tiny | MLX turbo | WhisperKit small |
|---|---|---|---|---|
| Match/beat `small` WER | one of three | ❌ 0.355 | ✅ **0.267** | ✅ **0.325 ≈ 0.327** |
| Beat `tiny.en` latency w/ acceptable WER | one of three | ✅ | ❌ ~11 s/file | ✅ (WhisperKit tiny: 269 ms p95) |
| Uniquely improve noisy/quiet/proper-noun clips | one of three | ❌ | ⚠️ proper-nouns yes | ❌ adversarial tail unchanged |
| Runs fully local | required | ✅ | ✅ | ✅ |
| No raw transcripts outside benchmark artifacts | required | ✅ | ✅ | ✅ (tool writes JSON to file, not stdout) |
| Clear failure behavior | required | ✅ 0 fail | ✅ 0 fail | ✅ 0 fail (3.3% empty on adversarial clips) |
| No persistent server required | required | ✅ | ⚠️ needs warm process | ✅ in-process, no server |
| Plausible packaging path | required | ⚠️ Python venv | ⚠️ Python venv | ✅ **native Swift/CoreML** (see compile caveat) |

The "promising" gates are met multiple ways (latency via MLX/WhisperKit tiny,
accuracy via MLX turbo and WhisperKit small). The decisive difference is the last
required gate: **only WhisperKit has a plausible native packaging path.**

**Packaging — MLX vs WhisperKit:**
- **MLX** runs under a Python venv (`.venv_mlx_audio`, pulling torch/numba/scipy).
  Excellent for benchmarking; bundling a Python runtime into a notarized menu-bar
  app is a poor product fit. MLX stays a benchmark-only harness.
- **WhisperKit** is native Swift/CoreML — directly bundlable, no Python, macOS 14+
  (already DexDictate's floor). Its one caveat is the **first-inference CoreML
  compile** (up to ~3 min for `small`), which a production integration must hide
  via pre-warming/pre-compilation, never on the user's first dictation.

## Decision

**WhisperKit is the lead candidate for an eventual second engine; MLX stays a
benchmark-only harness. Production stays on SwiftWhisper.** Concretely:

1. Keep SwiftWhisper as the production engine (unchanged, default model unchanged).
2. **Accuracy and latency gates are met, and WhisperKit clears the packaging gate
   that MLX cannot.** WhisperKit `small` matches SwiftWhisper `small` accuracy
   (0.325 ≈ 0.327) natively; WhisperKit `tiny`/`base` are the fastest steady-state
   lanes measured. MLX `large-v3-turbo` has the best WER (0.267) but is Python-only.
3. **Critical-path next step:** characterize and solve the WhisperKit
   **first-inference CoreML compile** cost (tiny ~5 s → small ~193 s). Decide a
   pre-warm/pre-compile-at-install strategy; production is a non-starter without it.
4. Keep MLX as a benchmark reference (best-WER ceiling via turbo) but do not pursue
   it for packaging.
5. Only after the compile/pre-warm story is solved, build the **test-only**
   `DexDictateSpeechEngine` adapter (see
   [`SPEECH_ENGINE_ABSTRACTION_DRAFT.md`](SPEECH_ENGINE_ABSTRACTION_DRAFT.md)) with
   a `WhisperKitEngine` conformer behind a benchmark/feature flag — never the
   default, never touching the output pipeline.

Production dictation remains on SwiftWhisper until the WhisperKit cold-start story
is solved and a test-only adapter is characterization-tested.
