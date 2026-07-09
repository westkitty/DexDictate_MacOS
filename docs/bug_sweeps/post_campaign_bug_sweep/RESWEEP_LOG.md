# Post-Campaign Bug Sweep — Resweep Log (Pass 3)

Performed after all Pass 2 fixes were applied and validated. Revisited every fixed bug,
inspected adjacent code, searched for newly introduced regressions, and reran targeted
tests.

## BUG-001 (Quit confirmation dialog) — revisited

- Re-checked `Sources/DexDictate/PopoverRootView.swift`: `git diff --stat` against this
  sweep's starting point shows **zero changes** to this file during Pass 2 — the fix
  (committed as `860b17d7`, before this formal sweep began) is untouched and intact.
- `confirmAndQuit()` still present, still used by both the header power icon and the
  footer overflow menu's "Quit App" item.
- No adjacent regression possible since nothing in Pass 2 touched this file.

## BUG-002 (Live Preview "Finalizing…" stuck) — revisited

- Re-read the full, current `LivePreviewController.swift` top to bottom (not just the
  diff) to check for any other state-reset path with the same class of bug.
- Confirmed all three call sites of `endSession(clearImmediately:)` now pass `true`
  (the top-of-function disabled/killed guard, the `default:` case, and `killForSession`)
  — no remaining call site can leave `isFinalizing`/`caption`/`micLevel` stuck.
- While fixing this, discovered and fixed a second, related defect in the same file during
  Pass 2 itself (the redundant `.receive(on: DispatchQueue.main)` on `$state`/`$inputLevel`
  causing test flakiness and a real one-tick UI latency) — already folded into BUG-002's
  fix commit rather than filed as a separate bug, since it was found and fixed in direct
  service of validating BUG-002's own regression test.
- Traced the full lifecycle once more by hand against `EngineLifecycle.swift`'s transition
  table: `.stopped → .initializing → .ready → .listening → .transcribing → .ready`. Every
  transition now correctly drives `beginSession()` (on `.listening`), the finalizing badge
  (on `.transcribing`), and a full reset (everything else) — no gap remains.
- Reran `swift test --filter LivePreview`: 3/3 passed.

## BUG-003 (SmartCleanupCoordinator actor-isolation warning) — revisited

- Re-read the full, current `SmartCleanupCoordinator.swift`. Confirmed the stored
  `settings` property is still non-optional (`private let settings: SmartCleanupSettings`)
  — only the `init` parameter became `SmartCleanupSettings?`, resolved via `?? .shared`
  inside the (actor-isolated) body. No call site was broken: `SmartCleanupCoordinator()`
  (used by `.shared`) and both explicit `SmartCleanupCoordinator(settings: settings)` call
  sites in `SmartCleanupTests.swift` all still compile and behave identically.
- Rebuilt with the fix in place and grepped the full build log for `warning:` — the
  Swift-6-mode warning is gone; no new warning appeared anywhere else in the log.
- Reran `swift test --filter SmartCleanup`: 20/20 passed.

## Adjacent-code check for newly introduced regressions

- Full `swift test` run after all three fixes: 410 tests, 1 failure
  (`MainActorActionTests.testRunAsyncExecutesOnMainActor`, the documented pre-existing
  flaky test, unrelated to any file this sweep touched) — rerun clean (2/2).
- `git diff --stat` confirms only three files touched in total across all of Pass 2:
  `LivePreviewController.swift`, `SmartCleanupCoordinator.swift`,
  `LivePreviewInvariantTests.swift` — no other file in the tree was modified, so no other
  area could have regressed from these changes.
- Manually reread `SmartCleanupCoordinator.swift`'s `handleItemsChanged`/`attemptCleanup`
  logic once more (unrelated to the fix, but adjacent in the same file) to confirm the
  earlier-flagged SUSPECTED-002 edge case (delete+undo re-triggering cleanup) is unchanged
  by this sweep's fix — confirmed unchanged, still just a documented suspected risk, not
  newly introduced or newly resolved.

## New confirmed bugs found during Pass 3

None. No new confirmed bugs surfaced during the resweep. (One new SUSPECTED risk — none —
also not found; the pre-existing SUSPECTED-001/002/003 items from Pass 1 remain
unconfirmed and undisturbed.)

## Conclusion

No further passes required. All three confirmed bugs found in this sweep (BUG-001 through
BUG-003) are fixed and validated; the resweep found no new confirmed bugs and no
regressions introduced by the fixes themselves.
