# BUG-006 Validation

## Automated

- `swift build`: clean, exit 0 at each stage (initial code changes, after moving
  `ModelSelectionActions` into `DexDictateKit`, and final).
- `swift test` (full suite): **416 tests, 0 failures** — 410 pre-existing + 6 new
  (`ModelSelectionActionsTests`), clean on first run, no known-flaky rerun needed. Log:
  `swift_test.log` in this directory.
- Targeted: `swift test --filter ModelSelectionActionsTests` — 6/6 passed individually before
  the full-suite run (see below for what each covers).
- `./build.sh`: clean, exit 0. Built for production, signed with "DexDictate Development",
  installed to `/Applications/DexDictate.app`.
- Relaunch verification: `pkill -x DexDictate_MacOS` then `open /Applications/DexDictate.app`;
  confirmed via `ps aux` that a single `DexDictate` process is running post-relaunch.

## New tests (`Tests/DexDictateTests/ModelSelectionActionsTests.swift`)

| Test | Protocol requirement covered |
|---|---|
| `testApplyWhisperSelectionUpdatesActiveModelAndPinsWhisperAsPrimary` | Selecting an installed model updates the active model setting (the exact binding bug BUG-006A fixed) |
| `testActiveModelRowsReflectSameStateSettingsAndPopoverShare` | Settings and popover selector state use the same underlying setting/model |
| `testSelectWhisperWithUnknownDownloadableIDDoesNotActivate` | Not-downloaded/unknown model does not become active unless downloaded |
| `testWhisperRowsDistinguishInstalledFromDownloadable` | Model catalog display names distinguish installed vs. downloadable states |
| `testWhisperRowsMarkImportedModelsInstalled` | Imported model selection persists / displays correctly |
| `testApplyProviderSelectionForEngineRolesNeverPinsPrimaryEngine` | Other engines (Nemotron/Moonshine) are never exposed as — or become — the active primary dictation model |

`ModelSelectionActions` was relocated from `Sources/DexDictate/` (app executable target) to
`Sources/DexDictateKit/` specifically to make this possible — it has no SwiftUI dependency, so
this is a pure-logic relocation, not the kind of view-layer move the BUG-004/BUG-005 precedent
warned against. `Package.swift` itself was **not** changed; `DexDictateKit` was already a target
`Tests/DexDictateTests` depends on.

### What remains untested (and why)

`SettingsRootView`'s SwiftUI layout (the top picker, section labels, "On"/"Off" badges,
`PopoverHeroView`/`PopoverRootView`'s button placement) cannot be unit tested — those views live
in `Sources/DexDictate/` (the app executable target), and `Tests/DexDictateTests` depends only
on `["DexDictateKit", "DexDictateObjCSupport"]` per `Package.swift`. Per this packet's explicit
boundary ("do not destabilize `Package.swift` just to test view layout"), no attempt was made to
move these SwiftUI views themselves or restructure the test target. Everything in them that is
*not* pure layout — every actual model-selection/state decision — was already extracted into
`ModelSelectionActions` and is covered by the new tests above.

## Static checks

- `git diff --stat`: touches exactly `Sources/DexDictate/DexStateFirstComponents.swift`,
  `Sources/DexDictate/PopoverHeroView.swift`, `Sources/DexDictate/PopoverRootView.swift`,
  `Sources/DexDictate/QuickSettingsView.swift`,
  `Sources/DexDictate/SettingsWindow/ModelsAccuracyPage.swift` (modified), plus
  `Sources/DexDictate/ModelSelectionActions.swift` deleted and
  `Sources/DexDictateKit/Transcription/ModelSelectionActions.swift` added (a pure move + public
  API surface, not new logic), `Tests/DexDictateTests/ModelSelectionActionsTests.swift` (new),
  and this packet's docs — plus pre-existing, unrelated `.resurrection/*` modifications that
  predate this session and are not part of this change.
- `git diff -- <all modified/added Swift files> | grep -i "AppStorage\|UserDefaults"`: no
  output — **no storage keys added, removed, or renamed.** (`ModelSelectionActions` reads/writes
  the same three pre-existing `AppSettings` keys — `preferredPrimaryEngineID`,
  `activeWhisperModelID`, `liveTranscriptionEnabled`, `commandModeEnabled` — it always did.)
- No forbidden files touched: no bundled-asset changes, no `Package.swift` changes, no Smart
  Cleanup/Live Preview default changes, no audio capture/output/insertion changes, no engine
  support removed (Parakeet/Nemotron/Moonshine/Apple Speech/Whisper all still present and
  reachable, just honestly labeled).

## Manual validation checklist — **NEEDS_ANDREW**

I cannot personally click through this LSUIElement menu-bar app on the live desktop.

### Settings model selector

1. Open Settings → Models & Accuracy.
2. Confirm the top selector is now labeled "Active Dictation Model" (not "Active Model").
3. Select `tiny.en` if installed — confirm the label changes to `tiny.en` and the status line
   beneath it now reads something like "Whisper produces the text that gets typed."
4. Select `medium.en (Imported)` if present — confirm the label changes accordingly.
5. Confirm the lower "Model Library" section (was "Choose Model") shows three clearly labeled
   groups: "Installed Dictation Models", "Download Models" (only if any models aren't
   downloaded), "Other Engines / Engine Roles".
6. Click a not-downloaded model in "Download Models" — confirm it downloads, then becomes
   selected (checkmark) once complete.
7. Confirm Nemotron/Moonshine/Apple Speech appear only under "Other Engines / Engine Roles",
   each showing their role (e.g. "— Live Streaming") and an "On"/"Off" indicator, never a
   selection checkmark.
8. Confirm the "Model Auto-Promotion" picker (was "Model Selection") no longer sits directly
   under the model picker with an ambiguous name.

### Popover model selector

9. Open the popover.
10. Tap the model chip (brain icon) — confirm the menu now shows "Installed Dictation Models" /
    "Download Models" / "Other Engines / Engine Roles" sections.
11. Select a different installed model — confirm the chip label updates immediately.
12. Reopen Settings → Models & Accuracy — confirm the "Active Dictation Model" picker shows the
    same selection you just made in the popover.

### Stop button placement

13. Start dictation (press your trigger, or tap "Start Dictation" in the popover).
14. Confirm the red "Stop Dictation" button now appears **below** the model/trigger/status chip
    row, not across the orb/hero area.
15. Confirm it appears **above** the Settings/footer row and stays visible without scrolling.
16. Confirm it doesn't cover the orb, model dropdown, retry controls, or status chips.
17. Click it — confirm dictation stops exactly as it did before (same `stopSystem()` call).
