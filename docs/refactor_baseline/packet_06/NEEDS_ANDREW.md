# Packet 06 — Screenshot / Manual Validation Gaps

Same LSUIElement/accessibility blocker as Packets 01–05 — cannot click through the popover
or Settings window in this environment.

Not captured this packet:
- Screenshot: Vocabulary section with an entry
- Screenshot: Commands section
- Screenshot: Input card without the two buttons

Manual validations not performed (require live UI interaction and/or real audio):
- Add vocabulary entry foo→bar on the page → dictate "foo" → confirm "bar" is typed; delete
  entry → confirm behavior reverts
- Define/verify a voice command (e.g. built-in "scratch that") executes
- History window → Learn Correction → confirm new mapping appears in the page's list

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: `swift test --filter "Vocabulary|CommandProcessor"` — 17/17 passed
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- Full `git diff` reviewed: only `QuickSettingsView.swift` (two buttons hidden behind
  `showLegacyVocabularyCommandsButtons`) and
  `SettingsWindow/VocabularyCommandsPage.swift` (built out) touched.
  `VocabularySettingsView.swift`, `CustomCommandsSheet.swift`, and
  `VocabularyCorrectionSheet.swift`: zero lines touched — both editor content views embedded
  verbatim, learn-correction flow untouched. No forbidden files. No `@AppStorage` key
  added/removed/renamed (grepped the diff — vocabulary/commands storage isn't
  `@AppStorage`-backed at all, it's managed internally by `VocabularyManager`/
  `CustomCommandsManager`, neither of which was touched).

## Required-inspection findings

- **Content-view vs. window-wrapper**: both `VocabularySettingsView` (public struct) and
  `CustomCommandsView` (internal struct, in `CustomCommandsSheet.swift`) are already pure
  content views with no window wrapper baked in — no split was needed, embedded as-is.
- **Import/export**: neither view has any import/export UI. Nothing to preserve.
- **Learned-correction provenance**: `VocabularyItem` (`VocabularyManager.swift`) has only
  `id`, `original`, `replacement` — no source/provenance field. Per the packet's own
  guidance, the "Learned" badge was skipped rather than adding a stored field (schema
  change, out of scope). Learned corrections still flow through the same unmodified
  `VocabularyManager.add`, so they appear in the page's list identically to manually-added
  entries — just without a distinguishing badge.
- **Pipeline order caption**: verified in `TranscriptionEngine.swift` (read-only) —
  `commandProcessor.process(...)` runs, then `vocabularyManager.applyEffective(...)` runs on
  its output. The plan-of-record's proposed caption ("Commands run first, then Vocabulary
  corrections, then the text is inserted") matches the real order exactly; used verbatim.
- **Lifecycle**: neither editor view has any `onAppear`/`task`/`onDisappear`/timer/observer.
  No stop condition triggered.
