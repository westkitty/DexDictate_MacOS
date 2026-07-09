# Experimental UI Adoption Inventory (Packet 12A)

Every experimental capability found by reading all nine files in `Sources/DexDictate/ExperimentalUI/`
(`DexStateFirstPopoverView.swift`, `DexStateFirstComponents.swift`, `DexCommandPaletteView.swift`,
`DexNanoHUDView.swift`, `DexDexterFeedView.swift`, `DexExperimentalEntry.swift`,
`DexExperimentalHubViews.swift`, `DexExperimentalUIStateAdapter.swift`, `DexLayeredRevealView.swift`),
plus `useExperimentalNanoHUD`'s production integration found in `FloatingHUD.swift`.

**Every MISSING row blocks Packet 12B** (gated, requires Andrew's separate explicit approval).

| Capability | Experimental file | Standard-UI home | Notes |
|---|---|---|---|
| State-first popover overall layout | `DexStateFirstPopoverView.swift` | **adopted** (Packet 09) | `PopoverRootView` is the standard-UI equivalent slim layout; not a 1:1 port, but the same "state-first" design goal — hero, result, history, status line, footer. |
| State hero (engine state readout) | `DexStateHero` in `DexStateFirstComponents.swift` | existing | `PopoverHeroView` (Packet 09) — same engine states, different visual treatment. |
| "Permissions OK" pill | `DexPermissionChips` in `DexStateFirstComponents.swift` | existing (implicit) | Standard popover shows an error banner only when something is missing (Packet 09's `errorBanner`); there's no positive "OK" chip when everything is granted — absence of a warning conveys the same information but not as an explicit affirmation. Cosmetic gap only. |
| Pinned "daily six" controls (trigger/model/mode compact pills + auto-paste/safe-mode/clipboard-fallback chips) | `DexContextChips` + `DexOutputChips` in `DexStateFirstComponents.swift` | **MISSING** as compact/pinned in the new default popover | Classic `AntiGravityMainView`'s `pinnedControlsStrip` (still in the codebase, non-default since Packet 09B) has an equivalent pinned strip. `PopoverRootView` (now default) has no compact inline pills for these — only full Settings pages (Dictation, Models & Accuracy, Output & Insertion). Not adopted this packet; flagging for Andrew. |
| Engine/trigger chips (interactive trigger + model pills) | `DexContextChips` | existing (full page, not compact) | Settings → Dictation (trigger/shortcut), Settings → Models & Accuracy (model) — same underlying storage keys and `ModelSelectionActions` calls, just not available as one-tap popover pills. |
| Live transcript + mic level meter while listening | `DexTranscriptCard` / `DexMicMeter` in `DexStateFirstComponents.swift` | **MISSING** | Found during this inventory, not part of the three suggested safe adoptions: `PopoverRootView`'s `PopoverHeroView`/`PopoverResultView` show engine state and the *last completed* result, but nothing live while `engine.state == .listening` — no live partial transcript, no mic level bar. The classic (now non-default) `HistoryView` and the experimental UI both have this. Not adopted this packet — deliberately not expanding scope beyond what was asked; flagging prominently for Andrew, likely worth a dedicated follow-up (Packet 15 or its own packet) rather than a rushed addition here. |
| Feedback badge (Pasted/Copied/etc.) | `DexFeedbackBadge` | existing | `PopoverResultView` (Packet 09) already shows this via `engine.resultFeedback`. |
| Nano HUD (compact floating HUD style) | `DexNanoHUDView.swift` | **existing — already adopted, pre-dates this packet** | Confirmed wired into production `FloatingHUD.swift` (`FloatingHUDController.show()`) via `useExperimentalNanoHUD`, with the toggle already in Settings → Advanced (Packet 08). This is a complete, working "option, not replacement" for the existing Floating HUD exactly as the plan of record describes — no new work needed. |
| Command Palette (⌘K) | `DexCommandPaletteView.swift` | **adopted this packet** | Re-hosted unchanged into `PopoverRootView` as a full-content screen-swap (same technique the experimental popover itself uses, to avoid sheet-triggered Dock bounce). Reachable via ⌘K (invisible keyboard-shortcut button) and a visible "Command Palette" item in the footer overflow menu. `onOpenFeatureHub`/`onOpenGUISwitcher` passed as `nil` — the view already renders those two specific commands as disabled with an explanatory subtitle, exactly as it's designed to handle a context lacking those screens. Zero edits to `DexCommandPaletteView.swift` itself. |
| Dexter Feed (stateful multi-line quote browser) | `DexDexterFeedView.swift` | **MISSING** | Only reachable via the experimental UI's Settings & History → Dexter layer, gated behind `useExperimentalDexterFeed`. Not one of the three suggested safe adoptions; not cleanly mappable to an existing standard-UI page without inventing new UI structure (it's a "shuffle 5 lines from all quote packs" browser, distinct from the single-line ticker/inline-quote). Flagging as MISSING rather than adopting speculatively. |
| Inline Dexter result quote | `DexterCommentaryLine` in `DexStateFirstComponents.swift` (used in `DexStateFirstPopoverView`'s main content) | **adopted this packet** | New toggle "Show quote inline with results" in Settings → Dexter & Personality (Packet 11 shipped this as a disabled placeholder pending this packet). New storage key `showInlineResultQuote` (default `false` — no prior standard-UI equivalent existed to preserve). When on, `PopoverResultView` shows `DexterCommentaryLine(text:)` beneath the transcript/badge/buttons, reading `profileManager.currentFlavorLine`. |
| "All Features" hub (wraps `QuickSettingsView`) | `DexExperimentalFeatureHubView` in `DexExperimentalHubViews.swift` | existing — superseded | The standalone Settings window (Packets 02–11) is the standard-UI equivalent; `QuickSettingsView` itself is still reachable (though now empty of active rows) from the classic, non-default popover. |
| "Switch UI" surface switcher | `DexExperimentalGUISwitcherView` in `DexExperimentalHubViews.swift` | existing | All four flags it toggles (`useExperimentalStateFirstUI`, `useExperimentalNanoHUD`, `useExperimentalCommandPalette`, `useExperimentalDexterFeed`) already live in Settings → Advanced (Packet 08). The classic popover's `UIModeToggleButton` (header) also still toggles `useExperimentalStateFirstUI` directly. |
| Live Transcription / Command Mode toggles | `DexRevealToggleRow` rows in `DexLayeredRevealView.swift`'s settings layer | existing | Settings → Models & Accuracy → Transcription Engines section (Packet 08B). |
| Auto-paste toggle | `DexLayeredRevealView.swift` settings layer | existing | Settings → Output & Insertion (Packet 05). |
| Safe Mode toggle | `DexLayeredRevealView.swift` settings layer | existing | Settings → Diagnostics & Recovery (Packet 08). Also in `PopoverRootView`'s footer overflow. |
| Reset Core Audio (+ postflight device validation) | `DexLayeredRevealView.swift`'s `advancedAudioRecoveryPanel` | existing | Settings → Diagnostics & Recovery → System Repair (Packet 08) — identical call sequence. |
| Show Floating HUD toggle | `DexLayeredRevealView.swift` settings layer | existing | Settings → General → Interface (Packet 08B). |
| Show Dexter commentary / Animate ticker toggles | `DexLayeredRevealView.swift`'s Dexter layer | existing | Settings → Dexter & Personality → Ticker (Packet 11). |
| Recent-transcriptions list + "Open Full History Window" | `DexLayeredRevealView.swift`'s history layer | existing | `PopoverHistoryTeaser` (Packet 09) + History window (pre-existing). |

## Summary

- **Adopted this packet**: Command Palette (⌘K), Inline Dexter result quote (new key `showInlineResultQuote`).
- **Already existing, pre-dating this packet**: Nano HUD (in production `FloatingHUD.swift`), all four experimental-flag toggles (Settings → Advanced), every setting duplicated in `DexLayeredRevealView`'s reveal panel, the "All Features" hub (superseded by the Settings window).
- **MISSING (blocks Packet 12B until resolved)**:
  1. Pinned "daily six" compact controls in the new default popover.
  2. Live transcript + mic level meter while actively listening, in the new default popover.
  3. Dexter Feed (stateful multi-line quote browser) — no standard-UI home at all.
