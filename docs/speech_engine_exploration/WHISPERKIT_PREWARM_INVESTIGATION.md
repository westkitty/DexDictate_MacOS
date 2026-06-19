# WhisperKit First-Inference / CoreML Compile Investigation

Status: **benchmark-only.** Nothing here is wired into production DexDictate.
Production remains on SwiftWhisper. This document records an empirical
investigation into the WhisperKit first-inference cost that blocks production
(notably `openai_whisper-small` taking ~193 s on first inference).

## Tooling

- `tools/whisperkit_sidecar` (isolated package) gained a `--diagnose` mode:
  loads the model once, runs N sequential inferences on a **synthetic silent**
  clip (each timed), optionally times one real **public** clip afterward, and
  reports only booleans for any recognized text — never the transcript.
- `scripts/benchmark_whisperkit_prewarm.py` drives it across fresh processes
  ("sessions"), can delete a model's download dir, and snapshots OS cache dirs.
- `scripts/benchmark_whisperkit_prewarm.sh` builds the isolated tool and forwards
  to the driver.

All output is under the git-ignored `artifacts/whisperkit-prewarm/`.

## Headline answers

| # | Question | Answer |
|---|---|---|
| 1 | Where is the cost? | The **first `transcribe()` call** (first inference). |
| 2 | What triggers it? | **CoreML Apple-Neural-Engine model specialization/compile.** It is driven by the **compute units**: ANE = huge, GPU = moderate, CPU = negligible. Not download, not model load. |
| 3 | One-time per model per machine? | Yes, cached (~176 MB) — **but evictable** (see Q4/Q6). |
| 4 | Survives process restart? | **Yes** — a fresh process after a successful compile pays only ~1–2 s, not the full minutes. But it does **not** survive macOS cache purge or model re-download. |
| 5 | Deleting `artifacts/whisperkit-models` reproduces it? | **Yes** — re-downloading the model files invalidates the compile cache → full recompile. |
| 6 | Deleting the compiled cache reproduces it? | **Yes** — deleting `~/Library/Caches/whisperkit-transcribe` → full recompile. |
| 7 | Does a silent prewarm clip work? | **Yes** — a silent clip absorbs the entire compile; the next real clip runs warm. |
| 8 | Can prewarm be measured separately? | **Yes** — that is exactly what `--diagnose` does. |
| 9 | Can we detect already-compiled/warm? | Partially — presence of the cache dir is a heuristic; a single timed silent inference is the reliable probe. |
| 10 | Safest production strategy? | **Background prewarm with a silent clip after model selection / on idle**, never on the user's first dictation. Optionally compile on CPU first for an instant path, then warm ANE in the background. |

## Measurements

Machine: Apple Silicon, macOS 26.5, this session. Times in ms. Default compute
units = WhisperKit default (ANE-heavy) unless noted. Models pre-downloaded.

### Cold vs warm vs restart (silent prewarm clip)

| Model | load | session0 inf0 (cold compile) | session0 inf1/inf2 (warm) | session1 inf0 (fresh process, post-compile) | real public clip after prewarm |
|---|---:|---:|---:|---:|---:|
| `openai_whisper-tiny` | ~2000 | **29 245** | 74 / 71 | **1 223** | 141 |
| `openai_whisper-base` | ~1900 | **59 179** | 114 / 105 | **1 207** | 232 |
| `openai_whisper-small` | ~2100 | **183 534** | 508 / 643 | **2 382** | 900 |

- **Model load is flat (~2 s) for all sizes** — the cost is *not* load.
- **First inference is the compile.** It scales with model size (tiny 29 s →
  small 184 s).
- **Restart persistence:** a second fresh process drops first-inference from
  minutes to ~1–2 s (small 183 534 → 2 382). The heavy compile persists across
  process restarts; only a small per-process warm-start remains.
- **Prewarm works:** in session0, the silent prewarm absorbed the full compile,
  and the subsequent real public clip ran warm (small 900 ms).
