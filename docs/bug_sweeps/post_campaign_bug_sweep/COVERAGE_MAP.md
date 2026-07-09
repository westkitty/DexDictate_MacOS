# Post-Campaign Bug Sweep — Coverage Map

Sweep base: `speech-engine-exploration-benchmarks` @ `860b17d7` (one commit past Andrew's
reported `4e501e40` — the Quit-dialog fix, confirmed working by Andrew before this sweep
began).

Diff range used for "what did this campaign actually change" checks:
`211ccd6f..860b17d7` (start of Packet 10B through the Quit fix).

## Areas inspected

| # | Area | Method | Result |
|---|---|---|---|
| 1 | Build/test baseline | `swift build`, `swift test` (multiple runs across the campaign, most recently after the Quit fix) | 409/409 passing, clean build, no new warnings beyond the pre-existing `fluidaudio` unhandled-resource notice |
| 2 | Settings page reachability | Compared `SettingsPage` enum cases vs `SettingsRootView`'s switch statement | All 11 cases present, mapped, instantiate correctly — no orphaned or missing page |
| 3 | Slim popover wiring | Read `PopoverRootView.swift`, `PopoverHeroView.swift`, `PopoverResultView.swift`, `PopoverHistoryTeaser.swift` in full; grepped for `.confirmationDialog`/`.alert`/`.sheet` across `Sources/DexDictate/` | Found and already fixed: quit confirmation dialog (see BUG-001 in ledger, already committed as `860b17d7` before this sweep). Found a **suspected** same-class risk in `PopoverResultView.swift`'s `.sheet` for Learn Correction — see SUSPECTED-001. |
| 4 | Feature-loss checklist | Cross-referenced `DexDictate_Feature_Loss_Checklist.md` rows against current source; re-confirmed zero-diff on every forbidden/fragile file across the full campaign diff range | No feature-loss regressions found |
| 5 | Smart Cleanup default-off | `grep -rn "smartCleanupEnabled"` | `@AppStorage("smartCleanupEnabled") public var enabled: Bool = false` — confirmed default off, single definition, no shadow |
| 6 | Smart Cleanup dead-endpoint behavior | Re-read `SmartCleanupClient.swift`'s catch-all error paths; re-confirmed via the campaign's own `curl` connection-refused test | Graceful `.failure(.network(...))`, no crash, no modal — consistent with design |
| 7 | Live Preview default-off | `grep -rn "livePreviewEnabled"` | `@AppStorage("livePreviewEnabled") public var livePreviewEnabled: Bool = false` in `AppSettings.swift`; `LivePreviewController.handleStateChanged` guards on it as the first check |
| 8 | Live Preview display-only invariant | Re-read `LivePreviewController.swift` in full; re-ran `LivePreviewInvariantTests` | Invariant test still passes (2/2). Found a **confirmed** state-machine bug in the same file during this pass — see BUG-002 |
| 9 | History raw/cleaned behavior | Re-read `HistoryWindow.swift`'s `HistoryItemRow`, `TranscriptionHistory.swift`'s `setCleanedText`, traced the `SmartCleanupCoordinator` → `TranscriptionHistory.$items` re-publish loop for a possible feedback loop | No infinite loop (the `lastSeenItemID` guard correctly short-circuits the coordinator's own re-publish). Found a narrow **suspected** low-severity edge case around delete+undo re-triggering cleanup — see SUSPECTED-002 |
| 10 | Experimental UI retirement — dangling refs / lost capability | Fresh, independent `grep` for every deleted type name across `Sources/`; confirmed `ExperimentalUI/` directory no longer exists | Clean — only two harmless doc-comment mentions remain (historical references, not code) |
| 11 | Help/documentation paths | `grep -c "Quick Settings →"` in `HelpView.swift` | 22 stale references remain — this is the SAME already-documented, already-scoped-out debt from Packet 10/10B (down from 34+ before those fixes); not a new bug |
| 12 | Storage keys and migrations | `git diff 211ccd6f..HEAD -- Sources/ \| grep "@AppStorage"` | Only additive `+` lines (`livePreviewEnabled`, `smartCleanupEnabled`, `smartCleanupBaseURL`, `smartCleanupModel`) — zero renames or removals |
| 13 | Launch/build/install path assumptions | Re-ran `./build.sh` after the Quit fix | Clean build, sign, install; app relaunches and stays stable per `ps aux` |
| 14 | LSUIElement/manual-validation limitations | Confirmed unchanged — same blocker as every packet this whole project | Documented throughout; manual validation checklist provided in the final report |
| 15 | Dexter identity preservation | `git diff 211ccd6f..HEAD --stat` against all Dexter/fragile files | Zero diffs on every file in the list |
| 16 | Accessibility / secure-field fallback risk | `git diff 211ccd6f..HEAD --stat -- Sources/DexDictateKit/Output/SecureInputContext.swift` (and the rest of the forbidden-file list) | Zero diffs — untouched all campaign |
| 17 | Audio route recovery regression risk | Zero diffs on `AudioRecorderService.swift`/`AudioRecorderRecoverySupport.swift`/`AudioTapInstaller.m`/`AudioResampler.swift` confirmed | No risk introduced |
| 18 | Clipboard/output behavior regression risk | Zero diffs on `ClipboardManager.swift`/`OutputCoordinator.swift`; reviewed the one behavior-adjacent change (`HistoryItemRow`'s copy button now copies `displayText` — whichever of raw/cleaned is currently shown — instead of always `item.text`) | Deliberate, documented Packet 13 change, not a regression; copying the currently-displayed variant matches user intent |
| 19 | Tests that appear flaky or misleading | Identified both members of the async-ordering-race test family (`MainActorActionTests.testRunAsyncExecutesOnMainActor`, `MainActorDispatchTests.testAsyncRunsOnMainThreadAsynchronously`) | Both are pre-existing (not written this campaign), both test the same `MainActorAction.run` timing guarantee, both are known-flaky-alone/pass-clean-on-rerun. Documented as an accepted test-suite characteristic, not a new issue. |
| 20 | New test coverage gaps | Reviewed `LivePreviewInvariantTests.swift` against the actual state machine | The invariant test suite did not cover the full `.listening → .transcribing → .ready` lifecycle, which is exactly where BUG-002 lived — gap closed by the Pass 2 fix's new regression test |

## Files read in full during this sweep

- `docs/refactor_baseline/final_remaining_campaign/FINAL_STATE_REPORT.md`
- `docs/refactor_baseline/AUTOPILOT_RUN_LEDGER.md` (tail, all campaign entries)
- `Sources/DexDictate/PopoverRootView.swift`
- `Sources/DexDictateKit/LivePreview/LivePreviewController.swift`
- `Sources/DexDictate/LivePreview/LivePreviewCaptionView.swift`
- `Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift`
- `Sources/DexDictate/HistoryWindow.swift` (`HistoryItemRow`)
- `Sources/DexDictateKit/EngineLifecycle.swift` (state transition table)
- `Sources/DexDictate/SettingsWindow/SettingsPage.swift`, `SettingsRootView.swift`
- `Sources/DexDictate/FloatingHUD.swift` (`FloatingHUDController.show()`/`setup()`)
- `Sources/DexDictate/PopoverHistoryTeaser.swift`

## Manual validation gap (stated plainly)

This sweep is code-level only. No live speech, no live menu-bar click-through, no live
Ollama tunnel test were performed — same LSUIElement/accessibility/network-availability
blockers documented in every packet this whole project. See `FINAL_BUG_SWEEP_REPORT.md`
section 6 for the exact manual checklist Andrew should run.
