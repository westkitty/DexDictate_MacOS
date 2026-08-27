# DexDictate Audio Hardening — Phase 2A Live-Path Observability

## Executor

Codex running on the intended local macOS checkout of `westkitty/DexDictate_MacOS`.

## Objective

Make the **existing AVAudioEngine live-transcription path observable and deterministically testable** without changing capture architecture, committed-output authority, UI design, dependencies, installed app, TCC, or audio routes.

This phase exists so the next installed-app microphone run can identify the exact failing edge instead of guessing.

**Do not implement AUHAL in this phase. Do not replace AVAudioEngine. Do not make Nemotron or Apple Speech authoritative for final text.**

## Governing evidence

Read first:

- `OPERATIONAL_STATE.md`
- `docs/DEXDICTATE_BIBLE.md`
- `docs/audio_hardening/phase_0_baseline_report.md`
- `docs/audio_hardening/phase_1_verifier_repair_report.md`

The Phase 1 evidence commit is:

```text
fe96bfa7fd4482112c0b98ffd9bca2186287aacf
```

The packet itself may be on a later docs-only branch commit. The current branch must contain `fe96bfa7fd4482112c0b98ffd9bca2186287aacf` as an ancestor.

`origin/main` must still be:

```text
7cb739208ea11af6e20beccd9907affbe4500444
```

If either condition is false, stop before editing.

---

## Special worktree-preservation rule

A previous Codex run reported one **pre-existing local tracked modification**:

```text
.resurrection/fragile_files.txt
```

That file is unrelated to this campaign and must be preserved exactly. A dirty tree is therefore **not automatically a blocker** in Phase 2A.

### Allowed entry state

Proceed only when either:

1. the working tree is clean; or
2. the only pre-existing tracked modification is an **unstaged** modification to `.resurrection/fragile_files.txt`, with nothing else staged or modified/untracked.

If any other pre-existing path is dirty, stop.

If `.resurrection/fragile_files.txt` is staged, stop. Do not unstage it yourself.

### Snapshot the protected local change

If that file is dirty, record before doing any work:

```bash
git status --porcelain=v1
shasum -a 256 .resurrection/fragile_files.txt
git diff -- .resurrection/fragile_files.txt | shasum -a 256
```

Record both SHA-256 values in the Phase 2A report as **protected local file hash** and **protected local diff hash**.

Never run against this file:

```text
git add
git checkout
git restore
git reset
git stash
rm
cp-overwrite
sed -i
```

Do not stage it, commit it, rewrite it, normalize it, or include it in an automated cleanup.

Before any Phase 2A commit and again at the end, recompute both hashes. They must be byte-for-byte identical to the entry values. If either changes, stop without attempting repair.

All staging in this phase must use **explicit authorized paths**. Never use `git add .`, `git add -A`, or `git commit -a`.

---

## Step 1 — Environment and branch gate

Run:

```bash
pwd
git rev-parse --show-toplevel
git remote get-url origin
git branch --show-current
git status --porcelain=v1
git diff --cached --name-only
git rev-parse HEAD
git fetch origin main work/dexdictate-audio-hardening
git rev-parse origin/main
git rev-parse origin/work/dexdictate-audio-hardening
git merge-base --is-ancestor fe96bfa7fd4482112c0b98ffd9bca2186287aacf HEAD
git merge-base --is-ancestor fe96bfa7fd4482112c0b98ffd9bca2186287aacf origin/work/dexdictate-audio-hardening
```

Hard gates:

- intended repository only;
- branch `work/dexdictate-audio-hardening`;
- no staged pre-existing changes;
- worktree state satisfies the special preservation rule above;
- `origin/main == 7cb739208ea11af6e20beccd9907affbe4500444`;
- local branch and remote hardening branch both contain the Phase 1 evidence commit.

If the local branch is simply behind its remote and has no local campaign commits, fast-forward only. Do not merge or rebase divergent work.

---

## Step 2 — Inspect only the live path first

Inspect these before editing:

```text
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Transcription/NemotronTranscriptionProvider.swift
Sources/DexDictateKit/Transcription/AppleSpeechTranscriptionProvider.swift
Sources/DexDictateKit/LivePreview/LivePreviewController.swift
Tests/DexDictateTests/LivePreviewInvariantTests.swift
Tests/DexDictateTests/NemotronRealAudioPartialPipelineTests.swift
```

