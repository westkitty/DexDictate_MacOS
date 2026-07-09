# Packet 10B — Benchmark Control Debt Plan

Source of debt: `docs/refactor_baseline/packet_10/NEEDS_ANDREW.md`, "New finding: four more
orphaned benchmark controls." Packet 07 hid the popover's entire "Benchmarks & Corpus"
`DisclosureGroup` (behind `showLegacyBenchmarksCorpusGroup = false` in
`QuickSettingsView.swift`), and only two of its six controls got a new Settings-window home
at the time (Import Model, Open Benchmark Capture → renamed "Open Benchmark Lab…"). Four
did not.

## Per-control disposition

| Old label (hidden popover) | Source | Still reachable elsewhere? | Disposition |
|---|---|---|---|
| Run Benchmarks Now | `adaptiveBenchmarkController.runBenchmarksNow()` in `ModelBenchmarking.swift` | No — Benchmark Lab window has no equivalent trigger, only a "Copy Benchmark Command" (manual CLI invocation), a materially different capability | **New home**: Settings → Models & Accuracy → new "Benchmark Tools" section, same button label, same `.disabled()` guard (`status.isBusy` / engine not ready-or-stopped), same call |
| Restore Stable Defaults | `settings.restoreStableDictationDefaults()` in `AppSettings.swift` | No — distinct from General settings' "Restore Defaults" (`resetToDefaults()`), which is a full-app factory reset; this one only touches model/end-preset/trim/retry/domain-mode/correction-sheet settings | **New home**: same "Benchmark Tools" section, same button label, same call, unchanged scope |
| Open Captured Corpus | `benchmarkCaptureController.openCorpusFolder()` | **Yes** — the Benchmark Lab window (opened via "Open Benchmark Lab…", already migrated in Packet 07) has its own "Open Corpus Folder" button calling the identical `openCorpusFolder()` method with the identical `sessionDirectory == nil` disabled guard. Packet 10's grep for the literal string "Open Captured Corpus" missed this because the Benchmark Lab's button uses a different label ("Open Corpus Folder") for the same capability. | **No new UI needed** — already reachable, just under a different (arguably clearer) label in a window the user already has to open for benchmarking anyway |
| `BenchmarkResultsSection` (historical results / promotion display) | private struct in `QuickSettingsView.swift` | No — no equivalent view exists elsewhere | **New home**: widened from `private` to internal (matching the established "widen struct visibility" pattern from Packets 03–11), re-hosted unchanged in the new "Benchmark Tools" section |

## Implementation

- `Sources/DexDictate/QuickSettingsView.swift`: `BenchmarkResultsSection` widened `private struct` → `struct`. Zero logic changes — same properties, same body.
- `Sources/DexDictate/SettingsWindow/ModelsAccuracyPage.swift`: added `adaptiveBenchmarkController: AdaptiveBenchmarkController` param and `@ObservedObject private var benchmarkResultsStore = BenchmarkResultsStore.shared` (singleton, same pattern as `WhisperModelCatalog.shared`/`TranscriptionEngine.shared` already used on this page); added a "Benchmark Tools" section reusing the exact hidden-popover calls and disabled conditions.
- `Sources/DexDictate/SettingsWindow/SettingsRootView.swift`: threaded `adaptiveBenchmarkController` through to `ModelsAccuracyPage`.
- `Sources/DexDictate/SettingsWindow/SettingsWindowController.swift`: added `adaptiveBenchmarkController` parameter to `show(...)`.
- `Sources/DexDictate/DexDictateApp.swift`: both `settingsWindowController.show(...)` call sites (slim popover and classic popover) now pass the app's single existing `adaptiveBenchmarkController` `@StateObject` instance — same singleton-threading discipline used for `scanner`/`benchmarkCaptureController`/`historyController`/`profileManager` throughout this project.

No new `@AppStorage` keys. No forbidden files touched. No benchmark logic changed — every call site is identical to its hidden popover counterpart.

## Help-text updates (scoped to this debt only)

`Sources/DexDictate/HelpView.swift`:
- `SafeModeContent` "Stable Dictation Defaults" entry: location string updated from stale
  `"Quick Settings → Benchmark → Restore Stable Defaults button"` to
  `"Settings → Models & Accuracy → Benchmark Tools → Restore Stable Defaults button"`.
- `BenchmarkingContent` "Restore Stable Defaults" heading/body: previously read "Not
  currently reachable from Settings or the popover — see Packet 10's report" (a
  self-referential stub written by Packet 10 to honestly reflect the gap at the time).
  Replaced with a "Benchmark Tools" heading covering both Run Benchmarks Now and Restore
  Stable Defaults at their real new location, plus a note on the results list below them.

**Not in scope**: the other 34 stale "Quick Settings →" Help references Packet 10 flagged
as a separate documentation-accuracy task are still out of scope here — this packet only
resolves the Help text tied to the four-control benchmark debt, per its own goal statement
("update stale Help-text paths where safe" in service of the benchmark bridge, not a full
Help audit).

## Forbidden-file string (unchanged, re-confirmed)

`Sources/DexDictateKit/TranscriptionEngine.swift:1262` still contains
`NSLocalizedString("Retrying in accuracy mode...", comment: "Retry progress")` — a real
user-facing string in a forbidden file. Re-confirmed present and untouched. No new
action possible without Andrew's explicit permission to edit that file.
