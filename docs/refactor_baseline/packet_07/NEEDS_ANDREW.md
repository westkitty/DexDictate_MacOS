# Packet 07 — Screenshot / Manual Validation Gaps

Same LSUIElement/accessibility blocker as Packets 01–06 — cannot click through the popover
or Settings window in this environment.

Not captured this packet:
- Screenshot: Models & Accuracy page
- Screenshot: popover after benchmark card removal
- Screenshot: Benchmark Lab opened from the page

Manual validations not performed (require live UI interaction and/or real audio):
- Model switch persists and is used by the next dictation
- Import Model accepts a GGML `.bin` file via the new page's button
- Deliberately poor dictation surfaces the retry button in the popover as before (Accuracy
  Retry toggle behavior)
- "Open Benchmark Lab…" opens the capture window; a benchmark run completes and writes
  `benchmark_baseline.json` (not committed, per the never-stage list)

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: `swift test --filter "BenchmarkPromotion|AdaptiveBenchmark"` — 8/8 passed
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- Full `git diff` reviewed: `QuickSettingsView.swift` (rows hidden behind two new flags,
  `showLegacyModelAccuracyRows` and `showLegacyBenchmarksCorpusGroup`; the entire
  Benchmarks & Corpus `DisclosureGroup` — including Import Model — is now unreachable from
  the popover, matching the packet's "no benchmark UI in popover" requirement),
  `SettingsWindow/ModelsAccuracyPage.swift` (built out), `SettingsWindowController.swift` +
  `SettingsRootView.swift` + `DexDictateApp.swift` (threaded the app's existing
  `BenchmarkCaptureWindowController` instance through, alongside the scanner from Packet 04,
  rather than constructing a second one). No forbidden files (`ModelBenchmarking.swift`,
  `WhisperModelCatalog.swift`, `BenchmarkCaptureWindow.swift` internals,
  `ModelSelectionActions.swift` logic — all untouched). No `@AppStorage` key
  added/removed/renamed (grepped the diff).

## Required-inspection findings

- **Lifecycle inventory**: no `onAppear`/`task`/`onDisappear`/timer/observer is scoped to
  the Accuracy & Speed or Benchmarks & Corpus cards themselves. However,
  `AdaptiveBenchmarkController` — which backs the benchmark status text shown in the old
  Benchmarks & Corpus group — is started via `adaptiveBenchmarkController.start(engine:)` in
  `DexDictateApp`'s top-level `.onAppear` (fires when the popover appears), and has no
  `.shared` singleton. This is idle-benchmark scheduling armed by the popover's appearance,
  not a specific card's — a step above what the stop condition literally describes, and I
  did not touch `ModelBenchmarking.swift` where it's implemented. Given the packet's own
  "a one-line ... summary **if trivially readable**" qualifier, and that threading a fourth
  controller (after `scanner` and `benchmarkCaptureController`) that clearly owns
  active scheduling behavior is not trivial, **I skipped the last-promotion/status summary
  on the new page** rather than risk instantiating a duplicate scheduler. This is a
  documented scope decision, not a discovered blocker requiring a hard stop.
- **Trim/experiment locations**: "Trim Leading/Trailing Silence" already moved to Audio &
  Microphone in Packet 04. "Trailing Trim Experiment" (`enableTrailingTrimExperiment`)
  remains in the popover's Accuracy & Speed card, unmigrated — it's explicitly Packet 08
  Advanced's to relocate, noted here as instructed.
- **Benchmark Capture window**: confirmed it opens via `benchmarkCaptureController.show(engine:)`,
  callable from the new page using the threaded controller instance.
- **Scope note**: "Context Biasing" (`dictationDomainMode` / Bias Mode picker) is adjacent to
  Context Injection but not listed in this packet's goal text — left in the popover,
  unmigrated. Packet 08's mandatory pre-removal inventory will catch it (and "Trailing Trim
  Experiment") before the Quick Settings entry is hidden.
