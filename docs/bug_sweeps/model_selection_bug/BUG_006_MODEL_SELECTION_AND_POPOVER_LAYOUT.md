# BUG-006 — Model Selection Clarity + Popover Stop Button Placement

## BUG-006A — Model selection UI was confusing and partly disconnected

### Root cause

Full evidence in `DIAGNOSIS.md`. Summary: DexDictate has two real underlying settings —
`AppSettings.preferredPrimaryEngineID` (which engine, Parakeet or Whisper, produces the
committed/pasted transcript) and `AppSettings.activeWhisperModelID` (which Whisper size, used
whenever Whisper is primary). Before this fix:

- The Settings → Models & Accuracy **top "Active Model" picker** only wrote
  `activeWhisperModelID` via a bare `Picker` binding — it never touched
  `preferredPrimaryEngineID`. If Parakeet was currently primary (the common case, since
  Parakeet-if-healthy is the default), selecting a different Whisper model there silently did
  nothing to what was actually typed. **This was a real binding bug**, not just a labeling
  problem.
- The lower **"Choose Model" list** and the **popover model dropdown** were already correctly
  wired (both called the same `ModelSelectionActions.selectWhisper`/`selectProvider`), but
  presented Parakeet/Whisper (real, mutually-exclusive primary-engine choices) and
  Nemotron/Moonshine/Apple Speech (independent feature-role toggles — Live Transcription,
  Command Mode — that never affect the primary engine) as one undifferentiated list of
  same-shaped, checkmark-style rows. That's a UI-honesty problem: it implied five
  interchangeable "models" when there were really only two primary-engine choices plus two
  unrelated feature toggles.
- A third picker, "Model Selection" (`settings.modelSelectionMode`, auto-idle-benchmark vs.
  manual promotion), sat directly beneath the top "Active Model" picker with an ambiguous label
  that read as if it were a second, competing way to choose the model — it actually only
  controls whether the idle benchmark system is allowed to auto-swap the Whisper model.

### What was confusing

- Two disconnected "make this the model" controls (top picker vs. lower list) with different
  real effects.
- A third, unrelated picker sitting right between them with a name similar enough to be
  mistaken for another model selector.
- Parakeet/Whisper (real primary-engine alternatives) and Nemotron/Moonshine/Apple Speech
  (feature-role toggles) sharing one flat list with identical selection styling.
- "Active Model: medium.en" (top picker) could disagree with "Primary dictation engine:
  Parakeet" (further down) with no explanation of why — because they read different state.

### What was actually broken vs. what was just mislabeled

- **Broken (binding bug)**: the top picker's disconnection from `preferredPrimaryEngineID`.
- **Mislabeled (presentation bug, not broken)**: the flat model list; the "Model Selection"
  auto-promotion picker's name; the lack of any honest "this is what's actually happening"
  headline.
- **Already correct**: not-downloaded models never silently become active
  (`WhisperModelCatalog.downloadModel` gates `applyWhisperSelection`); popover dropdown and the
  Settings model list already shared state before this fix.

### Files changed

- **`Sources/DexDictateKit/Transcription/ModelSelectionActions.swift`** (moved here from
  `Sources/DexDictate/`, made `public`): added `ActiveModelRow`/`activeModelRows`/
  `applyActiveModelSelection` (the unified Parakeet + installed-Whisper row set for the new
  top selector) and `primaryEngineStatusExplanation` (single honest status string shared by
  Settings' top section and `LiveTranscriptionStatusView`'s "Primary dictation engine" line).
  Moved out of the app target specifically so this shared logic — the actual subject of the
  fix — is reachable from `Tests/DexDictateTests` (see Testing below).
- **`Sources/DexDictate/SettingsWindow/ModelsAccuracyPage.swift`**: top picker relabeled
  "Active Dictation Model", rewired through `ModelSelectionActions.applyActiveModelSelection`
  (previously a bare `$settings.activeWhisperModelID` binding); added the honest status caption
  underneath; "Model Selection" renamed to "Model Auto-Promotion" with a clarifying caption;
  "Transcription Engines" header renamed "Model Library & Other Engines".
- **`Sources/DexDictate/QuickSettingsView.swift`** (`LiveTranscriptionStatusView`): "Choose
  Model" renamed "Model Library"; rows split into three explicit sections — "Installed
  Dictation Models" (Parakeet if healthy + installed Whisper sizes, checkmark-style, real
  primary-engine choices), "Download Models" (unhealthy Parakeet + not-yet-downloaded Whisper
  sizes, always showing an explicit "Download" action, never a checkmark), "Other Engines /
  Engine Roles" (Nemotron/Moonshine/Apple Speech, shown with an "On"/"Off" role indicator
  instead of a selection checkmark). Removed the now-shared `primaryEngineStatusExplanation`/
  `primaryEngineIsParakeet` duplicate logic in favor of the new `ModelSelectionActions` helpers.
