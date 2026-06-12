# Experimental UI — Manual QA Runbook

Branch: `experiment/state-first-popover-nano-hud-20260612-170821`

Bundle ID: `com.westkitty.dexdictate.macos`

---

## 1. Build and install

```bash
# From repo root — builds release, codesigns, and installs to ~/Applications
cd ~/DexDictate_MacOS.nosync
./build.sh --user
```

Expected output ends with: `Open with: open "$HOME/Applications/DexDictate.app"`

If build.sh is not executable:
```bash
chmod +x build.sh && ./build.sh --user
```

---

## 2. Enable flags and launch

Always **quit DexDictate before writing flags**, then relaunch. Flags are read at launch
time for the popover; the HUD flag is also read when you enable "Show Floating HUD."

> **Note:** All flags are also toggleable in-app from the state-first popover.
> Use "Switch UI" on the main screen to reach `DexExperimentalGUISwitcherView`.
> Shell commands below are provided for clean-slate testing only.

### Enable all experimental flags
```bash
pkill -x DexDictate 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalStateFirstUI -bool true
defaults write com.westkitty.dexdictate.macos useExperimentalNanoHUD -bool true
defaults write com.westkitty.dexdictate.macos useExperimentalCommandPalette -bool true
defaults write com.westkitty.dexdictate.macos useExperimentalDexterFeed -bool true
open ~/Applications/DexDictate.app
```

### Enable state-first popover only
```bash
pkill -x DexDictate 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalStateFirstUI -bool true
defaults delete com.westkitty.dexdictate.macos useExperimentalNanoHUD 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalCommandPalette 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalDexterFeed 2>/dev/null; true
open ~/Applications/DexDictate.app
```

### Enable state-first popover + command palette
```bash
pkill -x DexDictate 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalStateFirstUI -bool true
defaults write com.westkitty.dexdictate.macos useExperimentalCommandPalette -bool true
defaults delete com.westkitty.dexdictate.macos useExperimentalNanoHUD 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalDexterFeed 2>/dev/null; true
open ~/Applications/DexDictate.app
```

### Enable Nano HUD only
```bash
pkill -x DexDictate 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalStateFirstUI 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalNanoHUD -bool true
defaults delete com.westkitty.dexdictate.macos useExperimentalCommandPalette 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalDexterFeed 2>/dev/null; true
open ~/Applications/DexDictate.app
# After launch: open standard popover → Quick Settings → Show Floating HUD → ON
```

### Enable Dexter feed only (requires state-first popover to view)
```bash
pkill -x DexDictate 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalStateFirstUI -bool true
defaults delete com.westkitty.dexdictate.macos useExperimentalNanoHUD 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalCommandPalette 2>/dev/null; true
defaults write com.westkitty.dexdictate.macos useExperimentalDexterFeed -bool true
open ~/Applications/DexDictate.app
# After launch: state-first popover → Settings & History → Dexter tab
```

### Reset to production UI (disable all flags)
```bash
pkill -x DexDictate 2>/dev/null; true
defaults delete com.westkitty.dexdictate.macos useExperimentalStateFirstUI
defaults delete com.westkitty.dexdictate.macos useExperimentalNanoHUD
defaults delete com.westkitty.dexdictate.macos useExperimentalCommandPalette
defaults delete com.westkitty.dexdictate.macos useExperimentalDexterFeed
open ~/Applications/DexDictate.app
```

---

## 3. What to check

### A — State-first popover (requires `useExperimentalStateFirstUI = true`)

Click the menu bar DexDictate icon. The compact state-first popover appears in-place —
no separate window, no Dock bounce.

**Idle state**
- [ ] State hero shows "Off" with `mic.slash` icon
- [ ] No fake recording indicator, no spinner
- [ ] Trigger chip shows configured trigger (e.g. "Middle Mouse")
- [ ] Model chip shows active model ID (e.g. "tiny.en")
- [ ] "Settings & History" row visible at bottom
- [ ] "All Features" row visible below Settings & History
- [ ] "Switch UI" row visible at bottom
- [ ] "Commands" row visible if `useExperimentalCommandPalette` is on
- [ ] Power icon (top-left title bar) is always visible — never hidden
- [ ] Help icon (top-right title bar, `?`) is visible
- [ ] Experiment badge at very bottom: "Experimental UI · Switch UI to return to standard"

