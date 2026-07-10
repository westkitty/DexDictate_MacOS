# Final Model Selection Closure Audit

Verified by re-reading current source (not just recalling prior packet docs) after the BUG-007
fix. All checks below reflect the state on disk right now.

## Settings → Models & Accuracy

- ✅ Top picker labeled `Active Dictation Model` — `ModelsAccuracyPage.swift:40`.
- ✅ Top picker changes the true active dictation selection — bound to
  `activeModelSelectionBinding`, which calls `ModelSelectionActions.applyActiveModelSelection`
  (pins `preferredPrimaryEngineID` and/or `activeWhisperModelID`), not a bare storage binding.
- ✅ Top picker and status caption do not contradict each other — both read
  `ModelSelectionActions.primaryEngineID`/`primaryEngineStatusExplanation` off the same settings/
  registry state (`ModelsAccuracyPage.swift:44-57`).
- ✅ `Model Auto-Promotion` (was "Model Selection") is clearly a separate, non-competing control
  with its own explanatory caption (`ModelsAccuracyPage.swift:85-103`) — governs idle-benchmark
  auto-swap only, does not touch `activeWhisperModelID`/`preferredPrimaryEngineID` itself.
- ✅ `Model Library` (was "Choose Model", header now "Model Library & Other Engines") is not a
  competing fake selector — it shares `primaryEngineID`/`activeWhisperModelID` state with the top
  picker, so a selection made in either always agrees with the other.
- ✅ Installed models are under "Installed Dictation Models" (`QuickSettingsView.swift`
  `installedModelRows`).
- ✅ Downloadable models are under "Download Models" (`downloadableModelRows`).
- ✅ Downloadable rows never show a selection checkmark — `rowView`'s `isEngineRole` branch
  aside, non-role rows only ever get the green checkmark when `isSelected`, and a not-installed
  row's `isSelected` is structurally always `false` (only installed Whisper ids or a healthy
  Parakeet can be `true` — see `display(for:)`).
- ✅ Other Engines / Engine Roles are not presented as Whisper models — separate section, each
  row labeled with its real `userFacingModeName` role and an On/Off indicator instead of a
  selection checkmark.
- ✅ Parakeet role is honest — shown as its own row (`Installed Dictation Models` or `Download
  Models` depending on health), never mixed into the Whisper rows, labeled with its own
  `displayName`/`userFacingModeName`.
- ✅ Imported models still appear installed — `medium.en (Imported)` unaffected by the BUG-007
  fix (only non-English legacy-scan display names changed; imported-origin display names are
  untouched, per `WhisperModelCatalog.refresh()`'s separate imported-model branch).

## Popover model dropdown

- ✅ Uses same active model state as Settings — `DexContextChips` reads
  `ModelSelectionActions.primaryEngineID`/`whisperRows`, identical calls to Settings'.
- ✅ Same three-section grouping present: "Installed Dictation Models" / "Download Models" /
  "Other Engines / Engine Roles" (`DexStateFirstComponents.swift` Menu, confirmed unchanged by
  this packet).
- ✅ Selecting an installed dictation model updates state immediately — `selectWhisper`/
  `selectProvider` write directly to `@AppStorage`-backed `AppSettings`, which both surfaces
  observe via `@ObservedObject`/`@Published`.
- ✅ Download-only rows are explicit download actions (labeled "— Download", never checkmarked).
- ✅ Other Engines show role/on-off state (e.g. "Nemotron 3.5 ASR Streaming 0.6B — Live
  Streaming (On)"), not fake active-model state.

## Persistence (BUG-007 focus)

- ✅ Downloaded model remains installed after catalog refresh — `downloadModel` calls
  `refresh()` on success before returning; confirmed by existing
  `testImportReplacesExistingModelMetadata`/`ModelSelectionActionsTests` coverage and, for the
  legacy-file case specifically, `testLegacyMultilingualInstallDoesNotMaskEnglishCatalogCounterpart`
  (new).
- ✅ Downloaded model remains installed after app relaunch — `Models`/`ModelMetadata` are
  `~/Library/Application Support/DexDictate` paths, not sandboxed, not bundle-relative; confirmed
  directly against real `debug.log`/`diagnostics.jsonl` evidence showing `medium.en.bin` and
  `ggml-base.bin` loading successfully across multiple relaunches and across debug/production
  builds alike (see `DIAGNOSIS.md`).
- ✅ Imported model remains installed — same mechanism as downloads (shared `ImportedModelMetadata`
  sidecar scheme), unaffected by this fix.
- ✅ Active selection remains selected after relaunch — `activeWhisperModelID`/
  `preferredPrimaryEngineID` are plain `@AppStorage`, persisted by `UserDefaults` independently of
  the catalog scan; `WhisperModelCatalog.resolveSelection(savedID:)` additionally guards against a
  saved-but-now-missing model by falling back honestly with a surfaced warning (pre-existing,
  unaffected by this fix; covered by
  `testResolveSelectionFallsBackToBestAvailableWhenSavedMissing`/`testResolveSelectionKeepsValidSavedSelection`).
- ✅ Reinstall/build does not hide user-downloaded models — `Models`/`ModelMetadata` live outside
  the app bundle entirely; `./build.sh`'s codesign/reinstall never touches
  `~/Library/Application Support/DexDictate`.

## Regression from BUG-006B (stop button placement)

- ✅ Start button remains in hero when idle — `PopoverHeroView.swift`, rendered only
  `if engine.state == .stopped`.
- ✅ Stop button remains below chips/result content and above Settings/footer when active —
  `PopoverRootView.swift`, rendered `if engine.state != .stopped` between the `ScrollView` and
  the footer divider.
- ✅ Stop button still calls the same stop action — `MainActorAction.run { engine.stopSystem() }`,
  identical to the pre-BUG-006B combined button's Stop branch.
- ✅ Model dropdown is not overlapped by the stop button — they're in non-overlapping vertical
  positions (`compactControlsRow` inside the `ScrollView`, `stopDictationButton` after it,
  outside the `ScrollView`), confirmed by re-reading the current view hierarchy; no `ZStack`/
  absolute positioning is used anywhere in this path that could cause overlap.

## Verdict

No open code-level defect found beyond BUG-007 itself, which is fixed (display-name
disambiguation in `WhisperModelCatalog.recognizedInstalledModel`). All other items in this
checklist were already correct as of BUG-006 and remain correct now. See
`MODEL_SELECTION_DONE_GATE.md` for the formal gate.
