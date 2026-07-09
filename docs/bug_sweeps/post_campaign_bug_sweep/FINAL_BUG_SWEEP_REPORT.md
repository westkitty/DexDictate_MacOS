# Bug Sweep Report

## 1. Executive summary
- Target: DexDictate, `speech-engine-exploration-benchmarks` branch, post-campaign state
  (starting HEAD `860b17d7`, which already includes an ad hoc live-bug fix — the Quit
  confirmation dialog — that Andrew reported and confirmed working just before this sweep
  began).
- Scope inspected: full 20-item audit checklist across app shell/popover/Settings, the two
  new campaign features (Smart Cleanup, Live Preview), all high-risk preserved systems
  (audio, transcription, output, clipboard, secure input), Dexter identity preservation,
  experimental-UI retirement completeness, storage keys, tests, and documentation paths.
  See `COVERAGE_MAP.md` for the full per-area breakdown.
- Editing mode: narrow, evidence-backed fixes only — no redesign, no new features, no
  drive-by refactors.
- Validation mode: `swift build`, full `swift test`, `./build.sh` + relaunch, targeted test
  filters, static diff/storage-key/default-off/experimental-UI checks. No live
  speech/mic/menu-bar click-through was possible (same LSUIElement/accessibility blocker
  documented throughout this whole project) — manual validation checklist provided below
  for Andrew.
- Confirmed bugs found: 3 (BUG-001, already fixed and Andrew-confirmed before this sweep;
  BUG-002 and BUG-003, found and fixed during this sweep).
- Confirmed bugs fixed or specified: 3 of 3.
- Remaining confirmed bugs: 0.
- Suspected risks: 3 (SUSPECTED-001 through SUSPECTED-003 — none confirmed, none fixed,
  all documented with exact reproduction/verification steps).
- Blockers: live speech/mic/menu-bar interaction (environment-level, same as every packet
  this whole project); no live Ollama tunnel (Smart Cleanup's true success path, carried
  forward from Packet 13).
- Final verdict: **No unresolved confirmed bugs in inspected scope; remaining risks need
  verification.**

## 2. Sweep history

