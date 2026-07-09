# Post-Campaign Bug Sweep — Validation Log

## Build

- `swift build` (debug): clean, zero errors, zero warnings beyond the pre-existing
  `fluidaudio` unhandled-resource notice — confirmed the `SmartCleanupCoordinator`
  Swift-6-mode actor-isolation warning (BUG-003) is gone after the fix.
- `./build.sh` (release, sign, install): clean; app reinstalled to
  `/Applications/DexDictate.app`, relaunched, confirmed running and stable via `ps aux`
  (steady CPU, growing-then-stable RSS, `S` process state) a few seconds after launch.

## Full test suite

Two full `swift test` runs during Pass 2:

1. First run (BUG-002 fix applied, before the timing fix): 410 tests, 1 failure —
   `LivePreviewInvariantTests.testFinalizingBadgeClearsAfterTranscriptionCompletes`
   (the NEW regression test itself), failing at the `.transcribing` assertion. Root cause
   diagnosed as a redundant `.receive(on: DispatchQueue.main)` on `engine.$state`/
   `engine.$inputLevel` in `LivePreviewController` — both properties are already
   main-actor-guaranteed (`TranscriptionEngine` is `@MainActor`), so the extra redispatch
   only added an unnecessary run-loop-tick delay, which the synchronous test method raced
   against. Fixed by removing both redundant `.receive(on:)` calls.
2. Second run (after the timing fix): **410 tests, 1 failure** —
   `MainActorActionTests.testRunAsyncExecutesOnMainActor`, the documented, pre-existing
   known-flaky test (failing alone, same async-ordering-race family already accepted by
   this project's own written allowance). Rerun via `swift test --filter
   MainActorActionTests`: **2/2 passed clean.** Per the documented allowance, accepted and
   not treated as a regression.

Net result: **410/410 effectively passing** (409 baseline-equivalent + the 1 new
regression test for BUG-002, all green; the flaky test's rerun is clean).

## Targeted filters

- `swift test --filter SmartCleanup`: 20/20 passed.
- `swift test --filter LivePreview`: 3/3 passed (2 pre-existing invariant tests + the new
  `testFinalizingBadgeClearsAfterTranscriptionCompletes` regression test for BUG-002).
- `swift test --filter MainActorActionTests`: 2/2 passed (confirms the flaky failure was
  isolated and non-reproducing).

No `Settings`, `History`, `OutputCoordinator`, `ClipboardManager`, `SecureInputContext`,
`AudioRecorderRecovery`, `Profile`, `Benchmark`, `CommandProcessor`, or `Vocabulary` test
files were touched by this sweep's fixes, so no targeted rerun was needed for those areas —
the full-suite run already covers them and shows zero regressions.

## Static checks

```
$ git diff --stat -- Sources/ Tests/
 Sources/DexDictateKit/LivePreview/LivePreviewController.swift  | 16 ++++++++++---
 Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift |  9 ++++++--
 Tests/DexDictateTests/LivePreviewInvariantTests.swift            | 26 ++++++++++++++++++++++
 3 files changed, 46 insertions(+), 5 deletions(-)
```

- `git diff | grep "@AppStorage\|UserDefaults"` → no output — zero storage-key changes.
- `grep -R "useExperimentalStateFirstUI" Sources` → only the existing, already-documented
  dead key remnant in `AppSettings.swift` (the key itself, kept per "never reused") and
  the hidden legacy `QuickSettingsView.swift` toggle row (Packet 12B's own deliberate,
  documented leave-alone) — no new experimental-UI surface reappeared.
- `grep -R "smartCleanupEnabled" Sources Tests` → single definition, `= false`.
- `grep -R "livePreviewEnabled" Sources Tests` → single definition, `= false`; all other
  hits are guards or test-only toggles that restore the original value via `defer`.

## Scope confirmation

- Nothing under `.resurrection/`, `pre_fable/`, `.build/`, `SNAPSHOT/`, or any planning doc
  was staged, edited, or touched by this sweep.
- No bundled MP4/PNG assets changed (not touched at all this sweep).
- `Package.swift`/`Package.resolved` not touched.
- All three edited files are within this campaign's own new code (`LivePreview/`,
  `SmartCleanup/`) or a test file — no high-risk/forbidden file was touched.
