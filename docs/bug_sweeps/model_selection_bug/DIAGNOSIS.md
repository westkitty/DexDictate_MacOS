# BUG-006 Diagnosis

## 1. What setting/storage key actually controls the dictation model used for normal dictation?

Two keys jointly, both `AppSettings` `@AppStorage`:

- `preferredPrimaryEngineID` (`AppSettings.swift:120`, `@AppStorage("preferredPrimaryEngineID")`, default `""` = automatic) selects the **primary engine** — Parakeet or Whisper. Consumed directly by `TranscriptionEngine.runPrimaryEngine` (`Sources/DexDictateKit/TranscriptionEngine.swift:847-870`):
  - pinned to `.whisperKit` → always runs Whisper, even if Parakeet is healthy.
  - pinned to `.parakeetTDT06Bv3`, or unpinned (`""`) → runs Parakeet if `registry.parakeetProvider.healthCheck().isAvailable`, else falls back to Whisper.
- `activeWhisperModelID` (`AppSettings.swift:270`, `@AppStorage("activeWhisperModelID_v1")`) selects **which Whisper size** is used whenever Whisper ends up being the primary engine (pinned, or as the auto fallback).

This is a real, working two-key system — not broken, but nothing in the UI said so plainly before this fix.

## 2. What setting/storage key controls the Settings top picker?

Before the fix: `settings.activeWhisperModelID` **only** (`ModelsAccuracyPage.swift:35`, a bare SwiftUI `Picker` binding). It never touched `preferredPrimaryEngineID`.

## 3. What controls the lower Choose Model / model library list?

`LiveTranscriptionStatusView` (`QuickSettingsView.swift:1756-2005`, re-hosted into `ModelsAccuracyPage`). Reads `modelCatalog.availableModels` + `WhisperModelCatalog.downloadableCatalog` for Whisper rows, `registry.healthReport`/provider objects for engine rows. Tapping a row calls `ModelSelectionActions.selectWhisper`/`selectProvider` (`ModelSelectionActions.swift`), which **do** write `preferredPrimaryEngineID`: Whisper rows pin `.whisperKit`; Parakeet pins `.parakeetTDT06Bv3`; Nemotron/Apple Speech set `liveTranscriptionEnabled = true`; Moonshine sets `commandModeEnabled = true`.

## 4. What controls the popover model dropdown?

`DexContextChips` (`DexStateFirstComponents.swift`) — calls the **exact same** `ModelSelectionActions.selectWhisper`/`selectProvider` functions as the Settings "Choose Model" list (#3). These two surfaces were already correctly sharing state before this fix. The disconnect was only between these two and the Settings **top** picker (#2).

## 5. What controls Parakeet/Nemotron/Moonshine/Apple Speech?

- **Parakeet**: `preferredPrimaryEngineID` pin — a real, mutually-exclusive alternative to Whisper for the primary/committed dictation engine.
- **Nemotron / Apple Speech**: `settings.liveTranscriptionEnabled` (one shared boolean; the registry auto-prefers Nemotron over Apple Speech when both are healthy). This **only** affects the live-preview captions shown while speaking — never the committed/pasted transcript's engine.
- **Moonshine**: `settings.commandModeEnabled` — gates a short-utterance ("<2.5s") command-phrase check that runs *before* the primary engine, for recognized commands only. Does not change which engine handles ordinary dictation content.

## 6. Are Whisper models and other engines part of one selector or separate systems?

Two real systems: (a) the primary dictation engine (Whisper vs Parakeet — mutually exclusive, drives what's actually typed), and (b) two independent feature toggles (Live Transcription: Nemotron/Apple Speech; Command Mode: Moonshine) that never affect the committed transcript's engine. Before this fix, the "Choose Model" list presented all five as identically-shaped rows with the same checkmark affordance, implying one unified selector — that framing, not the underlying data, was the dishonest part.

## 7. When the user clicks `medium.en (Imported)`, what code path runs?

Depended on which control (pre-fix):
- **Top "Active Model" Picker**: only `settings.activeWhisperModelID = "medium.en"` ran. `preferredPrimaryEngineID` was untouched — if Parakeet was currently primary, nothing about the real active engine changed and no visible "active" indicator anywhere updated. **This was the binding bug.**
- **"Choose Model" list / popover dropdown**: `ModelSelectionActions.selectWhisper(id: "medium.en", isInstalled: true, ...)` → `applyWhisperSelection` → sets `activeWhisperModelID = "medium.en"` **and** `preferredPrimaryEngineID = "whisperKit"` — immediately changes the real primary engine, reflected everywhere.

## 8. When the user clicks a not-downloaded model, what code path runs?

Only reachable via "Choose Model" list / popover dropdown (the top picker only ever listed installed models, via `modelCatalog.availableModels`). `ModelSelectionActions.selectWhisper(isInstalled: false, ...)` → `WhisperModelCatalog.downloadModel(entry)` (network fetch, writes model + metadata sidecar, `refresh()`s the catalog) → only on success, `applyWhisperSelection` pins it active/primary. If the download throws, `applyWhisperSelection` is never reached and nothing becomes active — this "no-op until downloaded" behavior was already correct.

## 9. When the user clicks a popover dropdown model, what code path runs?

Identical to #7/#8's "Choose Model" path — same `ModelSelectionActions` calls. Already correctly shared with Settings' lower list before this fix.

## 10. Is there an actual binding bug, or is the UI merely presenting status/download rows as though they are selectors?

**Both, at different severity:**
- **Real binding bug**: the Settings top "Active Model" Picker was disconnected from `preferredPrimaryEngineID`. Selecting a model there could silently do nothing to the actual active engine whenever Parakeet was currently primary (the common case, since Parakeet-if-healthy is the default).
- **UI-honesty bug** (presentation, not a binding defect): the "Choose Model" list and popover dropdown presented Parakeet/Whisper (real, mutually-exclusive primary-engine alternatives) and Nemotron/Moonshine/Apple Speech (independent feature-role toggles) as one homogeneous list of interchangeable "active model" choices, all using the same selected-checkmark affordance.

## 11. Where is the red Stop Dictation button currently defined, and why does it land in the wrong visual layer?

`Sources/DexDictate/PopoverHeroView.swift`, inside the hero `VStack`, directly below the status row and trigger-hint text (was lines 72-85). One `Button` served both Start and Stop (icon/text/color swapped on `engine.state`), placed at the very top of the popover's scrollable content — ahead of `compactControlsRow` (the model/trigger/mode chip row) and `PopoverResultView` (retry/result). That ordering is why, while recording, the red Stop button visually sat above/across the model chip and status-chip row instead of below it.
