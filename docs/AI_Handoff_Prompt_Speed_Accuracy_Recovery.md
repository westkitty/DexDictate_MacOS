# DexDictate macOS - Exhaustive Handoff Prompt for Speed/Accuracy Recovery

Use this prompt as-is with another AI agent.

---

You are taking over a real macOS dictation project that has regressed and is now too slow/inaccurate for daily use. Your job is not to do a generic cleanup. Your job is to restore usability fast, then improve it beyond the previous behavior.

## 1) Project Identity and Current State

- Project: `DexDictate_MacOS`
- Repo path: `/Users/andrew/Projects/REF_DexDictate_MacOS`
- Branch: `main`
- HEAD: `c4bc260d923ecd6ba3648b32767a6b60c3e939c5` (local branch ahead of origin by 1 commit)
- Remote: `https://github.com/westkitty/DexDictate_MacOS`
- Platform: macOS 14+, Swift 5.9 SPM app
- Architecture: Menu bar app (`Sources/DexDictate`) + core library (`Sources/DexDictateKit`)

## 2) User-Critical Problem Statement

The user reports this was better before recent upgrades and is now "slow and inaccurate" to the point of workflow failure. Treat this as a production regression, not a feature request.

Primary mandate:
- Recover transcription speed and accuracy quickly.
- Restore trust/consistency.
- Avoid another speculative rewrite without measurement.

## 3) What Changed Historically (Key Timeline)

Use this timeline to reason about regression origins. Dates are from git commits.

### Foundation / Earlier implementation
- `8eeee41` (2026-02-16): refactor to `DexDictateKit` architecture.
- `4d7f18e` (2026-02-16): Whisper integration and advanced features.
- `dfb7ea6` (2026-02-17): removed Apple Speech path and forced Whisper-only local mode.

### Rapid transcription pipeline churn (likely regression window)
- `c310f0d` (2026-02-18): removed streaming per-chunk Whisper calls; moved to full-utterance accumulation + manual resample to 16k + single Whisper call on release.
- `5458c55` (2026-02-18): speed tuning (greedy best_of=1, speed_up=true, aggressive perf focus), tap changes.
- `1978b0f` (2026-02-18): fixed double tap, model reload behavior, state handling.
- `e57c5d1` (2026-02-18): fixed audio buffer data race and some UI issues.
- `ce0a38f` (2026-02-18): deadlock fix via mic permission guard and async audio setup.
- `3604893` (2026-02-18): major audio threading model rewrite to serial `audioQueue`, native format tap, stop delay changed to 250ms in source.
- `3bfcd8e` (2026-02-18): changed Whisper decoding profile toward balance/accuracy and added silence trimming.

### Current docs
- `c4bc260` (2026-02-19): added strict experiment matrix doc; no core engine code changes.

## 4) Evidence Collected in Current Workspace

### Build/Test status
- `scripts/run_quality_paths.sh` passes.
- `swift build` passes.
- `swift run VerificationRunner` passes (45 checks).

Important caveat:
- Current tests are mostly logic/string checks and source-code presence checks.
- They do **not** validate real-world dictation latency or WER.

### Runtime log evidence (from `/Users/andrew/Library/Application Support/DexDictate/debug.log`)
- Observed submit->Whisper output latencies are often multiple seconds.
- Parsed sample from log history:
  - `n=56`
  - mean `~3.77s`
  - p50 `3s`
  - p90 `4s`
  - p95 `8s`
  - max `19s`
- Empty outputs do occur in real logs (`Whisper output ... 0 chars`).

Critical observation:
- Recent log lines show old behavior signatures (`scheduleStop ... 750ms`, `speed_up=true`), while current source at HEAD uses 250ms delay and dynamic speed profile.
- This implies possible source/binary mismatch during prior runs. Validate you are benchmarking the current build, not stale app binaries.

## 5) What Currently Works

Based on code + passing tests:
- App builds and starts.
- Permissions flow exists and has guardrails.
- Input monitor/event tap generally works.
- Audio capture starts/stops and collects utterance buffers.
- Offline-only model path (`tiny.en.bin`) is wired.
- History, vocabulary replacement, profanity filter, command parsing, and auto-paste are functional in basic logic.
- Multiple crash/deadlock fixes were applied around event tap duplication and audio setup.

## 6) What Is Broken, Weak, or Misleading

### A) Performance and quality are not validated by automated tests
- No automated latency benchmark for real dictation path.
- No automated WER/corpus regression test.
- Verification suite can pass while user experience is unacceptable.

### B) Latency architecture tradeoff likely regressed responsiveness
- Current design transcribes only after trigger release (batch mode).
- That inherently delays visible results compared with true partial streaming UX.
- README still suggests "zero latency" and live partial behavior; this is not representative of current batch reality.

