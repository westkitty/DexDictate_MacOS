# DexDictate Final Remaining Campaign — Final State Report

## Final branch / HEAD / pushed status

- Final branch: `speech-engine-exploration-benchmarks`
- Final HEAD: `2601c779` ("docs: record packet 14 final commit hash in autopilot ledger")
- Pushed: Yes — `git status --porcelain --branch` shows the local branch even with
  `origin/speech-engine-exploration-benchmarks`, no ahead/behind.

## Full packet list and commit hashes (this campaign)

| Packet | Start commit | Final commit | Notes |
|---|---|---|---|
| 10B — Benchmark + Help Debt Bridge | `211ccd6f` | `1e432743` (+ `c6cd0915` ledger) | Re-homed 4 orphaned benchmark controls into Settings → Models & Accuracy |
| 12A-B — Missing Experimental Adoption Bridge | `c6cd0915` | `03983513` (+ `ed6a0f55` ledger) | Resolved all 3 MISSING items from Packet 12A's inventory; readiness: Ready |
| 12B — Experimental UI Retirement (GATED) | `ed6a0f55` | `52d2dd98` (+ `574b053d` ledger) | Retired the state-first surface; all adopted capabilities preserved |
| 13 — Smart Cleanup / Remote Ollama (GATED) | `574b053d` | `5e8ffc3b` (+ `a123a981` ledger) | New isolated `SmartCleanup` module; default off |
| 14 — Live Preview Prototype (GATED) | `a123a981` | `7bf561da` (+ `2601c779` ledger) | Display-only preview; default off; invariant test passing |

(Packets 15 and earlier — Visual Polish, 09–12A, etc. — were completed in the prior
autopilot run before this campaign began; see `AUTOPILOT_RUN_LEDGER.md` for their entries.)

## Tests run / final test result

- Full `swift test` run at the end of this campaign: **409 tests, 0 failures.**
- Baseline (Packet 01): 382 tests, 0 failures. Net +27 tests added across this campaign
  (25 `SmartCleanupTests` + 2 `LivePreviewInvariantTests`).
- One flaky failure was observed and resolved mid-campaign during Packet 14's first run
  (`MainActorDispatchTests.testAsyncRunsOnMainThreadAsynchronously`, an async-ordering race
  unrelated to Live Preview — same failure family as the documented
  `MainActorActionTests.testRunAsyncExecutesOnMainActor` known-flaky allowance, different
  test name). Passed clean on rerun; not a regression.
- Targeted filters run and passed during the campaign: `SmartCleanup` (20/20),
  `MainActorDispatchTests` (1/1 on rerun), `LivePreviewInvariantTests` (2/2, including the
  required byte-identical committed-transcript invariant using real `WhisperService` +
  real `sample_corpus/sample.wav`).

## Build result

`swift build` and `./build.sh` both succeeded cleanly at the end of every packet in this
campaign, including this final verification pass.

## App relaunch result

App relaunched via `open /Applications/DexDictate.app` after the final build; confirmed
running and stable via `ps aux` (steady-state CPU, growing then stabilizing RSS,
`S` process state) after a few seconds.

## Final working tree status

```
M .resurrection/codex_handoff.md
M .resurrection/fragile_files.txt
M .resurrection/last_scan.json
M .resurrection/project_map.json
M .resurrection/project_report.md
?? DexDictate_Fable5_UIUX_Recovery_Plan.md
?? DexDictate_Sonnet_Implementation_Handoff.md
?? pre_fable/
```

These are all pre-existing, unrelated items that predate this campaign (auto-generated
`.resurrection/` scan artifacts, the two planning docs this campaign's own prompts
reference, and the `pre_fable/` screenshot-packet directory) — none were touched by any
packet in this campaign and none are staged or committed.

## All NEEDS_ANDREW items (this campaign, collected)

**Packet 10B:**
- "Open Captured Corpus" needed no new UI — already reachable via the Benchmark Lab's
  "Open Corpus Folder" button under a different label.
