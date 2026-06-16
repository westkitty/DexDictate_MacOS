# Experimental UI: State-First Popover, Nano HUD, Layered Reveal

Branch: `experiment/state-first-popover-nano-hud-20260612-170821`

---

## What was built

Three feature-flagged experimental UI surfaces, layered on top of the existing production UI without modifying any engine code.

| Experiment | Flag | Default |
|---|---|---|
| State-first compact popover | `useExperimentalStateFirstUI` | `false` |
| Nano HUD | `useExperimentalNanoHUD` | `false` |
| Command Palette | `useExperimentalCommandPalette` | `false` |
| Dexter Stateful Feed | `useExperimentalDexterFeed` | `false` |

All flags default to `false`. The production path is unchanged.

---

## How to enable

**In-app (recommended):** Open the popover → expand "Settings & History" → scroll to the "Experimental UI" disclosure card → toggle the desired flags.

**Via UserDefaults (shell):**

```bash
# State-first popover (replaces AntiGravityMainView)
defaults write com.westkitty.dexdictate.macos useExperimentalStateFirstUI -bool true

# Nano HUD (replaces FloatingHUDView)
defaults write com.westkitty.dexdictate.macos useExperimentalNanoHUD -bool true

# Command palette button in state-first popover
defaults write com.westkitty.dexdictate.macos useExperimentalCommandPalette -bool true

# Dexter stateful feed in Layered Reveal settings panel
defaults write com.westkitty.dexdictate.macos useExperimentalDexterFeed -bool true
```

Restart DexDictate after writing defaults from the shell.

## How to disable / rollback

```bash
defaults delete com.westkitty.dexdictate.macos useExperimentalStateFirstUI
defaults delete com.westkitty.dexdictate.macos useExperimentalNanoHUD
defaults delete com.westkitty.dexdictate.macos useExperimentalCommandPalette
defaults delete com.westkitty.dexdictate.macos useExperimentalDexterFeed
```

Or toggle the flags back off in the Experimental UI card.

The original surfaces (`AntiGravityMainView`, `FloatingHUDView`, `QuickSettingsView`) remain in place. No files were deleted.

---

## Files changed

### Modified (existing production files)

| File | What changed |
|---|---|
| `Sources/DexDictateKit/Settings/AppSettings.swift` | Added four `@AppStorage` experiment flags |
| `Sources/DexDictate/DexDictateApp.swift` | MenuBarExtra routes to `DexExperimentalEntry` when state-first flag is on; `onChange` triggers HUD `refresh()` when Nano HUD flag changes |
| `Sources/DexDictate/FloatingHUD.swift` | `show()` checks Nano HUD flag and routes to correct view; added `refresh()` method |
| `Sources/DexDictate/QuickSettingsView.swift` | "Experimental UI" disclosure card with all four toggles |

### Created (experimental UI — app target)

| File | Purpose |
|---|---|
| `Sources/DexDictate/ExperimentalUI/DexExperimentalEntry.swift` | Container; creates adapter via `@StateObject` factory init |
| `Sources/DexDictate/ExperimentalUI/DexExperimentalUIStateAdapter.swift` | Adapter: subscribes to production services, produces `DexExperimentalUIState` |
| `Sources/DexDictate/ExperimentalUI/DexStateFirstPopoverView.swift` | State-first compact popover (320×480pt) |
| `Sources/DexDictate/ExperimentalUI/DexStateFirstComponents.swift` | Sub-components: state hero, permission chips, output chips, transcript card, mic meter, feedback badge, Dexter line |
| `Sources/DexDictate/ExperimentalUI/DexNanoHUDView.swift` | Minimal floating HUD strip |
| `Sources/DexDictate/ExperimentalUI/DexLayeredRevealView.swift` | In-popover panel with History, Settings, and Dexter layers; header has All Features + Switch UI buttons |
| `Sources/DexDictate/ExperimentalUI/DexCommandPaletteView.swift` | Searchable command palette (14 commands including Open All Features, Switch UI Surface, Quit) |
| `Sources/DexDictate/ExperimentalUI/DexExperimentalHubViews.swift` | DexExperimentalFeatureHubView (wraps full QuickSettingsView) + DexExperimentalGUISwitcherView |
| `Sources/DexDictate/ExperimentalUI/DexDexterFeedView.swift` | Dexter stateful feed (local quote packs, no network) |

### Created (kit — testable)