Also locate the existing live-caption window lifecycle tests and any existing provider/session diagnostics tests before creating new equivalents.

Search more broadly only if a named integration edge actually crosses another file.

Confirm by inspection that the current path is still conceptually:

```text
AVAudioEngine tap
  -> AudioRecorderService
     -> final audio accumulation
     -> active streaming provider (Nemotron or Apple Speech)
        -> partial callback
           -> TranscriptionEngine.liveTranscript
              -> LivePreviewController / visible caption surface

trigger release
  -> streaming provider stopped
  -> existing final transcription path
  -> committed output
```

If the current source differs materially, report the actual path and stop before inventing a second architecture.

---

## Step 3 — Add session-scoped live-transcription observability

Implement the smallest cohesive diagnostics layer that can identify the last proven boundary of a live session.

### Required trace identity

Every listening session must have one diagnostics/session identifier. Reuse an existing session UUID if safely available rather than creating competing session identities.

Structured diagnostics must use one searchable prefix:

```text
LIVE_TRACE
```

Do **not** log dictated words, audio samples, clipboard content, target-field content, prompts, API keys, model files, or other user content.

### Required boundary evidence

The diagnostics must be able to distinguish, at minimum:

1. session created / listening began;
2. live-provider resolution completed;
3. resolved provider ID and whether live streaming is actually active;
4. provider session start succeeded or failed;
5. first microphone/capture buffer was observed by DexDictate;
6. live-audio forwarding/provider intake was armed and, where safely observable, first buffer reached provider processing;
7. first partial callback arrived;
8. first partial was accepted by the current engine session and published to `liveTranscript`;
9. first caption update was observed by `LivePreviewController` when preview is enabled;
10. provider error, if any;
11. streaming stop requested;
12. final transcription path began;
13. session invalidated/ended;
14. stale callback was rejected, when such a callback actually occurs.

If one boundary cannot be instrumented without violating the real-time rule below, do **not** add unsafe instrumentation. Record that boundary as deliberately unavailable and use the nearest safe boundaries around it.

### Useful counters/snapshot

Where they can be collected on existing non-real-time work paths, expose a compact per-session snapshot containing useful values such as:

```text
captured buffer count
captured frame count
provider-processing/append count
partial callback count
provider error count
stale callback count
first-partial latency
```

Do not create a second product-facing settings system or UI for diagnostics. Debug/log/test visibility is sufficient for Phase 2A.

### Real-time callback rule — hard requirement

Do not make the AVAudioEngine real-time callback materially heavier.

Specifically, do not add per-buffer:

- `Safety.log` calls;
- filesystem operations;
- UI/MainActor waits;
- network operations;
- blocking async waits;
- new model/inference work;
- unbounded collections;
- a new `Task` solely for diagnostics;
- a new dispatch solely for diagnostics when the same counter/event can be recorded on an already-existing non-real-time path.

Prefer updating diagnostics inside work that already runs on `bufferQueue`, the existing Nemotron FIFO task, provider callbacks, or the main actor.

A **single one-shot session transition signal** from the audio callback is acceptable only if there is no safer existing non-real-time point and it is demonstrably bounded. Do not add a per-buffer logging stream.

No new package dependency is allowed for diagnostics.

---

## Step 4 — Preserve live/final authority boundaries

The implementation must not change these behaviors:

```text
Nemotron / Apple Speech
        -> provisional live display only

existing final engine
        -> authoritative committed transcript
        -> commands / vocabulary / cleanup / history / paste / undo
```

Live partials must not gain any path to:

- output insertion;
- clipboard mutation;
- history commits;
- command execution;
- Smart Cleanup submission;
- Undo state;
- final transcript authority.

Provider failure must remain non-fatal to the final dictation path.

Do not alter provider priority or model download behavior.

---

## Step 5 — Scope limits

Prefer changes only in the following existing files when required:

```text
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Transcription/NemotronTranscriptionProvider.swift
Sources/DexDictateKit/Transcription/AppleSpeechTranscriptionProvider.swift
Sources/DexDictateKit/LivePreview/LivePreviewController.swift
Tests/DexDictateTests/*live/provider/diagnostics-related tests*
OPERATIONAL_STATE.md
docs/audio_hardening/phase_2a_live_path_observability_report.md
```

One new focused diagnostics source file under `Sources/DexDictateKit/` and one new focused test file are allowed if they are cleaner than scattering state across existing classes.

