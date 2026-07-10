## Packet Result
- Packet: BUG-007 + Model Selection Closure Sweep
- Branch: speech-engine-exploration-benchmarks
- Commit hash: (see final response)
- Pushed: Yes
- Files changed:
  - `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift` — `recognizedInstalledModel`
    now appends `"(Multilingual)"` to the display name of a legacy non-English `ggml-<stem>.bin`
    file when that stem (`tiny`/`base`/`small`/`medium`) has a real `.en` counterpart in
    `downloadableCatalog`
  - `Tests/DexDictateTests/WhisperModelCatalogTests.swift` — updated display-name expectations
    for the four affected stems
  - `Tests/DexDictateTests/ModelSelectionActionsTests.swift` — new test:
    `testLegacyMultilingualInstallDoesNotMaskEnglishCatalogCounterpart`
- Files inspected but not changed: `ModelSelectionActions.swift`, `ModelsAccuracyPage.swift`,
  `QuickSettingsView.swift`, `DexStateFirstComponents.swift`, `PopoverRootView.swift`,
  `PopoverHeroView.swift` (all confirmed correct/unchanged since BUG-006 — no code drift)
- Forbidden files touched: No
- Tests run: full `swift test`; targeted `swift test --filter WhisperModelCatalogTests`;
  targeted `swift test --filter ModelSelectionActionsTests`
- Test result: 417 tests, 0 failures (416 pre-existing + 1 new) — clean on first run, no
  known-flaky rerun needed
- Storage keys changed: None
- Downloaded model behavior: Unchanged (already correct) — `downloadModel` saves to
  `Models/<id>.bin` with a metadata sidecar and refreshes the catalog on success
- Imported model behavior: Unchanged (already correct)
- Settings selector behavior: Unchanged since BUG-006 (re-audited, correct)
- Popover selector behavior: Unchanged since BUG-006 (re-audited, correct)
- Stop button regression: None — BUG-006B placement confirmed intact via source re-read
- Remaining risks: None beyond a subjective wording preference (see
  `MODEL_SELECTION_DONE_GATE.md`)
- Rollback required: No
- Next recommended packet: none — per explicit instruction, stopping after this fix.

## Root cause summary (for the record)

BUG-007 as reported ("downloaded models keep appearing as needing Download") was **not** a
persistence, path, refresh, or download-failure defect — real filesystem and log inspection
confirmed every model the app itself ever downloaded (`medium.en.bin`, metadata-backed) persists
correctly across relaunches and rebuilds. The actual defect was a **display-name ambiguity**:
two pre-existing files (`ggml-base.bin`, `ggml-small.bin`, dated before this session's work,
almost certainly fetched by hand via whisper.cpp's own script rather than the app) are genuinely
different models from the app's `base.en`/`small.en` catalog entries, but were displayed with
bare labels ("Base", "Small") indistinguishable-looking from their English catalog counterparts
sitting right next to them under "Download." Fixed by disambiguating the display name
("Base (Multilingual)") rather than by touching any path, id, or download logic.
