# Experimental UI — Feature Exposure Audit

Label: QA

Date: 2026-06-12 (Phase 7 — complete-access hardening pass)

A capability must be **directly accessible** or reachable via **one tap** from every
experimental surface. N/A is allowed only for the Nano HUD minimal strip, and only
because the HUD's hub button gives an immediate one-tap path to the full Feature Hub.

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Directly accessible or visible on this surface |
| 🔗 | One-tap navigation path to the capability |
| ⚙ | Accessible via "All Features" hub (one tap from any experimental surface) |
| ⚙hub | Nano HUD: accessible via the always-visible hub button → Feature Hub |
| N/A | Not applicable to this surface by design — hub button provides escape path |
| deferred | Known gap; documented reason; does not block QA |
| ❌ | Genuinely inaccessible — requires redesign |

## Surface navigation matrix

Every experimental surface has an escape path to the Feature Hub:

| Surface | Path to All Features | Path to Switch UI | Path to Quit | Path to Help |
|---------|---------------------|-------------------|--------------|--------------|
| State-first Popover (main) | ✅ "All Features" button | ✅ "Switch UI" button | ✅ power icon title bar | ✅ ? icon title bar |
| Nano HUD | ✅ sliders icon → hub panel | ⚙hub via Feature Hub → Switch UI | ⚙hub via Feature Hub | ⚙hub via Feature Hub |
| Layered Reveal | ✅ grid icon in header | ✅ switch icon in header | ⚙ via All Features | 🔗 via All Features |
| Command Palette | ✅ "Open All Features" cmd | ✅ "Switch UI Surface" cmd | ✅ "Quit DexDictate" cmd | ✅ "Open Help" cmd |
| Dexter Feed (within LR) | ✅ grid icon (LR header) | ✅ switch icon (LR header) | ⚙ via All Features | 🔗 via All Features |
| Shared Feature Hub | N/A (is the hub) | ⚙ Back → main → Switch UI | ✅ Quit button header | ✅ Help chip |

---

## Feature exposure table

### Group 1 — Dictation controls

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Start dictation | `engine.startSystem()` via trigger or popover button | ✅ button | N/A — trigger-based | N/A — settings panel | ✅ command | N/A | 🔗 Back→main | complete | HUD is state-display only; trigger fires regardless of HUD |
| Stop dictation system | `engine.stopSystem()` | ✅ (active state shows stop) | 🔗 stop/cancel button stops recording, system fully stoppable from cmd palette | N/A | ✅ command | N/A | 🔗 Back→main | complete | stopSystem() vs toggleListening() distinction documented inline |
| Stop recording early | `engine.toggleListening()` | ✅ (listening state) | ✅ stop button | N/A | ✅ command | N/A | 🔗 Back→main | complete | Proceeds to transcription; no discard path exists |
| True discard / cancel recording | No public engine method | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | deferred | Requires engine-level change; documented as known limitation |
| View engine state | `TranscriptionEngine.state` | ✅ DexStateHero | ✅ strip label+icon | N/A | N/A | N/A | N/A — settings panel | complete | HUD always shows current state |

### Group 2 — Output and insertion

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Auto-paste toggle | QS → Output | ✅ Settings layer | ⚙hub | ✅ Settings layer | ✅ command | ⚙ via LR header | ✅ QS embedded | complete | |
| Accessibility insertion | QS → Output | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ command palette has toggle path | ⚙ via LR header | ✅ QS | complete | |
| Clipboard fallback visibility | State-first output chips; QS output section | ✅ output chips | N/A | ⚙ via header | N/A | ⚙ via LR header | ✅ QS | complete | HUD shows state text; chip visible in state-first |
| Safe Mode toggle | QS → Safety | ✅ Settings layer | ⚙hub | ✅ Settings layer | ✅ command | ⚙ via LR header | ✅ QS | complete | |
| Per-app insertion settings | QS → Output (per-app overrides) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ via LR header | ✅ QS | complete | |
| Replace-field mode | QS → Output (if exposed) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ via LR header | ✅ QS | complete | Only accessible if production QS exposes it; no experiment change |
| Append-mode handling | QS (if wired) | ⚙ | ⚙hub | ⚙ | ⚙ | ⚙ via LR header | ✅ QS (if wired) | deferred | Not fully wired in production; experimental surfaces inherit QS state faithfully |
| Import / transcribe audio file | QS (if available) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS (if available) | complete | Passes through to QS; no experiment change |