| File | Purpose |
|---|---|
| `Sources/DexDictateKit/ExperimentalUI/DexExperimentalUIState.swift` | Pure value types (`EngineDisplayState`, `PermissionDisplayState`, `OutputDisplayState`, `TranscriptDisplayState`, `DexterLineDisplayState`, `DexExperimentalUIState`) |

### Created (tests)

| File | Purpose |
|---|---|
| `Tests/DexDictateTests/DexExperimentalUITests.swift` | 24 tests across 5 suites covering state type logic, permission chips, adapter contracts, and Dexter feed sampling |

---

## Validation commands

```bash
swift build          # must complete with no errors
swift test           # must pass 264 tests, 0 failures
```

---

## Architecture notes

### Adapter pattern

`DexExperimentalUIStateAdapter` is the single crossing point between production services and experimental views. Views observe only the adapter, not `TranscriptionEngine`, `PermissionManager`, etc. directly. This keeps the experimental surface isolated and easy to remove.

### Flag routing in DexDictateApp

The `MenuBarExtra` content wraps in `Group { if/else }` so all `.onAppear` / `.onChange` / `.onReceive` handlers fire regardless of which branch is shown. The `guard engine.state == .stopped` check in the initialisation handler prevents double-initialisation.

### HUD refresh

When `useExperimentalNanoHUD` changes while the HUD is open, `FloatingHUDController.refresh()` closes and re-opens the window, picking up the new view type. If the HUD is not open, the change takes effect on the next `show()` call.

### Stop vs cancel in Nano HUD

There is no true "discard recording" path in the engine. The Nano HUD stop button calls `engine.toggleListening()`, which stops recording and proceeds to transcription. This is intentional and documented inline. A future discard path would require an engine-level change out of scope for this experiment.

### Safe Mode binding

`settings.safeModeEnabled` cannot be set directly — it requires `enableSafeMode()` / `disableSafeMode()`. The Layered Reveal settings layer uses an inline `Binding<Bool>` that calls these methods, mirroring the same pattern in `QuickSettingsView`.

---

## Known limitations

- The command palette has no global hotkey. `⌘K` is displayed as a hint but is not wired — doing so would require modifying `InputMonitor`, which is out of scope for this experiment.
- The Nano HUD stop button proceeds to transcription; it does not discard the audio. No public `discardCurrentRecording()` engine method exists.
- The watermark image in the state-first popover uses a best-effort asset lookup and silently omits the image if not found in the bundle.
- The layered reveal history layer shows up to 12 recent items inline; the full history remains in the detached `HistoryWindow`.
- The Nano HUD hub panel does not embed `DexExperimentalGUISwitcherView`. Switching the UI surface from the Nano HUD requires: hub button → Back → open menu bar popover → Switch UI. This is a two-hop path and is acceptable because Nano HUD is an add-on surface.

---

## Manual QA checklist

Work through `docs/09_QA/DICTATION_FLOW_TESTS.md` and `FAILURE_STATE_TESTS.md` with each flag enabled.

**State-first popover (critical path)**
- [ ] Idle: state hero shows "Off", no fake activity
- [ ] Ready: model label visible, trigger label visible
- [ ] Listening: waveform icon, mic meter animates, stop not shown (trigger-based)
- [ ] Transcribing: "Transcribing" hero, no dashboard interruption
- [ ] Inserted: feedback badge shows success outcome
- [ ] Clipboard fallback: badge shows clipboard icon + explicit "Copied only" text
- [ ] Insertion failed: feedback badge shows failure tone
- [ ] Secure field: badge shows `copiedOnlySensitiveContext` reason text
- [ ] Mic permission missing: chip shows "Microphone" in red, tap opens System Settings
- [ ] Accessibility permission missing: chip shown, fix action visible
- [ ] Input Monitoring missing: chip shown, fix action visible
- [ ] Model missing/loading: `initializing` or `error` state shown in hero
- [ ] Reduced Motion: no pulsing animations, transitions use `.opacity` only
- [ ] Safe Mode: output chips show safe mode indicator

**Nano HUD**
- [ ] Appears floating above other windows without stealing focus
- [ ] Shows correct state label and icon during listening and transcribing
- [ ] Stop button visible only during listening; tap stops and proceeds to transcription
- [ ] Sliders icon (`slider.horizontal.3`) is ALWAYS visible — HUD is not a dead-end surface
- [ ] Tapping sliders icon opens a non-activating hub panel with full Feature Hub / QuickSettings
- [ ] Hub panel Back button closes the panel without disturbing the HUD
- [ ] Disappears after engine stops
- [ ] Does not appear when flag is off

