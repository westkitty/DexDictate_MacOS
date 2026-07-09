# Packet 12A-B — Missing Experimental Adoption Bridge

Resolves the three MISSING rows from `docs/experimental_adoption_inventory.md` (Packet 12A).

## 1. Pinned "daily six" compact controls

- **Source**: `DexContextChips` (trigger/model/mode pills) + `DexOutputChips` (auto-paste/
  safe-mode/clipboard-fallback status) in `Sources/DexDictate/ExperimentalUI/DexStateFirstComponents.swift`.
- **Standard-UI home**: new `compactControlsRow` in `Sources/DexDictate/PopoverRootView.swift`,
  rendered directly below `PopoverHeroView` (only when permissions are granted — the same
  branch the hero itself renders in).
- **Clean adoption**: Yes. `DexContextChips` needs `settings`, `WhisperModelCatalog.shared`,
  and `engine.transcriptionProviderRegistry` — all three already in scope in `PopoverRootView`
  without new threading (`settings` and `engine` are existing `@ObservedObject` params;
  `WhisperModelCatalog` is a singleton already referenced the same way in
  `ModelsAccuracyPage`). `DexOutputChips` needs an `OutputDisplayState`, built inline from
  `settings.autoPaste`/`settings.safeModeEnabled`/`engine.resultFeedback` — mirrors
  `DexExperimentalUIStateAdapter.rebuild()`'s own construction of the same struct, without
  reusing the adapter class itself (unnecessary weight for one popover).
- **Forbidden files avoided**: Yes — `DexContextChips.swift`/`DexOutputChips.swift`
  (inside `DexStateFirstComponents.swift`) are not forbidden files and were not edited;
  zero changes to any file under `ExperimentalUI/`.
- **Remains missing**: No — resolved.

## 2. Live transcript + mic level meter while actively listening

- **Source**: `DexTranscriptCard`/`DexMicMeter` in the same `DexStateFirstComponents.swift`;
  backing data from `TranscriptDisplayState` (`Sources/DexDictateKit/ExperimentalUI/DexExperimentalUIState.swift`,
  a plain public data struct, not a forbidden file).
- **Standard-UI home**: new `if engine.state == .listening { DexTranscriptCard(...) }` block
  in `PopoverRootView`, directly below the new compact controls row.
- **Safe existing published stream confirmed**: `engine.liveTranscript` (`@Published public
  var`) and `engine.inputLevel` (`@Published public var`, bound directly from
  `audioService.$inputLevel`) on `TranscriptionEngine` — both already public, already
  observed elsewhere (e.g. `DiagnosticsPage` already reads `engine.routeHealthSnapshot` the
  same way; `DexExperimentalUIStateAdapter` already reads both of these exact properties).
  Read-only inspection of `TranscriptionEngine.swift` confirmed `liveTranscript` is
  genuinely populated with live partial text only while a streaming-capable provider
  (Apple Speech or Nemotron) is active during `.listening` — otherwise it stays empty
  during listening and is only set to status strings ("Processing...", "Retrying...")
  in `.transcribing`/retry paths, which this feature never surfaces because it only
  renders while `engine.state == .listening`. `inputLevel` is universal (bound to the
  audio service regardless of provider), so the mic meter always works.
- **No audio tap added**: Confirmed — this only *reads* two already-`@Published`
  properties from the existing singleton; no new `AudioTapInstaller`/`AudioRecorderService`
  code, no new capture path.
- **`recentText: nil`** is passed deliberately so `DexTranscriptCard` never falls back to
  showing the last completed transcript — that stays `PopoverResultView`'s job, avoiding a
  duplicate "last transcription" line when both would otherwise be visible during the
  brief `.listening → .transcribing` transition.
- **Remains missing**: No — resolved. (Full live-preview UI beyond this — throttled partial
  updates, provider-error handling, latency measurement — is Packet 14's explicit territory
  and was not attempted here; this is a passive read of already-computed state, not a new
  live-preview feature.)

## 3. Dexter Feed (stateful multi-line quote browser)

- **Source**: `Sources/DexDictate/ExperimentalUI/DexDexterFeedView.swift`, unchanged.
- **Standard-UI home**: `Settings → Dexter & Personality` (the campaign's own preferred
  home), inserted between the existing "Inline Result Quotes" and "Watermark Backdrop"
  sections in `DexterPersonalityPage.swift`.
- **Clean adoption**: Yes — `DexDexterFeedView` only requires `settings: AppSettings` and
  `profileManager: ProfileManager`, both already `@ObservedObject`/available on this page.
  Sources its lines from the existing `FlavorQuotePacks` infrastructure (not a forbidden
  file); zero edits to `DexDexterFeedView.swift`, `ProfileManager.swift`, or
  `FlavorQuotePacks.swift`.
- **Quote/feed behavior preserved**: identical shuffle logic (3 lines from the active
  profile's pack, up to 2 from other packs, combined and reshuffled) — the view was
  re-hosted verbatim, no logic changes.
- **Remains missing**: No — resolved.

## Forbidden files avoided (all three items)

`Sources/DexDictateKit/Profiles/ProfileManager.swift`, `Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift`,
`Sources/DexDictate/FlavorTickerView.swift`, and `Sources/DexDictateKit/TranscriptionEngine.swift`
were all read-only inspected and zero-line-diff confirmed via `git diff --stat`. No file
under `Sources/DexDictate/ExperimentalUI/` was touched.

## Summary

| Missing item | Status |
|---|---|
| Pinned "daily six" compact controls | **Resolved** — adopted into `PopoverRootView` |
| Live transcript + mic level meter | **Resolved** — adopted into `PopoverRootView`, listening-only |
| Dexter Feed browser | **Resolved** — adopted into `DexterPersonalityPage` |

**Experimental UI still functional: Yes** — zero files under `ExperimentalUI/` were
modified; the experimental surfaces (`useExperimentalStateFirstUI`, `useExperimentalNanoHUD`,
`useExperimentalCommandPalette`, `useExperimentalDexterFeed`) remain exactly as they were,
fully intact and independently toggleable from Settings → Advanced.

**Packet 12B readiness: Ready** — all three MISSING items from Packet 12A's inventory are
now resolved with standard-UI homes. Nothing blocks Packet 12B on the "does every
experimental capability have a standard home" question. (Packet 12B itself is still gated
and requires the separate readiness confirmation this document provides before it may run
in this same campaign.)
