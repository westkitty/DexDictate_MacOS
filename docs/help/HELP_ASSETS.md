# DexDictate Help System — Screenshot & Asset Shot List

<!-- Generated from codebase inspection. Capture from a real running build. -->
<!-- Last updated: 2026-04-08 -->

## Capture Guidelines

- Capture at **2× (Retina)** resolution
- Use macOS Screenshot (Cmd+Shift+4 or Cmd+Shift+5) for precision
- Crop tightly unless the full window is the subject
- **Hide title bars** unless the window chrome is part of what's being shown
- Annotate with **red rectangle callouts** where called out (use Preview markup or Figma)
- Save as PNG; use the exact filenames listed below
- Store assets in: `Sources/DexDictateKit/Resources/Assets.xcassets/Help/`
  (create one `.imageset` per screenshot; add `Contents.json` with `idiom: "mac"`)

---

## Screenshot Inventory

---

### `help-welcome-overview.png`

- **Section:** Welcome to DexDictate
- **Shows:** Full main popover in idle state — app title, history panel (empty or 1–2 items), controls area, Quick Settings collapsed, footer
- **Capture from:** Open the menu bar popover with no active dictation session
- **Framing:** Full popover (320×540 pt displayed size), slight macOS shadow visible, no title bar
- **Annotations:** None — clean overview shot
- **Priority:** Required

---

### `help-onboarding-permissions.png`

- **Section:** Getting Started
- **Shows:** Onboarding page 2 — three-step permission checklist with Accessibility, Input Monitoring, and Microphone status badges
- **Capture from:** Tap the version string in the footer five times to reopen onboarding → navigate to the Permissions page
- **Framing:** Full onboarding window (520×480 pt)
- **Annotations:** Optionally highlight each badge with a light callout border
- **Priority:** Required

---

### `help-onboarding-shortcut.png`

- **Section:** Getting Started
- **Shows:** Onboarding page 3 — shortcut recorder with a sample shortcut already configured (e.g., Ctrl+D)
- **Capture from:** Onboarding → navigate to the Shortcut page → set a sample shortcut so the field shows a key
- **Framing:** Full onboarding window
- **Annotations:** None
- **Priority:** Recommended

---

### `help-permissions-banner.png`

- **Section:** Permissions
- **Shows:** Yellow/orange permission warning banner inside the main popover
- **Capture from:** Revoke Accessibility permission temporarily in System Settings → Privacy & Security → Accessibility, then open DexDictate
- **Framing:** Crop to just the banner area (~top 120pt of popover content below the title)
- **Annotations:** Red outline around the banner
- **Priority:** Required
- **Restore after capture:** Re-grant Accessibility permission

---

### `help-permissions-system-settings.png`

- **Section:** Permissions
- **Shows:** macOS System Settings → Privacy & Security → Accessibility with DexDictate visible in the list
- **Capture from:** System Settings app, navigate to the Accessibility list
- **Framing:** Crop to the app list area — no need for full System Settings window chrome
- **Annotations:** Red arrow pointing to the DexDictate row
- **Priority:** Recommended

---

### `help-trigger-settings.png`

- **Section:** Trigger Setup
- **Shows:** Quick Settings panel expanded, Mode section visible — trigger mode selector and shortcut recorder field with a configured shortcut
- **Capture from:** Open popover → expand Quick Settings → Mode section is at the top
- **Framing:** Crop to the Quick Settings card area (not the full popover)
- **Annotations:** Red callout rectangles around the trigger mode selector and shortcut field
- **Priority:** Required

---

### `help-recording-active.png`

- **Section:** Recording & Audio
- **Shows:** Popover during active dictation — red "Mic Active" badge, live transcript text or "Listening..." label, green mic level progress bar
- **Capture from:** Start dictation and capture quickly while speaking (use a helper or prepare a phrase)
- **Framing:** Crop to the history panel area (top ~200pt of popover content)
- **Annotations:** Callout on the "Mic Active" badge and the progress bar
- **Priority:** Required

---

### `help-transcription-model.png`

- **Section:** Transcription
- **Shows:** Quick Settings System section — active model name and Utterance End Preset picker visible
- **Capture from:** Open Quick Settings → scroll to the System section
- **Framing:** Crop to the System section card
- **Annotations:** Callout on the model name row and the preset picker
- **Priority:** Recommended

---

### `help-output-settings.png`

- **Section:** Output & Pasting
- **Shows:** Quick Settings Output section fully expanded — Auto-Paste, Copy Only in Sensitive Fields, Profanity Filter, Use Accessibility API, Per-App Rules manage button, Safe Mode, Show Floating HUD all visible
- **Capture from:** Open Quick Settings → Output section → expand it fully
- **Framing:** Crop to the Output section card
- **Annotations:** None — clean overview of the section
- **Priority:** Required

---

### `help-history-window.png`

- **Section:** Transcription History
- **Shows:** Detached FullHistoryView window with 3–5 history items, search field active, export (share) and trash icon buttons visible in the header
- **Capture from:** Dictate a few phrases → click the detach/expand (↗) button in the history panel header
- **Framing:** Full detached window (400×500 pt displayed size), with macOS window chrome visible
- **Annotations:** Callout on the search field and the export button
- **Priority:** Required

---

### `help-history-inline-expanded.png`