**Layered Reveal**
- [ ] History layer shows recent items; "Open Full History" button opens detached window
- [ ] Settings layer: auto-paste, safe mode, floating HUD toggles persist across launches
- [ ] Dexter layer: Dexter feed loads lines when flag is on; toggle stays quiet when off
- [ ] Header shows grid icon (All Features) and switch icon (Switch UI) — both functional
- [ ] Escape key or Back button returns to main popover (no separate window dismissal)

**Accessibility**
- [ ] All buttons have accessibility labels
- [ ] State hero text is readable by VoiceOver
- [ ] No icon-only failure states (every error has text + icon + recovery action)

---

## Future work

- Wire `⌘K` to command palette once a safe global shortcut path exists
- Add transition animations to state hero respecting Reduced Motion
- Expand Nano HUD to show insertion outcome briefly before hiding
- Add per-app destination chip to context chips row
- Promote `DexExperimentalUIState` value types to a stable API once patterns are validated

---

> **Hard constraint reminder:** This experiment must never modify audio capture, Whisper transcription, output insertion, clipboard fallback, permission checking, model loading, history persistence, entitlements, or packaging. If a future change requires touching those layers, it belongs in a separate branch and PR.

---

## Manual QA correction pass — 2026-06-12

Andrew ran manual QA after the initial experimental UI implementation. The branch was buildable but not product-ready. The following corrections were made in the correction pass:

### Architecture fix — Dock bounce eliminated

`.sheet` presentations from the state-first popover caused `NSApp.activate()` which bounced the Dock. All sub-panels (Settings & History, Command Palette, Feature Hub, GUI Switcher) are now embedded as in-popover states via `ExperimentalScreen` enum state machine. No `.sheet` is used from any experimental surface.

### New: ExperimentalScreen state machine (DexStateFirstPopoverView)

```swift
enum ExperimentalScreen: Equatable {
    case main, settingsAndHistory, commandPalette, featureHub, guiSwitcher
}
```

Screen state drives what fills the 320×480 popover. Each non-main screen uses an opaque dark overlay so the watermark stays hidden behind settings content.

### New: All Features hub (DexExperimentalFeatureHubView)

Wraps `QuickSettingsView` with a back button, quit button, and quick-access chips for History and Help. Every production DexDictate feature is accessible without switching to Standard UI. The hub owns scanner / benchmark controller `@StateObject`s to avoid threading them through the parent chain.

### New: GUI Switcher (DexExperimentalGUISwitcherView)

In-popover surface selector. No shell `defaults write` commands needed. Shows:
- Main Popover Surface: Standard UI vs State-first (radio-style)
- Add-on surfaces: Nano HUD, Command Palette, Dexter Feed (toggles)

### New: Quit button in title bar

Always-visible power button in the top-left of the title bar. Never hidden behind settings.

### profileManager now threaded to popover

`DexExperimentalEntry` now passes `profileManager` to `DexStateFirstPopoverView`, which threads it to `DexLayeredRevealView` and the feature hub. Required for the Dexter Feed profile preference fix.

### Dexter feed profile preference

`DexDexterFeedView` now accepts `profileManager` and prioritises lines from `profileManager.activeProfile` (3 lines) over other profiles (2 lines from the rest), shuffled within each pool.

### HelpView: Experimental UI section added

New `.experimentalUI` case in `HelpSection` enum. Content covers all surfaces, flags, GUI switcher usage, and shell `defaults delete` commands for manual reset.

### Files modified in correction pass

- `DexStateFirstPopoverView.swift` — full rewrite with ExperimentalScreen
- `DexLayeredRevealView.swift` — add onBack, remove .sheet frame/background, profileManager
- `DexCommandPaletteView.swift` — add onBack, remove .sheet frame/background
- `DexExperimentalEntry.swift` — pass profileManager
- `DexDexterFeedView.swift` — add profileManager, profile-aware loadLines()
- `HelpView.swift` — add .experimentalUI section
- `DexExperimentalHubViews.swift` — new file (DexExperimentalFeatureHubView + DexExperimentalGUISwitcherView)

### Validation

`swift build` — clean (0 errors, 0 warnings)  
`swift test` — 264 tests, 0 failures