- Notably, session0 was cold again even though these models had been compiled
  hours earlier in the benchmark run — i.e. the OS cache **can be purged**
  (`com.apple.cache_delete` was observed active), so warmth is not permanent.

### Compute-units lever (tiny, compile cache cleared before each → true cold)

| Compute units | cold first-inference | warm inference |
|---|---:|---:|
| `cpu` | **1 746** | 126 |
| `gpu` | 7 198 | 147 |
| `ane` (default) | 27 089 | 69 |

**This is the key mechanism finding.** The Apple Neural Engine path is what costs
minutes to compile; CPU compiles almost instantly (and still transcribes at a
usable 126 ms warm), GPU is in between. ANE wins steady-state latency but loses
cold-start badly.

### Cache reproduction

| Action | Model downloaded? | First inference | Conclusion |
|---|---|---:|---|
| Delete `~/Library/Caches/whisperkit-transcribe` | yes (untouched) | **27 983** (recompile) | Compile cache is the artifact; deleting it recompiles (Q6). |
| Delete + re-download model files (cache dir intact) | re-downloaded | **27 761** (recompile) | Re-download invalidates the compile cache key (Q5). |

So the compiled artifact stays valid only while **both** the OS cache dir
(`~/Library/Caches/whisperkit-transcribe`) survives **and** the model files are
unchanged. Either a cache purge or a model re-download triggers a full recompile.

## Privacy

- Prewarm uses a **synthetic silent** WAV generated locally — never a private
  transcript.
- WhisperKit **hallucinates tokens on silence** (a known Whisper trait), so the
  silent prewarm produces non-empty output. This is harmless (no user audio
  involved), but it means "empty output" is *not* a reliable warmth detector.
- The diagnose tool stores only booleans (`prewarm_output_empty`,
  `real_after_prewarm_output_empty`), never the transcript text. No raw
  transcripts are written to app diagnostics. All artifacts are git-ignored.

## WhisperKit's built-in `prewarm` config (the controllable-prep question)

WhisperKit **does** expose a built-in prewarm: `WhisperKitConfig(prewarm: Bool?)`
and `WhisperKit.prewarmModels()`. Per WhisperKit's own docs, it loads each model
"sequentially and unloaded immediately to trigger specialization if necessary" —
i.e. it deliberately runs the CoreML/ANE specialization **at model-load time**,
and it needs **no audio** to do so.

Tooling: the isolated tool gained `--config-prewarm` / `--no-config-prewarm`
(sets `WhisperKitConfig(prewarm:)`), and the diagnose JSON now reports WhisperKit's
own `whisperkit_prewarm_load_ms` (its internal `prewarmLoadTime`).

Measured, compile cache cleared before each (true cold), default ANE compute:

| Model | prewarm | model load (ms) | WhisperKit prewarm (ms) | first inference (ms) | warm steady (ms) | real clip after |
|---|---|---:|---:|---:|---:|---:|
| tiny | **on** | 32 691 | 30 653 | **1 026** | 65 | 144 |
| tiny | off | 2 485 | 0 | **29 042** | 67 | 123 |
| base | **on** | 61 616 | 59 652 | **1 222** | 110 | 222 |
| base | off | 2 107 | 0 | **61 590** | 111 | 349 |
| small | **on** | 187 318 | 184 394 | **20 818** | 400 | 829 |
| small | off | ~2 000 | 0 | **~183 000** | ~450 | ~800 |

**Findings:**

1. **Yes — `prewarm: true` moves the compile into model load.** WhisperKit's own
   `prewarmLoadTime` captures essentially the entire specialization (tiny 30.7 s,
   base 59.7 s, small 184.4 s), and the first `transcribe()` collapses
   accordingly (tiny 29 s → 1.0 s; base 62 s → 1.2 s).
2. **It relocates, it does not eliminate.** Total one-time cost is conserved — the
   user waits the same number of seconds, but now at a controllable preparation
   point (`WhisperKit(config)` init) instead of mid-dictation.