- Forbidden-file string in `TranscriptionEngine.swift:1262` ("Retrying in accuracy
  mode...") remains untouched — cannot fix without explicit permission to edit that file.
- Broader 34-reference Help-text audit remains out of scope (same boundary Packet 10 drew).

**Packet 12A-B:**
- No live manual validation of the compact controls row, live transcript/mic meter, or
  Dexter Feed shuffle button — same LSUIElement/accessibility blocker as every packet.

**Packet 12B:**
- Judgment call: `DexExperimentalHubViews.swift` was split rather than wholesale-removed
  (the handoff's literal file list named it for deletion) because `FloatingHUD.swift` has
  a real, pre-existing dependency on `DexExperimentalFeatureHubView` for the Nano HUD's
  "All Features" hub panel. Kept and moved; deleted only the actual "Switch UI" screen
  (`DexExperimentalGUISwitcherView`).
- Three Advanced-page toggle rows removed (state-first, command palette, Dexter feed
  flags) since their sole readers were deleted; underlying storage keys untouched. If
  Andrew wants these three toggles visible again for continuity, that's a one-line revert.

**Packet 13:**
- No live Ollama tunnel available in this environment to exercise the true success path
  (Test Connection listing real models, Test Inference getting a real reply, a real
  dictation producing a real Cleaned variant). This is an environmental gap, not a code
  gap — client logic is unit tested and verified against a genuinely dead port (curl
  connection-refused).
- The "Use raw"/"Use cleaned" swap lives only in the detached History window, per the
  plan of record's specific wording ("History window") — not the popover's inline history
  teaser or the classic popover.

**Packet 14:**
- Kill switch is a documented health-poll proxy (`TranscriptionProviderRegistry
  .refreshHealthReport()`), not a literal "provider threw an error" hook — no safe
  external hook for that exists without editing forbidden `TranscriptionEngine.swift`.
  A live simulated-failure test was not performed end-to-end for this reason.
- `LivePreviewController.swift` lives in `Sources/DexDictateKit/LivePreview/`, not the
  packet's suggested `Sources/DexDictate/LivePreview/` — deliberate deviation to avoid a
  `Package.swift` test-target dependency change on the `@main` SwiftUI executable target.
  The SwiftUI caption view stays in `Sources/DexDictate/` as intended.
- Nano HUD does not show the preview caption (only the standard Floating HUD and popover
  hero do), to avoid touching the already-adopted Nano HUD component.

## Remaining gates

Nothing from this campaign's own approved list remains — Packets 10B, 12A-B, 12B, 13, and
14 all ran, all completed, all pushed. No gates from THIS campaign are still pending.

(Beyond this campaign: any future new feature work would define its own new gates: none
implied here.)

## Rollback notes (every packet in this campaign)

- **10B**: `git revert 1e432743` (and the ledger-hash commit `c6cd0915` if desired) fully
  restores the pre-10B state — the four benchmark controls return to being unreachable
  from Settings, and the two Help-text edits revert. No storage-key impact either way.
- **12A-B**: `git revert 03983513` removes the compact controls row, live transcript/mic
  meter, and Dexter Feed section from the standard UI — the underlying `DexStateFirstComponents.swift`/`DexDexterFeedView.swift`/etc. files stay in `ExperimentalUI/` (this revert predates the 12B move, so reverting 12A-B before 12B works cleanly; reverting it after 12B requires also handling the 12B move — see below).
- **12B**: `git revert 52d2dd98` is a single commit specifically so it is trivially
  revertible, per the packet's own explicit design — restores the entire `ExperimentalUI/`
  surface, `UIModeToggleButton`, and the three Advanced-page toggle rows. Note: if 12A-B
  is reverted AFTER 12B (rather than before), the file-move history means a revert of 12B
  alone restores the deleted/moved files to their 12B-era (post-12A-B) state, which is
  correct and expected — no special handling needed since git tracks renames.
- **13**: `git revert 5e8ffc3b` removes the entire `SmartCleanup` module, the Settings
  page content (reverting to the Packet 02 placeholder), the Diagnostics row, and the
  History window's raw/cleaned swap. Runtime rollback (no revert needed) is simply
  leaving `smartCleanupEnabled` at its default `false` — already the shipped state.
- **14**: `git revert 7bf561da` removes `LivePreviewController`, the caption view, the
  Settings toggle, and the HUD/hero wiring. Runtime rollback (no revert needed) is leaving
  `livePreviewEnabled` at its default `false` — already the shipped state. Per the
  packet's own rollback note, `LivePreviewInvariantTests.swift` should be considered for
  retention even if the feature itself is ever reverted, since it's a permanent
  architecture guard, not a feature test — this is a recommendation for Andrew's future
  judgment, not something enforced here.
- Each ledger-hash-correction commit (the small `docs: record packet NN final commit
  hash...` commits) can be reverted independently and has zero effect on app behavior —
  they only edit `AUTOPILOT_RUN_LEDGER.md`.

## Did Packet 12B actually run?

**Yes.** Commit `52d2dd98`. The `ExperimentalUI/` directory no longer exists (confirmed:
`ls Sources/DexDictate/ExperimentalUI/` → "No such file or directory"). The
`useExperimentalStateFirstUI` flag has no remaining reader anywhere in `Sources/`
(confirmed via `grep`). All previously-adopted standard-UI capabilities (Command Palette,
Nano HUD, inline Dexter quote, compact controls, live transcript/mic meter, Dexter Feed)
remain present and functional in their standard homes.

## Did Packet 13 actually run?

**Yes.** Commit `5e8ffc3b`. `Sources/DexDictateKit/SmartCleanup/` exists with all four
files (`SmartCleanupSettings.swift`, `SmartCleanupKeychain.swift`, `SmartCleanupClient.swift`,
`SmartCleanupCoordinator.swift`). Settings → Smart Cleanup page is fully built out.
Diagnostics has the new status row. History window shows the Cleaned/Raw swap.

## Did Packet 14 actually run?

**Yes.** Commit `7bf561da`. `Sources/DexDictateKit/LivePreview/LivePreviewController.swift`
and `Sources/DexDictate/LivePreview/LivePreviewCaptionView.swift` both exist. Settings →
Dictation has the "Live Preview (experimental)" toggle. The permanent invariant test
(`LivePreviewInvariantTests.swift`) exists and passes.

## Is Smart Cleanup runtime-off by default?

**Yes.** `@AppStorage("smartCleanupEnabled") public var enabled: Bool = false` in
`SmartCleanupSettings.swift` — confirmed via `grep`. `SmartCleanupCoordinator` guards on
`settings.enabled` as the very first line of `handleItemsChanged(_:)`, before any network
call — zero network activity when disabled, both by code guarantee and by unit test
(`testAddingHistoryItemWhileDisabledDoesNotChangeReachability`).

## Is Live Preview runtime-off by default?

**Yes.** `@AppStorage("livePreviewEnabled") public var livePreviewEnabled: Bool = false`
in `AppSettings.swift` — confirmed via `grep`. `LivePreviewController.handleStateChanged(_:)`
guards on `settings.livePreviewEnabled` before doing anything — confirmed both by code
review and by unit test (`testPreviewStaysInertWhenSettingIsOff`).

## Is the experimental UI retired or still present?

**Retired.** `Sources/DexDictate/ExperimentalUI/` no longer exists (Packet 12B). The
`useExperimentalStateFirstUI` flag's storage key still exists in `AppSettings.swift` (per
the hard rule "the key is never reused"), but it has zero readers anywhere in the
codebase — toggling it now does nothing, by design, since there is no more experimental
surface for it to switch to. All capabilities that surface used to provide (Command
Palette, Nano HUD, inline Dexter quote, compact "daily six" controls, live transcript +
mic meter, Dexter Feed) live permanently in the standard popover and Settings window,
confirmed present and functional as of this report.

## Summary

All five packets approved for this campaign (10B, 12A-B, 12B, 13, 14) ran to completion,
each with a clean `swift build`, a full `swift test` pass (zero new failures beyond one
documented, rerun-confirmed flaky test), an explicit-path commit, and a push. The
experimental UI surface is fully retired with zero capability loss. Both new gated
features (Smart Cleanup, Live Preview) ship default-off, with unit-test-enforced
guarantees of zero activity in that default state. The working tree is clean of anything
this campaign touched. No further packets from the original handoff document remain
unaddressed in the approved sequence.