**Start dictation**
- [ ] "Start Dictation" button is visible when engine is stopped
- [ ] Tapping it transitions hero to "Starting…" then "Ready" then listens when trigger activated
- [ ] During listening: hero shows "Listening", waveform icon, mic meter animates in transcript card
- [ ] During transcribing: hero shows "Transcribing", brain icon

**After dictation**
- [ ] Feedback badge appears with outcome (e.g. "Pasted into active app" or "Copied only instead of pasting")
- [ ] Recent transcript visible in transcript card

**Clipboard fallback state** (test in a password field or secure input)
- [ ] Feedback badge shows "Copied only instead of pasting" or similar
- [ ] Output chips show "Secure field — copied" chip in orange
- [ ] Does NOT say only "Dexter says…" — the chip must be visible regardless of Dexter

**Permission chips**
- [ ] If all permissions granted: single green "Permissions OK" chip
- [ ] If a permission is missing: individual orange chip per missing permission with label
- [ ] "Open System Settings →" link is tappable and opens System Settings

**Dexter commentary line**
- [ ] Appears as italic quoted text at bottom (if `showFlavorTicker` is on)
- [ ] Can be muted via Settings & History → Dexter → "Show Dexter commentary" toggle
- [ ] Muting also mutes commentary in the standard popover (shared setting)
- [ ] Dexter commentary does NOT appear during active dictation (it's static, not animated)

**Reduced Motion** (enable in System Settings → Accessibility → Motion)
- [ ] State hero icon has no pulse animation
- [ ] Mic meter has no animation

---

### B — Settings & History (accessed from state-first popover, in-popover)

Tap "Settings & History" row. The panel loads inside the popover — no separate window
opens, no Dock bounce.

**Transition**
- [ ] Content replaces the main screen within the same 320×480 frame
- [ ] Header shows: Back (chevron.left) | "Settings & History" | grid icon + switch icon

**Header buttons (always visible)**
- [ ] Back button (chevron.left "Back") returns to main popover — Escape key also works
- [ ] Grid icon (square.grid.2x2) opens All Features in-popover
- [ ] Switch icon (switch.2) opens GUI Switcher in-popover

**History layer**
- [ ] Shows recent transcriptions (up to 12)
- [ ] "No transcriptions yet" shown when history is empty
- [ ] "Open Full History Window" button opens the detached history window (no Dock bounce)

**Settings layer**
- [ ] Auto-paste toggle works and persists across app restarts
- [ ] Safe Mode toggle works (confirm chip appears in output chips area when returning to main)
- [ ] Show Floating HUD toggle works (HUD appears/disappears)
- [ ] Footer note references "Full settings available in Quick Settings" — does not block access

**Dexter layer** (requires `useExperimentalDexterFeed = true`)
- [ ] "Show Dexter commentary" and "Animate ticker" toggles are visible
- [ ] When Dexter feed flag is on: "Dexter Feed (Experimental)" section visible with ~5 quotes
- [ ] "Shuffle lines" button loads new quotes
- [ ] Quotes from active profile appear more often than others (verify with a distinct profile active)
- [ ] When flag is off: placeholder text explains how to enable via GUI Switcher
- [ ] "Source: [pack name]" label shown under each quote line

**Navigation**
- [ ] Escape key returns to main popover (not to OS or separate window)
- [ ] Back button returns to main popover
- [ ] No `.sheet` detachment — focus never leaves the menu bar popover

---

### C — Command Palette (requires `useExperimentalStateFirstUI` + `useExperimentalCommandPalette`)

"Commands" button appears below "Settings & History" in the popover. Shows magnifying glass + "⌘K" hint.

**Opening**
- [ ] Tapping "Commands" loads the palette inside the popover — no separate window, no Dock bounce
- [ ] Header shows: Back (chevron.left) | "Command Palette" | spacer
- [ ] Search field auto-focuses on open
- [ ] Escape key and Back button both return to main popover

**Command discovery**
- [ ] Typing filters commands (try: "safe", "stop", "history", "feature", "quit")
- [ ] Empty state shown for unmatched search
- [ ] Disabled commands show in muted style with `−` indicator and explanatory subtitle
- [ ] Enabled commands execute on tap and return to the appropriate surface

**Required commands — confirm all are present and wired**
- [ ] "Start Dictation" — enabled when engine stopped; disabled when running
- [ ] "Stop Dictation System" — enabled when running; disabled when stopped
- [ ] "Stop Recording Early" — enabled only during listening
- [ ] "Toggle Safe Mode" — subtitle reflects current state; tap toggles it
- [ ] "Toggle Auto-paste" — subtitle reflects current state
- [ ] "Toggle Dexter Commentary" — subtitle reflects current state
- [ ] "Toggle Floating HUD" — enabled, reflects showFloatingHUD
- [ ] "Toggle Nano HUD" — enabled, reflects useExperimentalNanoHUD
- [ ] "Open Full History" — opens HistoryWindow and returns to popover
- [ ] "Open Help" — opens Help window
- [ ] "Open All Features" — loads Feature Hub in-popover
- [ ] "Switch UI Surface" — loads GUI Switcher in-popover
- [ ] "Quit DexDictate" — terminates app

**Enter key**
- [ ] Enter runs the first enabled matching command in filtered results

---

### D — Nano HUD (requires `useExperimentalNanoHUD = true` + Floating HUD enabled)

To test: enable flag → launch → open popover → Quick Settings → enable "Show Floating HUD."

**Basic behavior**
- [ ] Small strip appears floating, not in the Dock or menu bar
- [ ] Does NOT steal focus from active app
- [ ] Can be repositioned by dragging
- [ ] Shows correct state label ("Listening", "Transcribing", "Off", "Ready")
- [ ] During listening: red waveform icon pulses (or shows static if Reduce Motion on), mic meter visible, stop button (⏹) shows
- [ ] Tapping stop button proceeds to transcription (not discard — intentional)
- [ ] During transcribing: yellow brain icon, live transcript or "Processing…" text
- [ ] After completion: returns to "Ready" or "Off"

**Hub button (critical — must not be a dead-end)**
- [ ] Sliders icon (`slider.horizontal.3`) is ALWAYS visible — even when not recording
- [ ] Tapping it opens a 320×480 floating panel containing the full Feature Hub
- [ ] Feature Hub panel is non-activating (does not steal focus or bounce Dock)
- [ ] Feature Hub shows QuickSettings content, scrollable
- [ ] Feature Hub Back button closes the hub panel (returns to HUD-only state)
- [ ] History chip and Help chip in Feature Hub are functional
- [ ] Quit button in Feature Hub header terminates the app

**Switching HUD type while running**
- [ ] Disable Nano HUD flag while HUD is hidden → re-enable Show Floating HUD → standard HUD appears
- [ ] Enable Nano HUD flag while HUD is open → close and reopen HUD → Nano HUD appears

---

### E — All Features / Feature Hub (accessed from any surface)

Reached via: main popover "All Features" button, Layered Reveal grid icon, Command Palette "Open All Features" command, or Nano HUD hub button.

- [ ] Opens inside the popover (or as hub panel from Nano HUD) — no Dock bounce
- [ ] Header shows: Back | "All Features" | Quit
- [ ] History and Help chips are shown and functional below the header
- [ ] QuickSettingsView content is visible and scrollable
- [ ] All QuickSettings panels are accessible (trigger, microphone, model, output, appearance, diagnostics, etc.)
- [ ] Toggles within QuickSettings take effect immediately
- [ ] Back button returns to the calling surface (main popover, or closes the hub panel from HUD)
- [ ] Quit button terminates the app

---

### F — GUI Switcher (accessed from main popover or any header)

Reached via: main popover "Switch UI" button, Layered Reveal switch icon, Command Palette "Switch UI Surface" command.

- [ ] Opens inside the popover — no Dock bounce
- [ ] Header shows: Back | "Switch UI Surface" | spacer
- [ ] "Standard UI" and "State-first Popover" radio rows visible
- [ ] Selecting "Standard UI": `useExperimentalStateFirstUI = false`, closes to standard popover
- [ ] Selecting "State-first Popover" (already active): checkmark shown, no navigation
- [ ] Add-on toggles: Nano HUD, Command Palette, Dexter Feed toggles all visible and functional
- [ ] Changes take effect immediately (no restart required for popover flag; HUD refresh on next open)
- [ ] Escape key and Back button return to calling surface

---

### G — In-app flag toggles (smoke test of Quick Settings path)

- [ ] Open standard popover (disable `useExperimentalStateFirstUI` first if needed)
- [ ] Open Quick Settings → scroll to "Experimental UI" panel → expand it
- [ ] All 4 toggles visible with labels and explanation text
- [ ] Toggling "State-first compact popover" immediately switches popover on next open
- [ ] Toggling "Nano HUD" takes effect when HUD is next created

---

### H — Production path regression check

With all flags disabled (reset command above):

- [ ] Menu bar popover shows standard `AntiGravityMainView`
- [ ] All dictation functions work normally
- [ ] HUD shows standard `FloatingHUDView`
- [ ] Quick Settings shows all panels intact — Experimental UI panel is present but all flags default off
- [ ] No crash, no blank view, no Dock bounce in standard mode

---

## 4. Every GUI option complete-access check

For each surface, follow the steps below and confirm the feature path works.

### State-first Popover

| Goal | Steps | Pass criteria |
|------|-------|---------------|
| All Features / Quick Settings | Main → tap "All Features" | QuickSettings panel opens in-popover |
| Switch UI | Main → tap "Switch UI" | GUI Switcher opens in-popover |
| Help | Main → tap ? in title bar | Help window opens (detached, no Dock bounce) |
| Quit | Main → tap power icon in title bar | App terminates |
| Full History | Main → Settings & History → History tab → Open Full History Window | HistoryWindow opens detached |
| Quick Settings controls (e.g. Safe Mode) | Main → All Features → QS Safe Mode toggle | Toggle works |
| Dictation Start | Main → Start Dictation button | Dictation starts |
| Command Palette (if flag on) | Main → tap Commands row | Palette opens in-popover |

### Nano HUD

| Goal | Steps | Pass criteria |
|------|-------|---------------|
| All Features / Quick Settings | HUD → tap sliders icon | Hub panel opens (non-activating), QS visible |
| Help | HUD → sliders → Help chip | Help window opens |
| Quit | HUD → sliders → Quit button | App terminates |
| Full History | HUD → sliders → History chip | HistoryWindow opens detached |
| Quick Settings controls | HUD → sliders → scroll to any QS toggle | Toggle works, change persists |
| Switch UI | HUD → sliders → Back → open menu bar popover → Switch UI | GUI Switcher opens |
| Stop recording | HUD → stop button (⏹) during listening | Transcription proceeds |

### Layered Reveal (Settings & History)

| Goal | Steps | Pass criteria |
|------|-------|---------------|
| All Features | Header → grid icon | Feature Hub opens in-popover |
| Switch UI | Header → switch icon | GUI Switcher opens in-popover |
| Help | Header → grid icon → Help chip | Help window opens |
| Quit | Header → grid icon → Quit button | App terminates |
| Full History | History tab → Open Full History Window | HistoryWindow opens detached |
| Quick Settings controls | Header → grid icon → QS | Full controls accessible |
| Back to main | Header → Back or Escape | Returns to state-first popover main |
| Safe Mode (direct) | Settings tab → Safe Mode toggle | Toggle works |
| Auto-paste (direct) | Settings tab → Auto-paste toggle | Toggle works |
| Dexter Feed (if flag on) | Dexter tab → feed lines visible | Lines load with active profile bias |

### Command Palette

| Goal | Steps | Pass criteria |
|------|-------|---------------|
| All Features | Search or scroll → "Open All Features" | Feature Hub opens in-popover |
| Switch UI | Search "switch" → "Switch UI Surface" | GUI Switcher opens in-popover |
| Help | Search "help" → "Open Help" | Help window opens |
| Quit | Search "quit" → "Quit DexDictate" | App terminates |
| Full History | Search "history" → "Open Full History" | HistoryWindow opens |
| Safe Mode | Search "safe" → "Toggle Safe Mode" | Toggles, subtitle updates |
| Dictation Start | Search "start" → "Start Dictation" | Dictation starts |
| Back to main | Back button or Escape | Returns to state-first popover main |

### Dexter Feed (within Settings & History → Dexter tab)

Dexter Feed is a sub-layer of Layered Reveal. Navigation comes from the Layered Reveal header.

| Goal | Steps | Pass criteria |
|------|-------|---------------|
| All Features | Dexter tab → grid icon in LR header | Feature Hub opens in-popover |
| Switch UI | Dexter tab → switch icon in LR header | GUI Switcher opens in-popover |
| Help | Dexter tab → LR header grid → Help chip | Help window opens |
| Quit | Dexter tab → LR header grid → Quit | App terminates |
| Toggle Dexter commentary | Dexter tab → "Show Dexter commentary" toggle | Setting persists |
| Shuffle lines | Dexter tab → "Shuffle lines" button | New quotes load with active profile bias |
| Back to main | Back button or Escape | Returns to state-first popover main |

---

## 5. Failure conditions — stop testing if any of these occur

| Symptom | Likely cause | Action |
|---|---|---|
| App crashes on launch | Build artifact is stale | Rebuild: `./build.sh --user` |
| Popover shows blank or crashes | Adapter or state type error | Check Console.app for crash report |
| Any sub-panel opens as a separate window (Settings, Commands, All Features, GUI Switcher) | `.sheet` regression | Stop — report as critical regression |
| Dock bounces when opening any experimental panel | NSApp.activate() triggered | Stop — report as critical regression |
| HUD sliders button does nothing | `onOpenHub` callback not wired | Stop and report |
| HUD hub panel opens but QS is blank | Feature Hub missing dependencies | Stop and report |
| A failure state is shown only in Dexter copy | Accessibility bug | File in experiment issue tracker |
| Any permission request from the app beyond mic/accessibility/input monitoring | Constraint violation | Stop and report |
| Any network request in Console.app | Constraint violation | Stop and report |
| Production dictation broken with all flags off | Regression | Stop and report |

---

## 6. Observations to capture

For each surface tested, note:
- Screenshot of: idle state, listening state, transcribed/inserted state, and any failure state reached
- Whether Dexter commentary is visible and in which states
- Whether Nano HUD stays on top during full-screen apps
- Whether Settings & History toggles persist after relaunch
- Whether the production popover is unchanged when flags are off
- Whether any sub-panel opened as a separate window (should never happen)

---

## 7. Confirm test complete

Run after finishing QA:
```bash
swift test  # should still pass 264 tests, 0 failures
```

File observations or issues against the branch before merging.

---

## Correction pass — 2026-06-12 (Phase 6)

The following regressions were found in manual QA and corrected:

| Finding | Root cause | Fix |
|---|---|---|
| Settings & History opened a separate window; Dock bounced | `.sheet` from MenuBarExtra calls `NSApp.activate()` | Converted to in-popover navigation via ExperimentalScreen state machine |
| No way to quit from experimental popover | Quit was only in Standard UI ControlsView | Added power button to title bar — always visible |
| Features (mic selection, profiles, etc.) unreachable from state-first popover | No QuickSettings access path | Added All Features hub wrapping full QuickSettings |
| No in-app way to switch surfaces | Required shell `defaults write` commands | Added GUI Switcher screen (Switch UI button) |
| Dexter feed showed random cross-profile lines | loadLines() used allCases without profile context | Feed now prefers active profile lines (3:2 ratio) |
| No Help section for experimental UI | Help has 18 sections, none covering experimental | Added `.experimentalUI` to HelpSection |
| Command Palette also opened as separate sheet | Same .sheet issue as layered reveal | Converted to in-popover with back button |

---

## Hardening pass — 2026-06-12 (Phase 7)

Second pass completed after Phase 6. Addressed dead-end surfaces and exposure gaps:

| Finding | Fix |
|---|---|
| Nano HUD had no path to Feature Hub | Added always-visible `slider.horizontal.3` hub button; FloatingHUDController creates hub NSPanel |
| Layered Reveal had no Feature Hub or GUI Switcher buttons in header | Added grid icon (All Features) and switch icon (Switch UI) to header |
| Command Palette had no navigation commands for Feature Hub, Switch UI, or Quit | Added "Open All Features", "Switch UI Surface", "Quit DexDictate" commands |
| Exposure audit only covered 3 surfaces (Standard, State-first, Nano HUD) | Rewritten with all 6 surfaces + production location + status + notes columns |
| Runbook had stale "sheet opens" language in Settings & History and Command Palette sections | All sections updated to reflect in-popover state-machine behavior |

### Re-test after hardening pass

Run the full runbook above. In addition:

- [ ] Nano HUD sliders button opens hub panel (non-activating, no Dock bounce)
- [ ] Layered Reveal header shows grid + switch icons; both navigate correctly
- [ ] Command Palette includes "Open All Features", "Switch UI Surface", "Quit DexDictate"
- [ ] Every GUI option complete-access check (Section 4) passes for all 5 surfaces
- [ ] No surface is a dead-end (every surface can reach Feature Hub within 1–2 taps)
- [ ] Exposure audit file updated with all 6 column groups