Do not change in this phase:

- `Package.swift` or `Package.resolved`;
- final transcription engine selection/authority;
- OutputCoordinator or insertion behavior;
- vocabulary, commands, history, Undo, or Smart Cleanup behavior;
- microphone-selection policy;
- AVAudioEngine recovery architecture;
- tap installation architecture;
- AUHAL/Core Audio capture backend implementation;
- user-facing caption layout/style;
- settings defaults or storage keys;
- entitlements, TCC metadata, signing, packaging, or release version.

If a deterministic test exposes an existing defect that cannot be fixed inside the allowed live-session files without crossing these boundaries, stop and report rather than broadening scope.

---

## Step 6 — Deterministic tests

Add or extend tests so the observability itself cannot lie.

At minimum prove:

1. a new session starts with fresh diagnostics and cannot inherit counters/state from the prior session;
2. provider resolution/start success and failure are represented distinctly;
3. first-partial timing/count is recorded only after a real partial event;
4. a stale callback from an invalidated session is ignored by product state and represented as stale diagnostics if safely observable;
5. live partial publication never becomes committed output authority;
6. provider error diagnostics do not transition the final dictation path into failure by themselves;
7. diagnostics contain no transcript/audio-content field;
8. diagnostics reset/end cleanly when listening ends or the system stops.

Do not write a test that merely asserts hard-coded log strings exist in source. Exercise the diagnostics/session behavior.

Keep the existing real Nemotron regression intact. Do not weaken or replace `NemotronRealAudioPartialPipelineTests`.

---

## Step 7 — Validation ladder

Use an isolated Foundation home for normal automated validation so real DexDictate preferences are not rewritten:

```bash
PHASE2A_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dexdictate-phase2a.XXXXXX")"
printf 'PHASE2A_HOME=%s\n' "$PHASE2A_HOME"
```

Run focused tests first. Include the exact new/changed diagnostics tests plus:

```bash
env CFFIXED_USER_HOME="$PHASE2A_HOME" swift test --filter LivePreviewInvariantTests
env CFFIXED_USER_HOME="$PHASE2A_HOME" swift test --filter AudioRecorderTapStateTests
env CFFIXED_USER_HOME="$PHASE2A_HOME" swift test --filter EngineLifecycleStateMachineTests
```

Run any existing Apple Speech/provider-session tests that directly cover changed code.

### Real Nemotron regression

Inspect `NemotronRealAudioPartialPipelineTests.swift` before running it against the real home.

If and only if inspection confirms that this test path does **not** download models, change TCC, or mutate `AppSettings`/user preferences, run:

```bash
swift test --filter NemotronRealAudioPartialPipelineTests
```

Record PASS or SKIP exactly. Do not download Nemotron merely to make this test run.

Then run:

```bash
env CFFIXED_USER_HOME="$PHASE2A_HOME" swift run VerificationRunner
env CFFIXED_USER_HOME="$PHASE2A_HOME" swift test
git diff --check
```

Expected baseline before Phase 2A source changes was 707 executed / 0 failures / 11 skips. The total test count may legitimately increase because this phase adds tests; it must not decrease without a documented reason.

One bounded repair pass is allowed only for failures caused by the Phase 2A changes. Do not repair unrelated pre-existing failures inside this packet.

---

## Step 8 — Diff and protected-local-file audit

Before documentation/state edits, inspect:

```bash
git diff --name-only
git diff --stat
git diff --check
```

Every application/test file in the diff must map directly to Phase 2A observability or its regression tests.

If `.resurrection/fragile_files.txt` was dirty at entry, recompute:

```bash
shasum -a 256 .resurrection/fragile_files.txt
git diff -- .resurrection/fragile_files.txt | shasum -a 256
```

Both values must exactly match the entry snapshot.

Do not include the protected local file in Phase 2A diff statistics when reporting campaign changes; report it separately as a preserved pre-existing local modification.

---

## Step 9 — Write Phase 2A evidence report

Create exactly:

```text
docs/audio_hardening/phase_2a_live_path_observability_report.md
```

Use this shape:

```markdown
# Phase 2A Live-Path Observability Report

- Timestamp:
- Starting campaign evidence commit: fe96bfa7fd4482112c0b98ffd9bca2186287aacf
- Starting packet HEAD:
- origin/main:
- Protected pre-existing local modification: NONE / .resurrection/fragile_files.txt
- Protected local file hash before/after: N/A / MATCH / MISMATCH
- Protected local diff hash before/after: N/A / MATCH / MISMATCH

## Implementation
- Files changed:
- Diagnostics/session mechanism:
- Real-time callback behavior changed: NO / explain and BLOCK
- Final transcript authority changed: NO
- Capture backend changed: NO

## Observable boundaries
- session created:
- provider resolved:
- provider started/start failed:
- first capture observed:
- provider intake/processing observed:
- first partial:
- engine liveTranscript publish:
- LivePreviewController observation:
- provider error:
- stream stop:
- final path start:
- stale callback rejection:

## Validation
- Focused diagnostics tests:
- LivePreviewInvariantTests:
- AudioRecorderTapStateTests:
- EngineLifecycleStateMachineTests:
- Apple/provider tests:
- NemotronRealAudioPartialPipelineTests: PASS / SKIP / NOT RUN with reason
- VerificationRunner:
- Full suite executed/failures/skips:
- git diff --check:

## Evidence boundary
- Installed app replaced: NO
- Real microphone tested: NO
- Bluetooth/Zoom route churn tested: NO
- TCC changed: NO
- User DexDictate preferences intentionally changed: NO
- Dependencies changed: NO

## Phase 2A verdict
- PASS / BLOCKED

## Earliest unresolved failure
- None / exact failure
```

---

## Step 10 — Update Operational State only after validation

If Phase 2A passes:

- keep installed live-caption behavior (`UNK-002`) **unknown**; this phase does not prove the real microphone/UI path;
- record the diagnostics implementation as source/test verified or partially verified, not installed-app verified;
- keep `INV-006` unresolved pending the real microphone proof;
- keep AUHAL deferred;
- record that Phase 2B is the next task: installed-app live microphone proof on the existing AVAudioEngine backend;
- record the preservation rule for the pre-existing `.resurrection/fragile_files.txt` modification if it was present, without claiming its contents are project authority.

Do not mark live transcription “working” merely because diagnostics/tests pass.

---

## Step 11 — Stage, commit, and push only authorized campaign files

If validation passes, stage each Phase 2A path explicitly. Do not use broad staging commands.

Example shape only — substitute the actual authorized changed paths:

```bash
git add Sources/DexDictateKit/<exact-phase2a-files>
git add Tests/DexDictateTests/<exact-phase2a-tests>
git add OPERATIONAL_STATE.md
git add docs/audio_hardening/phase_2a_live_path_observability_report.md
```

Then:

```bash
git diff --cached --name-only
git diff --cached --check
```

Hard gate: `.resurrection/fragile_files.txt` must **not** appear in the staged set.

Review every staged path. Commit only if every path maps to Phase 2A:

```bash
git commit -m "test(audio-hardening): instrument live transcription path"
git push origin work/dexdictate-audio-hardening
```

No force push. No merge. No `main` mutation.

After push, verify the protected local file hashes one final time if it was dirty at entry.

---

## Completion rule

Phase 2A passes only when all of these are true:

- current AVAudioEngine/live-provider architecture remains intact;
- the live path has session-scoped, content-free diagnostics capable of localizing the next real-microphone failure;
- diagnostics do not add unsafe per-buffer real-time work;
- deterministic live/session tests pass;
- VerificationRunner passes;
- full XCTest suite passes;
- final transcript authority remains unchanged;
- no dependency/settings/output/UI-design/capture-backend changes occurred;
- the pre-existing `.resurrection/fragile_files.txt` modification, if present, is unchanged and uncommitted;
- Phase 2A report and Operational State are committed/pushed to the hardening branch.

If a required check fails after one Phase-2A-caused repair pass, stop with `BLOCKED` and the earliest unresolved failure. Do not proceed to installed-app testing or AUHAL.

## Final response

Return only:

1. Phase 2A verdict;
2. final branch HEAD;
3. exact Phase 2A changed files;
4. protected `.resurrection/fragile_files.txt` before/after hash status;
5. diagnostics boundary summary;
6. focused-test results;
7. Nemotron real-audio test result/skip reason;
8. VerificationRunner result;
9. full-suite executed/failure/skip counts;
10. confirmation that installed app, real microphone, TCC, audio routes, dependencies, final-output authority, and protected local modification were not changed/tested beyond the stated evidence boundary;
11. earliest unresolved failure, if any.