### C) Risky heuristic path affecting accuracy
- Manual silence trimming (`trimSilenceForTranscription`) can clip low-volume consonants/edges.
- Manual linear resampling may degrade quality vs converter-based path.
- Dynamic decode profile may still make poor tradeoffs by utterance length heuristic alone.

### D) Stuck/transcribing edge case risk
- In `WhisperService.transcribe`, if model is missing/not loaded, call returns early.
- In `TranscriptionEngine.stopListening`, state was already moved to `.transcribing`; if callback never fires, state recovery risk exists.
- Verify this behavior end-to-end and harden with fallback state reset.

### E) Settings/UI mismatch
- `silenceTimeout` is exposed in UI/settings but not effectively wired into stopping logic.
- `launchAtLogin` stored but not implemented.

### F) Historical process failure (important)
Major admitted process mistakes in prior upgrades:
- Multiple core pipeline changes landed in rapid sequence without locked baseline metrics.
- "Speed" claims and "accuracy" claims were not guarded by objective offline corpus runs before/after each change.
- Verification runner drifted toward source-pattern checks instead of user-visible quality checks.

## 7) Files to Audit First

- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/DexDictateKit/TranscriptionEngine.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/DexDictateKit/Services/AudioRecorderService.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/DexDictateKit/Services/WhisperService.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/DexDictateKit/InputMonitor.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/DexDictateKit/AppSettings.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/Sources/VerificationRunner/main.swift`
- `/Users/andrew/Projects/REF_DexDictate_MacOS/docs/DexDictate_Strict_Experiment_Matrix.md`

## 8) Non-Negotiable Recovery Plan

Execute in this order. Do not skip measurement steps.

### Phase 0 - Baseline Integrity
1. Confirm working tree commit SHA and build binary from current source.
2. Confirm debug logs reflect current source constants (especially stop delay + whisper params).
3. Reproduce current behavior with controlled utterance corpus.

### Phase 1 - Instrumentation Upgrade (must happen first)
1. Add explicit timestamped metrics logs for:
   - trigger up event
   - audio stop complete
   - post-trim sample count
   - post-resample sample count
   - whisper submit
   - whisper completion
   - finalize/paste complete
2. Emit one structured line per utterance with all timings and metadata.
3. Add a script to parse logs into CSV.

### Phase 2 - Fast rollback experiments (minimal invasive)
1. Add feature flags (runtime settings or compile flags) for:
   - silence trim on/off
   - trim aggressiveness
   - resample method (current linear vs AVAudioConverter path)
   - stop tail delay (e.g. 150ms/250ms/500ms/750ms)
   - whisper decode profile (accuracy vs balanced vs speed)
2. Run A/B against fixed corpus and keep raw transcripts.

### Phase 3 - Accuracy restoration
1. Compare `tiny.en` vs `base.en` (and `small.en` only if latency remains acceptable).
2. Lock decode params based on measured WER + latency, not assumptions.
3. Validate command phrases and punctuation across profiles.

### Phase 4 - Responsiveness UX
1. Re-introduce low-cost partial UX feedback if true streaming decode is not viable.
2. Ensure user gets immediate progress cues while batch decode runs.
3. Reduce perceived lag without lying about "zero latency".

### Phase 5 - Regression gate in CI/local script
1. Add a test harness that fails if p95 total latency or WER crosses thresholds.
2. Keep offline-only guarantee.
3. Update docs to match actual behavior.

## 9) Acceptance Criteria (Strict)

Minimum pass bar to call this fixed:
- p95 `T_total_ms` <= 2200ms on short/normal utterances (local machine baseline matched).
- Mean `T_submit_to_output_ms` materially improved from current measured baseline.
- WER on reference corpus improved by at least 20% vs baseline or reaches <=8% combined target corpus.
- Command error rate <=2%.
- No engine stuck states after 30-minute soak.
- No online/network transcription path introduced.

## 10) Practical "Do This Now" Checklist for You

1. Run current strict matrix from `docs/DexDictate_Strict_Experiment_Matrix.md` with real logging.
2. Produce baseline table (latency/WER/command/punctuation).
3. Implement instrumentation and flags in smallest safe patch.
4. Run first rollback sweep:
   - disable silence trim
   - 500ms stop delay
   - accuracy-biased decode profile
5. If accuracy still bad, test `base.en` locally.
6. Present before/after numbers and the exact winning config.

## 11) Delivery Format Required From You

Provide exactly:
1. Root cause summary ranked by impact.
2. Concrete code changes with file paths.
3. Baseline vs final metrics table.
4. Residual risks.
5. Next two highest-leverage improvements.

No vague statements. No "seems faster" claims without numbers.

---

If you need a starting hypothesis ranking:
1. batch-only post-release decode + model/param profile mismatch is major latency contributor.
2. silence trimming + resampling path may be damaging word boundary accuracy.
3. current validation stack is blind to user-visible regression, so bad configs pass.

Treat this as a production recovery incident.