| Pass | Purpose | Areas inspected | Bugs found | Fixes applied/specified | Validation performed | New issues discovered | Result |
|---|---|---:|---:|---|---|---:|---|
| 1 | Audit only, no edits | All 20 checklist areas (see `COVERAGE_MAP.md`) | 1 confirmed (BUG-002), 3 suspected | None (audit-only pass) | Static grep/diff review, re-ran existing test suite (409 baseline + prior fixes) | 1 confirmed, 3 suspected | Ledger drafted |
| 2 | Apply safe fixes | `LivePreviewController.swift`, `SmartCleanupCoordinator.swift` | 1 more confirmed (BUG-003, a compiler warning found while validating BUG-002's fix); 1 more confirmed mid-pass (the redundant `.receive(on:)` timing defect, folded into BUG-002) | BUG-002 fixed (2 edits: the `false→true` fix, then the timing fix); BUG-003 fixed; new regression test added | `swift build`, `swift test` (iterative, until green), targeted `SmartCleanup`/`LivePreview` filters | 0 | All 3 confirmed bugs fixed |
| 3 | Resweep | Re-read all 3 fixed files in full; re-verified BUG-001 untouched; re-ran targeted + full suite | 0 new | None needed | `swift test --filter LivePreview`/`SmartCleanup`, full `swift test`, `git diff --stat` | 0 | Sweep closed, no Pass 4 needed |

## 3. Complete bug ledger

See `BUG_LEDGER.md` for the full structured entries. Summary:

**Confirmed (all fixed):**
- BUG-001 — Quit confirmation dialog silently never appeared in the slim popover (fixed
  before this sweep, Andrew-confirmed, carried forward for traceability).
- BUG-002 — Live Preview's "Finalizing…" badge stuck permanently `true` after the first
  completed dictation, plus a related redundant-dispatch timing defect discovered while
  validating the fix (both fixed together).
- BUG-003 — `SmartCleanupCoordinator`'s default init argument triggered a Swift 6
  actor-isolation warning (forward-compatibility defect, not a runtime bug today; fixed).

**Suspected (not confirmed, not fixed — documented for Andrew's verification):**
- SUSPECTED-001 — `PopoverResultView.swift`'s "Learn Correction" `.sheet` may share
  BUG-001's popover-dismissal risk class; pre-existing, not a campaign regression, never
  re-validated after the slim popover became default.
- SUSPECTED-002 — Smart Cleanup could re-attempt a previously-failed cleanup if a
  delete+undo interaction brings that item back to "newest"; narrow edge case, arguably
  reasonable, not an automatic retry storm.
- SUSPECTED-003 — Smart Cleanup's API key field writes to Keychain on every keystroke;
  inefficient, not incorrect.

## 4. Fixes applied

### BUG-002 fix (`Sources/DexDictateKit/LivePreview/LivePreviewController.swift`)
1. Changed `default: endSession(clearImmediately: false)` to
   `endSession(clearImmediately: true)` in `handleStateChanged(_:)` — the finalizing badge
   and caption now always clear when the engine returns to `.ready`/`.stopped`/`.error`/
   `.initializing`.
2. Removed the redundant `.receive(on: DispatchQueue.main)` from the `engine.$state` and
   `engine.$inputLevel` Combine subscriptions — `TranscriptionEngine` is `@MainActor`, so
   these were already guaranteed to publish on the main actor; the redispatch only added
   an unnecessary run-loop-tick delay.
3. Added `testFinalizingBadgeClearsAfterTranscriptionCompletes` to
   `Tests/DexDictateTests/LivePreviewInvariantTests.swift`, driving a real
   `TranscriptionEngine` through the full `.listening → .transcribing → .ready` lifecycle.

### BUG-003 fix (`Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift`)
Changed `init(settings: SmartCleanupSettings = .shared)` to
`init(settings: SmartCleanupSettings? = nil) { self.settings = settings ?? .shared }` —
resolves the default inside the actor-isolated initializer body instead of in a
nonisolated default-argument-expression context, eliminating the Swift-6-mode warning.
The stored property remains non-optional; no call site was broken.

### BUG-001 (already fixed prior to this sweep, restated for completeness)
`Sources/DexDictate/PopoverRootView.swift`: replaced `.confirmationDialog` with a native
`NSAlert.runModal()` for the Quit confirmation, matching the same pattern already proven
in `DiagnosticsPage`'s "Reset Core Audio?" alert. Committed as `860b17d7`, confirmed
working by Andrew.

## 5. Remaining risks and blockers

- **SUSPECTED-001, 002, 003** (see section 3 / `BUG_LEDGER.md`) — none confirmed, none
  require immediate action, all have exact next-verification steps documented.
- **No live Ollama tunnel** — Smart Cleanup's true success path (Test Connection listing
  real models, a real dictation producing a real Cleaned variant) remains unverified
  end-to-end, carried forward from Packet 13.
- **LSUIElement/accessibility blocker** — this sweep, like every packet before it, could
  not click through the running app, speak into the microphone, or drive the popover/HUD
  interactively. All fixes were validated by code-level tests and architecture review, not
  live interaction. See the manual validation checklist below.

## 6. Validation checklist
- [x] swift build — clean, zero errors, zero warnings beyond the pre-existing `fluidaudio`
  notice
- [x] swift test — 410 tests; 1 failure was the documented pre-existing flaky test
  (`MainActorActionTests.testRunAsyncExecutesOnMainActor`), clean on rerun (2/2)
- [x] ./build.sh — clean build, sign, install; app relaunched and confirmed stable via
  `ps aux`
- [x] targeted tests — `SmartCleanup` (20/20), `LivePreview` (3/3), `MainActorActionTests`
  rerun (2/2)
- [x] diff review — `git diff --stat` shows exactly 3 files touched this sweep
  (`LivePreviewController.swift`, `SmartCleanupCoordinator.swift`,
  `LivePreviewInvariantTests.swift`), all within this campaign's own new code or its tests
- [x] storage-key check — zero `@AppStorage`/`UserDefaults` changes this sweep
- [x] default-off checks for Smart Cleanup and Live Preview — both confirmed
  `= false` at their single definitions
- [x] experimental UI retirement check — `ExperimentalUI/` directory still absent; no new
  live surface reintroduced; the one remaining `useExperimentalStateFirstUI` reference is
  the already-documented dead key + hidden legacy toggle row from Packet 12B, unchanged
- [x] manual validation checklist prepared for Andrew (below)

## 7. Final verdict

**No unresolved confirmed bugs in inspected scope; remaining risks need verification**

---

## Manual validation checklist for Andrew

The following require live interaction this sweep could not perform (same
LSUIElement/accessibility/network-availability limitations as every packet this project):

1. Launch the app (`open /Applications/DexDictate.app`) and confirm it starts cleanly.
2. Open the slim popover from the menu bar icon.
3. Open Settings (gear icon) and click through all 11 sidebar pages — confirm each loads
   without a crash or blank page.
4. Perform one real dictation (hold/press your trigger, speak a sentence, release) and
   confirm the transcript appears and gets inserted into a text field (try Notes or
   TextEdit).
5. Focus a password/secure field, dictate, and confirm the result is copied to the
   clipboard rather than pasted (secure-field copy-only fallback).
6. In Settings → Dictation, toggle "Live Preview (experimental)" on, dictate again, and
   confirm: a dimmed/italic "PREVIEW" caption appears while speaking, a "Finalizing…"
   badge appears briefly after you stop, and — this is the specific bug this sweep fixed —
   **the "Finalizing…" badge disappears once the result arrives, rather than staying
   stuck on screen indefinitely.** Toggle it back off afterward (it defaults off).
7. If you have a real Ollama tunnel available: in Settings → Smart Cleanup, enable it,
   fill in your base URL/model/API key, click Test Connection and Test Inference, confirm
   both succeed, then dictate once and check the History window for a Cleaned/Raw pair.
   If no tunnel is available, this step remains unverified (as it has been since Packet 13).
8. In the popover, dictate something, then click "Learn Correction" on the result — confirm
   the correction sheet actually appears (this checks SUSPECTED-001; if it does NOT appear,
   that confirms a second instance of the same bug class as the just-fixed Quit dialog, and
   is worth reporting back).
9. Confirm the Dexter flavor ticker scrolls, the watermark rotates/shows correctly, and (on
   a completely fresh install/reset) the launch animation plays.
10. Click the power icon (or "Quit App" in the footer overflow menu) one more time to
    confirm the Quit fix still works as expected.
