## Packet Result
- Packet: BUG-006 — Model Selection Clarity + Popover Stop Button Placement
- Branch: speech-engine-exploration-benchmarks
- Commit hash: (see final response)
- Pushed: Yes
- Files changed:
  - `Sources/DexDictate/SettingsWindow/ModelsAccuracyPage.swift` — honest "Active Dictation
    Model" top picker wired through `ModelSelectionActions`; "Model Selection" renamed "Model
    Auto-Promotion"; "Transcription Engines" renamed "Model Library & Other Engines"
  - `Sources/DexDictate/QuickSettingsView.swift` (`LiveTranscriptionStatusView`) — "Choose
    Model" renamed "Model Library", split into Installed/Download/Other-Engines sections
  - `Sources/DexDictate/DexStateFirstComponents.swift` (`DexContextChips`) — popover model
    dropdown menu split into the same three sections
  - `Sources/DexDictate/PopoverHeroView.swift` — Stop half of the old combined button removed;
    Start-only, idle-only now
  - `Sources/DexDictate/PopoverRootView.swift` — new `stopDictationButton`, shown below chips/
    result content and above the footer
  - `Sources/DexDictate/ModelSelectionActions.swift` deleted →
    `Sources/DexDictateKit/Transcription/ModelSelectionActions.swift` added (pure relocation +
    `public` API surface + new `ActiveModelRow`/`activeModelRows`/
    `applyActiveModelSelection`/`primaryEngineStatusExplanation` helpers)
  - `Tests/DexDictateTests/ModelSelectionActionsTests.swift` (new, 6 tests)
- Files inspected but not changed: `SettingsRootView.swift`, `SettingsSidebar.swift`,
  `PopoverResultView.swift`, `WhisperModelCatalog.swift`, `TranscriptionProviderTypes.swift`,
  `TranscriptionProviderRegistry.swift`, per-provider files (Parakeet/Nemotron/Moonshine/Apple
  Speech/WhisperKit), `TranscriptionEngine.swift` (confirmed `runPrimaryEngine` matches
  `ModelSelectionActions.primaryEngineID` exactly), `AppSettings.swift` (confirmed
  `restoreDefaults()` does not reset `preferredPrimaryEngineID`/`liveTranscriptionEnabled`/
  `commandModeEnabled` — accounted for in test cleanup), the classic (non-default)
  `ControlsView.swift` popover (left untouched — out of scope; the bug report's screenshots and
  prior sessions all reference the default slim popover / Settings surfaces)
- Forbidden files touched: No
- Tests run: full `swift test`; targeted `swift test --filter ModelSelectionActionsTests`
- Test result: 416 tests, 0 failures (410 pre-existing + 6 new) — clean on first run, no known-
  flaky rerun needed
- Manual validation: **NEEDS_ANDREW** — could not click through the running app. 17-step
  checklist in `VALIDATION.md`.
- Storage keys changed: None — reads/writes the same three pre-existing `AppSettings` keys
  (`preferredPrimaryEngineID`, `activeWhisperModelID`, `liveTranscriptionEnabled`,
  `commandModeEnabled`) that already existed before this fix
- Model selector behavior: One honest, shared source of truth
  (`ModelSelectionActions.activeModelRows`/`primaryEngineID`) now drives the Settings top
  picker, the Model Library list, and the popover dropdown — selecting in any one immediately
  updates the others
- Download behavior: Unchanged and already correct — not-yet-downloaded models download first,
  then activate only on success; now visually separated into an explicit "Download Models"
  section that's never shown with a selection checkmark
- Other engines behavior: Nemotron/Moonshine/Apple Speech are confined to "Other Engines /
  Engine Roles" sections, labeled with their real role and an On/Off indicator instead of a
  model-selection checkmark; confirmed by test that they can never pin the primary engine
- Stop button placement: Moved from the hero (`PopoverHeroView`, competing with the chip row)
  to `PopoverRootView`, below the scrollable chip/result content and above the footer/Settings
  row — same `engine.stopSystem()` call, unchanged condition (`engine.state != .stopped`)
- Remaining risks: None identified beyond the standard "cannot personally click-test live UI"
  caveat. All changes are additive/presentational plus one narrow binding fix; no architecture
  changes, no engine behavior changes beyond making the top picker actually pin the engine it
  displays (which is the fix itself, not a side effect).
- Rollback required: No
- Next recommended packet: none — per explicit instruction, stopping after this fix.