- **`Sources/DexDictate/DexStateFirstComponents.swift`** (`DexContextChips`, the popover model
  chip): same three-section split applied to the dropdown Menu — "Installed Dictation Models" /
  "Download Models" / "Other Engines / Engine Roles", with role engines labeled by their actual
  function (e.g. "Nemotron 3.5 ASR Streaming 0.6B — Live Streaming (On)") instead of looking
  like plain alternative dictation models.
- **`Tests/DexDictateTests/ModelSelectionActionsTests.swift`** (new): see Testing below.

### How Settings and popover now share model state

Both surfaces call the exact same `ModelSelectionActions` functions:
`activeModelRows`/`applyActiveModelSelection` for the new top Settings picker,
`whisperRows`/`selectWhisper`/`selectProvider`/`primaryEngineID` for the Model Library list and
the popover dropdown. None of the three surfaces (top picker, Model Library, popover dropdown)
keep their own copy of "what's selected" — they all derive it live from
`AppSettings.preferredPrimaryEngineID` / `AppSettings.activeWhisperModelID` via the same shared
functions, so a change from any one of them is visible in all three immediately (SwiftUI
`@ObservedObject`/`@AppStorage` publishing does the rest — no new plumbing was needed).

### How downloadable models behave

Unchanged, and already correct before this fix: tapping a not-yet-downloaded model calls
`ModelSelectionActions.selectWhisper(isInstalled: false, ...)`, which downloads via
`WhisperModelCatalog.downloadModel` first and only calls `applyWhisperSelection` (making it
active) on success — if the download throws, nothing becomes active. What changed is purely
presentational: "Download Models" rows now live in their own explicitly-labeled section and are
never rendered with a selection checkmark, so a not-yet-installed model can no longer be
mistaken for an already-active one.

### How Other Engines are represented

Nemotron, Moonshine, and Apple Speech now appear only in "Other Engines / Engine Roles"
sections (Settings' Model Library, and the popover dropdown) — never in "Installed Dictation
Models" or "Download Models", since they are not primary-engine alternatives. Each row shows
its actual role (`userFacingModeName`: "Live Streaming" for Nemotron/Apple Speech, "Command"
for Moonshine) and an explicit On/Off state reflecting the real toggle it drives
(`liveTranscriptionEnabled`/`commandModeEnabled`) rather than a model-selection checkmark.
Tapping one still calls `ModelSelectionActions.selectProvider`, which still only ever flips
those two feature toggles — it was never possible for these three to become the pinned primary
engine, and that invariant is now also enforced by test
(`testApplyProviderSelectionForEngineRolesNeverPinsPrimaryEngine`).

## BUG-006B — Stop Dictation button placement

### Where it moved

Previously one `Button` in `Sources/DexDictate/PopoverHeroView.swift` served both "Start
Dictation" and "Stop Dictation" (icon/text/color swapped on `engine.state`), sitting at the top
of the popover's scrollable content — directly above `compactControlsRow` (the model/trigger/
status chip row). While recording, the red Stop button therefore visually sat above/across the
chip row instead of below it.

Split into two:
- **`PopoverHeroView`**: keeps only the "Start Dictation" half, now conditionally rendered
  (`if engine.state == .stopped`) — exactly the condition under which the old combined button
  used to read "Start Dictation".
- **`PopoverRootView`**: new `stopDictationButton`, rendered when `engine.state != .stopped`
  (the same condition the old combined button used to read "Stop Dictation"), placed **after**
  the scrollable content (hero, chips, result, history) and **before** the footer divider/
  Settings row — so it always sits below the model/status chip section and above Settings,
  and stays visible without scrolling since it's outside the `ScrollView`.

### Why the stop action behavior was not changed

`stopDictationButton` calls `MainActorAction.run { engine.stopSystem() }` — the identical call
the old combined button made on its Stop branch (`toggleDictation()`'s `else` branch). Nothing
about session lifecycle, engine state transitions, or when stopping is possible changed; only
the control's position and which view renders it changed.

## Manual validation

See `VALIDATION.md` — marked **NEEDS_ANDREW** for all live click-through steps, since this
cannot be exercised by clicking through the running LSUIElement app from this environment.