3. **`small` keeps a residual.** Even with prewarm, small's first real inference
   still paid ~20.8 s on top of the 184 s load-time prewarm — so for large models
   prewarm is **not** a 100% shift; budget for a residual first-transcription cost.
4. **Works for tiny/base/small** (all measured).
5. **Compute units interact strongly** (tiny, prewarm on, true cold):
   CPU load 3.1 s (prewarm 1.1 s) / GPU 2.9 s (0.8 s) / ANE 30.6 s (28.7 s). So
   prewarm + CPU (or GPU) is a **near-instant prepared model**; prewarm + ANE pays
   the full specialization at load but yields the best warm latency (66 ms).
6. **Combines with the CPU-first / ANE-background strategy.** You can
   `prewarm: true` a CPU instance (ready in ~3 s) for immediate first dictation
   while a second `prewarm: true` ANE instance specializes in the background
   (tiny ~31 s, small ~184 s) for best steady-state — same config flag, different
   `computeOptions`.
7. **Privacy: better than the silent-clip approach.** `prewarm: true` triggers
   specialization via load-unload-load with **no audio input at all**, so there is
   zero transcript/audio surface. (The silent-clip prewarm remains a valid
   alternative; both keep output under git-ignored `artifacts/` and the tool
   stores only booleans.)
8. **No unexpected transcript writes.** Built-in prewarm produces no transcripts;
   diagnose output contains timings + booleans only.
9. **Packaging implication (new):** WhisperKit warns load time roughly **doubles
   when the cache IS warm** (load-unload-load) — usually <1 s extra — and on a cold
   cache it front-loads the full specialization. The app must run prewarm at a
   controlled prep point, and should detect warmth to avoid the redundant 2x load.

## Two-stage prep: config prewarm + one silent dummy decode

`prewarm: true` specializes the **audio encoder** at load, but leaves a
**text-decoder/prefill** residual that lands on whatever the *first decode* is.
The fix: after load, run **one synthetic silent dummy decode** as an explicit prep
step, then the user's first real dictation is warm.

Tooling: the diagnose mode gained `--dummy-decode`, which strictly orders the
sequence as **[load (+config prewarm)] → [one silent dummy decode] → [first real
public clip] → [warm inferences]**. Toggling `--dummy-decode` with everything else
held constant is the A/B test.

Measured, true cold (compile cache cleared), `prewarm: true`, default ANE compute.
The decisive column is the **first real clip**:

| Model | prep: load (wk_prewarm) | dummy silent decode | **first real clip — WITH dummy** | **first real clip — NO dummy** | warm steady |
|---|---:|---:|---:|---:|---:|
| tiny  | ~29–35 s (27–33 s) | 1.0 s | **0.12 s** | 1.33 s | 0.07 s |
| base  | ~58–60 s (56–58 s) | 1.1 s | **0.21 s** | 8.24 s | 0.12 s |
| small | ~190–230 s (190–228 s) | 2.3 s | **1.04 s** | **34.56 s** | 0.4–0.7 s |

**Findings:**

1. **Yes — the dummy decode removes the residual from the user's first real clip.**
   Without it, the first real clip pays the decoder residual (small **34.6 s**, base
   8.2 s, tiny 1.3 s). With it, the first real clip is warm (small **1.04 s**, base
   0.21 s, tiny 0.12 s). The effect is 10–40× and consistent across all three
   models, so it is not thermal noise.
2. **The silent dummy decode itself is cheap** (small 2.3 s) — silence decodes few
   tokens, yet it is enough to trigger the decoder specialization so the next real
   clip is warm.
3. **Total prep to a warm-for-real state** (load + prewarm + dummy): tiny ~30 s,
   base ~59 s, small ~194 s on ANE.