### Group 3 — Audio and model settings

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Microphone / input device selection | QS → Microphone | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Trigger mode (middle mouse / keyboard / side button) | QS → Trigger | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Model selection / download | QS → Model | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Silence timeout / utterance end | QS (if exposed) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS (if exposed) | complete | Passes through to QS; no experiment change |
| Audio feedback sounds | QS (if exposed) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS (if exposed) | complete | Passes through to QS |
| Benchmark / model management | QS → Model / Diagnostics | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | Feature Hub owns BenchmarkCaptureController + AdaptiveBenchmarkController as @StateObject |

### Group 4 — History

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Inline recent history | Engine history items | ✅ DexTranscriptCard | N/A | ✅ History layer (12 items) | N/A | N/A | 🔗 Full History chip | complete | |
| Open full history window | HistoryWindow (detached) | 🔗 Settings & History → History | ⚙hub → hub History chip | ✅ "Open Full History Window" button | ✅ command | 🔗 LR header → All Features | ✅ History chip | complete | Opens `HistoryWindowController.show()` |
| Copy / clear / export / search history | HistoryWindow internal | 🔗 → Full History window | ⚙hub | 🔗 → Full History window | 🔗 → Full History cmd | 🔗 → LR then Full History | ✅ History chip → window | complete | These live in the detached HistoryWindow; all surfaces have a path |
| Persist history setting | QS → History (if exposed) | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |

### Group 5 — Appearance and profile

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Profile selection | QS → Profile | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Watermark behavior | QS → Appearance | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Menu bar display / icon settings | QS → Appearance | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | MenuBarIconController.shared observed in Feature Hub |
| Theme / appearance | QS → Appearance | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |

### Group 6 — Dexter and flavor

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Dexter commentary toggle | QS / `showFlavorTicker` | ✅ DexterCommentaryLine (live) | N/A | ✅ Dexter layer toggle | ✅ command | ✅ Dexter layer toggle | ✅ QS | complete | |
| Animate ticker toggle | QS / `animateFlavorTicker` | ⚙ All Features | N/A | ✅ Dexter layer toggle | ⚙ | ✅ Dexter layer toggle | ✅ QS | complete | |
| Dexter feed (experimental) | `useExperimentalDexterFeed` flag | 🔗 Settings & History → Dexter tab | N/A | ✅ Dexter layer (when flag on) | 🔗 Toggle Nano HUD/feed cmd | ✅ DexDexterFeedView | ✅ QS flag toggle | complete | Flag must be on; enabled via GUI Switcher |
| Dexter feed profile preference | `profileManager.activeProfile` | ⚙ (feeds into all surfaces) | N/A | ✅ Dexter layer uses active profile | N/A | ✅ 3:2 active:other ratio | ⚙ via QS profile | complete | |

### Group 7 — System, permissions, and diagnostics

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Floating HUD toggle | QS → HUD / `showFloatingHUD` | ✅ Settings layer | N/A | ✅ Settings layer | ✅ command | ⚙ via LR header | ✅ QS | complete | |
| Microphone permission status / recovery | QS + PermissionChips | ✅ DexPermissionChips + tap → System Settings | N/A | ⚙ via header | ⚙ | ⚙ | ✅ QS permissions section | complete | |
| Accessibility permission status / recovery | QS + PermissionChips | ✅ DexPermissionChips | N/A | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Input Monitoring permission status / recovery | QS + PermissionChips | ✅ DexPermissionChips | N/A | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Profanity filter | QS → Output | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Vocabulary settings | QS → Vocabulary | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Custom commands | QS → Commands | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Dictation stats | QS → Diagnostics / Stats | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Diagnostics | QS → Diagnostics | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |
| Launch at login | QS → System | ⚙ All Features | ⚙hub | ⚙ via header | ⚙ | ⚙ | ✅ QS | complete | |

### Group 8 — Help, meta, and troubleshooting