- **Section:** Transcription History
- **Shows:** Inline history panel inside the main popover in expanded (300pt) state, showing several history items with timestamps and copy buttons
- **Capture from:** Dictate a few phrases → click the chevron to expand history
- **Framing:** Crop to the history panel area inside the popover
- **Annotations:** Callout on the detach button (↗) and the collapse chevron
- **Priority:** Recommended

---

### `help-vocabulary-correction-sheet.png`

- **Section:** Custom Vocabulary
- **Shows:** Vocabulary correction sheet modal — "Incorrect phrase" field filled with a sample wrong transcription and "Correct phrase" field filled with the correct version
- **Capture from:** Open detached history window → click "Learn Correction" on any item → fill both fields with example text
- **Framing:** Sheet modal, cropped tightly
- **Annotations:** None — the filled fields are self-explanatory
- **Priority:** Required

---

### `help-voice-commands-sheet.png`

- **Section:** Voice Commands
- **Shows:** Custom Commands sheet with 2–3 example entries visible (e.g., "Dex comma" → "," and "Dex period" → ".")
- **Capture from:** Quick Settings → Output → Custom Commands button → open the sheet → add 2–3 example commands
- **Framing:** Sheet modal, cropped
- **Annotations:** None
- **Priority:** Recommended

---

### `help-appearance-settings.png`

- **Section:** Appearance & Menu Bar
- **Shows:** Quick Settings Appearance section — theme picker and menu bar display mode selector
- **Capture from:** Quick Settings → Appearance section
- **Framing:** Crop to the Appearance section card
- **Annotations:** Callout on the theme picker control
- **Priority:** Recommended

---

### `help-floating-hud-states.png`

- **Section:** Floating HUD
- **Shows:** Two side-by-side states of the Floating HUD — recording state (red accent) and idle/ready state (green accent)
- **Capture from:**
  1. Enable Show Floating HUD → screenshot the HUD in idle state
  2. Start dictation → screenshot the HUD in recording state
  3. Composite both states side-by-side in Preview or Figma on a dark desktop background
- **Framing:** Just the HUD panel (approximately 200×60pt), 2× on a dark background; add text labels "Recording" and "Ready" below each state
- **Annotations:** Labels below each state
- **Priority:** Recommended

---

### `help-safe-mode-toggle.png`

- **Section:** Safe Mode
- **Shows:** Quick Settings Output section with the Safe Mode toggle in the ON state (visually active)
- **Capture from:** Quick Settings → Output section → toggle Safe Mode on
- **Framing:** Crop to the Safe Mode toggle row only
- **Annotations:** Red outline rectangle around the Safe Mode toggle
- **Priority:** Required
- **Restore after capture:** Turn Safe Mode back off

---

### `help-benchmark-capture.png`

- **Section:** Benchmarking & Models
- **Shows:** Benchmark Capture window — a reference prompt visible, mic level bar, recording status displayed
- **Capture from:** Quick Settings → System section → Benchmark → Capture Corpus button
- **Framing:** Full Benchmark Capture window (640×680 pt displayed size), macOS chrome visible
- **Annotations:** Callout on the current prompt text and the mic level bar
- **Priority:** Recommended

---

### `help-model-settings.png`

- **Section:** Benchmarking & Models
- **Shows:** Quick Settings System section — model selector with the active model name highlighted
- **Capture from:** Quick Settings → System section
- **Framing:** Crop to just the model selector area
- **Annotations:** None
- **Priority:** Recommended

---

### `help-diagnostics-permissions-banner.png`

- **Section:** Diagnostics
- **Shows:** Permission banner inside the main popover (same content as `help-permissions-banner.png` but annotated for the Diagnostics section)
- **Capture from:** Same as `help-permissions-banner.png` — revoke Accessibility temporarily, open DexDictate
- **Framing:** Same crop as permissions-banner
- **Annotations:** Red callout reading "Check here first"
- **Priority:** Optional — reuse `help-permissions-banner.png` if reducing asset count
- **Restore after capture:** Re-grant Accessibility permission

---

## Icon & Illustration Assets

All sidebar icons use standard SF Symbols bundled with macOS — no custom icon files needed for the sidebar. The following are only required if icons are embedded in section body content (not the sidebar).

| Asset | SF Symbol | Use in body | Priority |
|---|---|---|---|
| Trigger icon for body illustration | `keyboard` | Trigger Setup section | Optional |
| Output icon for body illustration | `doc.on.clipboard` | Output & Pasting section | Optional |
| HUD icon for body illustration | `rectangle.on.rectangle` | Floating HUD section | Optional |
| Safe Mode shield for body | `shield.lefthalf.filled` | Safe Mode section | Optional |

---

## Priority Summary

| Priority | Count | Assets |
|---|---|---|
| Required | 9 | welcome-overview, onboarding-permissions, permissions-banner, trigger-settings, recording-active, output-settings, history-window, vocabulary-correction-sheet, safe-mode-toggle |
| Recommended | 8 | onboarding-shortcut, permissions-system-settings, transcription-model, history-inline-expanded, voice-commands-sheet, appearance-settings, floating-hud-states, benchmark-capture, model-settings |
| Optional | 1 | diagnostics-permissions-banner (reuse permissions-banner with different annotation) |

**Minimum viable help system:** Capture the 9 Required screenshots first. The help window functions without images, using placeholder space; screenshots can be added incrementally.