4. **Compute units change prep cost a lot** (small, prewarm + dummy):

   | Compute units | prep load (wk_prewarm) | dummy | first real | warm steady |
   |---|---:|---:|---:|---:|
   | CPU | ~42 s (24 s) | 5.0 s | 1.72 s | ~1.4 s |
   | GPU | ~23 s (21 s) | 7.8 s | 2.91 s | ~2.4 s |
   | ANE (default) | ~192 s (190 s) | 2.3 s | 1.04 s | ~0.4–0.7 s |

   CPU/GPU slash prep from ~190 s to ~25–45 s but pay much worse steady-state
   latency (CPU ~1.4 s, GPU ~2.4 s vs ANE ~0.4–0.7 s per clip).
5. **Privacy preserved.** The dummy decode uses synthetic silence; the tool stores
   only timings and booleans — confirmed no `"text"` field exists anywhere under
   `artifacts/whisperkit-prewarm/`. (Silence hallucinates tokens, so
   `dummy_output_empty=false`, but the text is never persisted.)
6. **Variance caveat.** Absolute load/prewarm times vary run-to-run (190–230 s for
   small) due to thermal/load state; treat them as approximate. The *relative*
   dummy-vs-no-dummy effect on the first real clip is robust.

**Answer to the residual question:** config prewarm + one silent dummy decode is
sufficient to make the first real dictation warm for tiny/base/small. The
production-shaped prep is: **(1) `WhisperKitConfig(prewarm: true)` at model prep,
(2) one synthetic silent decode, (3) mark the model ready.**

## Recommended production UX strategy (for a future, separate decision)

Production integration is still blocked, but the safe shape is now clear:

1. **Never compile on the user's first dictation.** A 3-minute stall (small,
   ANE) is unacceptable.
2. **Two-stage background prep, triggered by model selection** (and re-triggered
   after any model update/re-download or cache eviction), surfaced as a
   "Preparing model…" state — not a blocking modal:
   1. `WhisperKitConfig(prewarm: true)` — specializes the encoder at load (no
      audio needed).
   2. one **synthetic silent dummy decode** — absorbs the text-decoder residual.
   3. mark the model ready. After this, the user's first real dictation is warm
      (small ~1 s, base ~0.2 s, tiny ~0.1 s).
3. **Detect warmth before prepping** with a single timed silent decode (cheap when
   warm); skip prep if already fast, to avoid the redundant warm-cache 2x load.
4. **CPU-first / ANE-background is worth it** (now measured): prep `small` on CPU
   (~25–45 s) or GPU for an immediately usable model (~1.4 s/clip on CPU) while a
   second `prewarm: true` ANE instance specializes in the background (~190 s) for
   the best steady-state latency (~0.4–0.7 s/clip), then switch.
5. **Persist across launches but assume eviction:** the cache survives restarts
   but macOS may purge `~/Library/Caches`; the app must re-detect and re-prep
   gracefully rather than assume permanent warmth.

## What remains unknown

- Whether warmth survives a **full reboot** (only process-restart and cache-purge
  were tested this session).
- The exact **cache key** (content hash vs path+mtime) — re-download invalidates
  it, but we did not isolate which attribute.
- Whether warmth survives a **full reboot** (only process-restart and cache-purge
  were tested).
- The exact **cache key** (content hash vs path+mtime).
- `large-v3-turbo` compile cost (intentionally not tested; the `small` problem is
  representative and sufficient).
- End-to-end wiring of the CPU-first → ANE-background hand-off with two WhisperKit
  instances (the per-stage timings say it works; the live switch is not wired/tested).
- High run-to-run variance in load/prewarm times (thermal); a cooled-machine
  re-measure would tighten the absolute prep-time numbers.

(Resolved this turn: WhisperKit's `WhisperKitConfig(prewarm:)` shifts the encoder
compile to load time, and a single silent dummy decode after load absorbs the
text-decoder residual so the first real dictation is warm — see the sections above.)

## Production code untouched

No production Swift files, `Package.swift`, `build.sh`, signing, packaging, or
dictation behavior were modified. WhisperKit remains confined to the isolated
benchmark package.