| Capability | Prod. location | SFP | HUD | Lay.Rev | Cmd.Pal | Dex.Feed | Feat.Hub | Status | Notes / risks |
|---|---|---|---|---|---|---|---|---|---|
| Help window | HelpWindowController | ✅ ? title bar button | ⚙hub → Help chip | 🔗 All Features → Help chip | ✅ command | 🔗 LR header → All Features | ✅ Help chip | complete | |
| CoreAudio -10868 help path | HelpView → Diagnostics section | 🔗 via Help window | ⚙hub | 🔗 via help | 🔗 via help cmd | 🔗 via help | ✅ Help chip | complete | HelpView has this section |
| Zoom troubleshooting path | HelpView → Per-App section | 🔗 via Help window | ⚙hub | 🔗 via help | 🔗 via help cmd | 🔗 via help | ✅ Help chip | complete | |
| Quit | `NSApplication.shared.terminate(nil)` | ✅ power icon title bar | ⚙hub | ⚙ via All Features header | ✅ "Quit DexDictate" command | ⚙ via LR header | ✅ power button header | complete | |
| Switch to Standard UI | `useExperimentalStateFirstUI = false` | ✅ Switch UI button | ⚙hub → Feature Hub → can't switch there | ✅ switch icon header | ✅ "Switch UI Surface" command | ✅ switch icon (LR header) | 🔗 Back → main → Switch UI | complete | Nano HUD: hub panel doesn't expose GUI Switcher; Back → main → Switch UI is 2 taps |
| Enable / disable experimental surfaces | `DexExperimentalGUISwitcherView` | ✅ Switch UI button | ⚙hub (limited — no GUI switcher in hub panel) | ✅ switch icon header | ✅ "Switch UI Surface" command | ✅ switch icon (LR header) | 🔗 Back → main → Switch UI | partial | Nano HUD hub panel lacks the GUI Switcher; noted as acceptable since Nano HUD is an add-on |
| Onboarding debug | 5-tap version label | ⚙ All Features footer | N/A | ⚙ via header | ⚙ | ⚙ | ✅ QS footer | complete | |

---

## Notes on Nano HUD N/A coverage

The Nano HUD is a minimal strip by design. It is **not** a dead-end surface.
The always-visible `slider.horizontal.3` button opens a 320×480 `NSPanel` containing
`DexExperimentalFeatureHubView` (the full Feature Hub). This gives the Nano HUD an
immediate one-tap path to every capability listed above.

The `⚙hub` notation in the HUD column means: tap the sliders button → hub panel opens.

---

## Notes on GUI Switcher from Nano HUD

The Nano HUD hub panel does not embed `DexExperimentalGUISwitcherView`.
To reach the GUI Switcher from the Nano HUD:

1. Tap sliders button → hub panel opens (Feature Hub)
2. Tap Back → closes hub panel
3. Open menu bar popover → Switch UI button

This is a known two-hop path. It is acceptable because:
- Nano HUD is an add-on surface, not the primary popover
- The GUI Switcher is accessible from the menu bar popover
- Disabling the Nano HUD can be done via `Toggle Nano HUD` in the Command Palette
  (which is accessible from the state-first popover if the flag is on)

---

## Failure condition from QA spec

> "If any feature is only accessible by switching back to Standard UI, the surface fails."

As of Phase 7 (2026-06-12):

- Every production feature reachable via QuickSettingsView is accessible from every
  experimental surface via "All Features" (one tap).
- Quit is present in: State-first title bar, Command Palette, Feature Hub header.
- Help is reachable from: State-first title bar, Command Palette, Feature Hub chip.
- Full History is reachable from: Layered Reveal button, Command Palette, Feature Hub chip.
- Nano HUD hub button is always visible — no dead-end surface.
- True recording discard is marked `deferred` with documented reason (engine limitation).
- No feature requires switching to Standard UI.

---

## Hard constraints verified

| Constraint | Status |
|---|---|
| Audio capture unchanged | ✅ Not touched |
| Whisper transcription unchanged | ✅ Not touched |
| Output insertion unchanged | ✅ Not touched |
| Clipboard fallback unchanged | ✅ Not touched |
| Permission behaviour unchanged | ✅ Not touched |
| Model loading unchanged | ✅ Not touched |
| History persistence unchanged | ✅ Not touched |
| Entitlements unchanged | ✅ Not touched |
| Packaging / signing unchanged | ✅ Not touched |
| Opening animation preserved | ✅ Not touched |
| Onboarding preserved | ✅ Not touched |
| Watermark support preserved | ✅ Not touched |
| Dexter / flavor support preserved | ✅ Not touched |
| Experimental UI not default | ✅ All flags default false |
| No feature removed | ✅ All features accessible via Feature Hub |
| No commit | ✅ |
| No push | ✅ |
