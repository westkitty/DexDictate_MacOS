# DexDictate — Help Center Content Draft

<!-- IA: sidebar sections, draft copy, search aliases, screenshot notes, cross-links -->
<!-- Generated from codebase inspection. Features documented only if clearly implemented. -->
<!-- Last updated: 2026-04-08 -->

---

## Help Window Architecture

### Navigation Model

- Left sidebar: 18 named sections, each with SF Symbol icon
- Top search field: filters sidebar and matches section body text + search aliases
- Content pane: scrollable, max readable width ~480pt
- "Related:" footer on each section linking to 1–3 related sections
- Default landing: Welcome section

### Section List (ordered as they appear in sidebar)

| # | Title | SF Symbol | Search Aliases |
|---|---|---|---|
| 1 | Welcome to DexDictate | `hand.wave` | what is, intro, overview, start |
| 2 | Getting Started | `flag.checkered` | setup, first run, onboarding, begin |
| 3 | Permissions | `lock.shield` | accessibility, input monitoring, microphone, privacy |
| 4 | Trigger Setup | `keyboard` | shortcut, hotkey, button, hold, toggle, middle mouse |
| 5 | Recording & Audio | `waveform` | mic, microphone, input, audio, record, silence |
| 6 | Transcription | `text.bubble` | whisper, model, accuracy, local, offline |
| 7 | Output & Pasting | `doc.on.clipboard` | paste, copy, insert, secure, password, auto-paste |
| 8 | Transcription History | `clock.arrow.circlepath` | history, log, export, search, detach |
| 9 | Custom Vocabulary | `book.closed` | words, replacements, vocabulary, correction |
| 10 | Voice Commands | `mic.badge.plus` | scratch that, dex, new line, all caps, commands |
| 11 | Profiles | `person.2` | canadian, aussie, standard, flavor, watermark |
| 12 | Appearance & Menu Bar | `paintbrush` | theme, icon, emoji, minimalist, cyberpunk, menu bar |
| 13 | Floating HUD | `rectangle.on.rectangle` | hud, floating, panel, overlay, status |
| 14 | Safe Mode | `shield.lefthalf.filled` | safe, defaults, restore, low risk |
| 15 | Benchmarking & Models | `chart.bar` | benchmark, wer, latency, model, tiny.en, accuracy |
| 16 | Shortcuts & Siri | `sparkles` | siri, shortcuts, app intents, automation |
| 17 | Diagnostics | `stethoscope` | logs, debug, troubleshoot, not working, error |
| 18 | About | `info.circle` | version, github, credits |

---

## Section Content

---

### 1. Welcome to DexDictate

**What it is**

DexDictate lives in your menu bar and converts your speech to text using a local Whisper AI model — no internet connection required. Your audio never leaves your Mac.

Press your configured trigger to start speaking. DexDictate transcribes what you say and types it into whatever app is in focus.

**Key ideas**

- Everything runs locally on your Mac (Apple Silicon optimized)
- Works in any app: code editors, documents, chat, email, terminals
- Hold your trigger to talk, release to transcribe — or switch to click-to-toggle mode
- Every transcription is saved in-session for review, correction, and export

> **Screenshot:** Full popover in resting state — watermark, history panel, controls, Quick Settings collapsed, footer
> → `help-welcome-overview.png`

**Related:** Getting Started · Trigger Setup · Output & Pasting

---

### 2. Getting Started

**First launch**

When you first open DexDictate, the onboarding flow walks you through three required steps:

1. **Accessibility permission** — allows DexDictate to detect your trigger key/button
2. **Input Monitoring permission** — allows DexDictate to listen for your trigger globally
3. **Microphone permission** — macOS will ask when you first start dictating

> **Screenshot:** Onboarding permissions page showing three permission steps with status badges
> → `help-onboarding-permissions.png`

**After onboarding**

- Click the DexDictate icon in your menu bar to open the popover
- Hold your trigger and start speaking
- Release to transcribe — text appears in your active app

**Re-opening onboarding**

Tap the version string in the footer five times to re-open the onboarding screen (useful for reviewing permissions or shortcut setup).

> **Screenshot:** Onboarding shortcut page with recorder configured
> → `help-onboarding-shortcut.png`

**Related:** Permissions · Trigger Setup

---

### 3. Permissions

DexDictate requires three macOS permissions. All three are standard and can be revoked at any time in System Settings → Privacy & Security.

---

**Accessibility**

Required to detect your trigger key or button press system-wide, even when DexDictate is not the focused app.

- Where to grant: System Settings → Privacy & Security → Accessibility → DexDictate
- If missing: The trigger will not fire. A warning banner appears inside DexDictate.

---

**Input Monitoring**

Required to read keyboard and mouse button events globally.

- Where to grant: System Settings → Privacy & Security → Input Monitoring → DexDictate
- If missing: Same symptom as missing Accessibility — trigger doesn't fire.

---

**Microphone**

Required to record your voice. macOS will prompt automatically the first time you dictate.

- Where to grant: System Settings → Privacy & Security → Microphone → DexDictate
- If missing: Recording appears to start but captures silence.

---

**Troubleshooting permissions**

If the permission banner appears even after granting:
1. Fully quit DexDictate (right-click the menu bar icon → Quit)
2. Re-open DexDictate
3. If the banner persists, remove DexDictate from the permission list in System Settings, re-add it, then relaunch

> **Screenshot:** Permission warning banner inside the main popover
> → `help-permissions-banner.png`

> **Screenshot:** macOS System Settings showing Accessibility list with DexDictate
> → `help-permissions-system-settings.png`

**Related:** Getting Started · Diagnostics

---

### 4. Trigger Setup

**What the trigger does**

The trigger is the key or button you hold (or click) to start and stop dictation. DexDictate monitors it globally — it fires even when another app is in focus.

**Default trigger:** Middle mouse button

---

**Changing your trigger**

Open the popover → Quick Settings → Input section → click the shortcut recorder field → press your desired key or button combination.

Supported triggers:
- Any keyboard key, with optional modifiers (Cmd, Shift, Ctrl, Option)
- Mouse buttons (middle, back, forward, and others)
- Combinations such as Ctrl + a function key or Right Option alone

---

**Trigger modes**

**Hold to Talk** *(default)*
Hold the trigger → DexDictate starts recording. Release → recording stops and transcription begins immediately. Good for short utterances and quick insertions.

**Click to Toggle**
Press the trigger once to start recording. Press again to stop. Good for long-form dictation where holding is uncomfortable.

Switch mode: Quick Settings → Input → Trigger Mode selector.

> **Screenshot:** Quick Settings open, Mode section showing trigger mode and shortcut recorder
> → `help-trigger-settings.png`

**Related:** Recording & Audio · Getting Started

---

### 5. Recording & Audio

**Microphone selection**

By default DexDictate uses your system default microphone. To use a different device:
Quick Settings → Input → Input Device → select from the list.

The list shows all audio input devices detected by macOS: built-in mic, USB microphones, Bluetooth headsets, and audio interfaces.

---

**Silence timeout**

DexDictate can automatically stop recording after a period of silence, even if you haven't released the trigger.

- To enable: Quick Settings → Output → Silence Timeout → set a value in seconds (0 = disabled)
- When active, a countdown timer appears in the history panel: "Auto-stopping in Xs..."

---

**File import**

Transcribe an existing audio file by dragging and dropping it onto the DexDictate popover. Supported formats include WAV, MP3, M4A, and other formats supported by AVFoundation on macOS.

---

**Live transcript preview**

While recording, a partial transcription preview appears in the history panel with a green "Live" label and a mic level bar. This preview is approximate — the final transcription may differ slightly once processing is complete.

> **Screenshot:** Main popover during active recording — "Mic Active" badge, live preview, mic level bar
> → `help-recording-active.png`

**Related:** Trigger Setup · Transcription · Transcription History

---

### 6. Transcription

**Local, private transcription**

DexDictate uses OpenAI's Whisper model running entirely on your Mac. No audio or text is sent to any external server at any point.

---

**The bundled model**

The default model is `tiny.en` — a compact, English-only model that balances speed and accuracy well on Apple Silicon Macs.

---

**Model selection**

Quick Settings → System → Model section.

DexDictate can benchmark available models on your hardware and automatically promote to a more accurate or faster model if one is available. See **Benchmarking & Models** for details.

---

**Utterance End Preset**

Controls how aggressively DexDictate trims silence at the end of a recording:

| Preset | Behavior |
|---|---|
| Stable | Conservative; least likely to clip the end of a sentence |
| Fast | More aggressive silence trimming; may clip very last words |
| Conservative | Very generous; waits longer before closing the utterance |

Quick Settings → System → Utterance End Preset.

---

**Accuracy Retry** *(opt-in)*

When enabled, DexDictate automatically re-runs transcription at higher accuracy if it detects a low-confidence result. Items re-transcribed this way are tagged "Accuracy retry" in history.

Enable via: Quick Settings → System → Benchmark → Optimization section → Accuracy Retry toggle (when visible in your build).

---

**Important caveats**

- Accuracy depends heavily on microphone quality and background noise
- Very short phrases (under ~1 second) may not transcribe reliably
- Non-English speech will produce unpredictable results with the default `tiny.en` model
- The trailing trim experiment (opt-in) can improve results by removing post-speech silence

> **Screenshot:** Quick Settings System section showing active model and Utterance End Preset
> → `help-transcription-model.png`

**Related:** Benchmarking & Models · Recording & Audio · Output & Pasting

---

### 7. Output & Pasting

**How DexDictate delivers text**

DexDictate picks the best delivery method based on your settings and the focused app:

| Scenario | What happens |
|---|---|
| Default (auto-paste on) | Text is copied to clipboard; Cmd+V is simulated in the active app |
| Focused app is a password/secure field | Text is copied to clipboard only — no keystroke simulation |
| Per-app rule: clipboard only | Text is always copied only, never pasted |
| Per-app rule: Accessibility API | Text is inserted via the macOS Accessibility API directly |
| Auto-paste off | Text is saved to history only; nothing is pasted or copied |

---

**Auto-paste**

Quick Settings → Output → Auto-Paste toggle.

When on (default), DexDictate pastes immediately after transcription completes. When off, text is only saved to history — copy it from there manually.

---

**Copy-only in sensitive fields**

Quick Settings → Output → Copy Only in Sensitive Fields.

When on (default), DexDictate detects password and secure text fields via the Accessibility API and switches to clipboard-only mode automatically.

---

**Accessibility API insertion**

Quick Settings → Output → Use Accessibility API for Insertion.

An alternative to Cmd+V. Inserts text directly into the focused element via macOS accessibility. More reliable in some apps (code editors, terminal emulators). May not work in every app.

---

**Per-app rules**

Quick Settings → Output → Manage Per-App Rules.

Set a custom delivery mode for specific apps by their bundle identifier. Overrides the global setting for those apps only.

---

**Profanity filter**

Quick Settings → Output → Filter Profanity.

Replaces matched words with asterisks in the final output before it is delivered. Add custom words to filter, or remove words from the built-in list, using the + / − buttons.

> **Screenshot:** Quick Settings Output section expanded — all output toggles visible
> → `help-output-settings.png`

**Related:** Transcription History · Transcription · Safe Mode

---

### 8. Transcription History

**The inline history panel**

Every transcription is logged in the history panel at the top of the main popover. Each item shows:

- Timestamp
- Full transcription text (selectable)
- Copy button
- "Accuracy retry" badge when applicable

The panel collapses to 100pt (most recent items) or expands to 300pt. Click the chevron icon to toggle.

---

**Detached history window**

Click the expand icon (↗) in the history panel header to open a full-size detached window. Features:

- Search across all history items
- Export all history to a plain text file
- Clear all history
- "Learn Correction" button on each item (teaches DexDictate a vocabulary replacement)

> **Screenshot:** Detached history window with several items, search field, export and trash buttons
> → `help-history-window.png`

> **Screenshot:** Inline history panel expanded in recording state
> → `help-history-inline-expanded.png`

---

**History persistence**

By default, history is cleared when you close the popover. Enable persistence in:
Quick Settings → Mode → Persist History Across Sessions.

When enabled, history is saved to disk and restored on next launch.

**Related:** Custom Vocabulary · Output & Pasting

---

### 9. Custom Vocabulary

**What it does**

Custom vocabulary teaches DexDictate to automatically replace transcribed words or phrases with your preferred versions. Useful for proper nouns, technical terms, acronyms, and consistently mis-transcribed words.

**Example:** If Whisper consistently transcribes "DexDictate" as "Dex Dictate", add an entry:
`Dex Dictate` → `DexDictate`

---

**Adding a replacement**

**Option A — From history:** Click "Learn Correction" on any history item → enter the correct version in the correction sheet.

**Option B — From settings:** Quick Settings → Input → Custom Vocabulary → open the editor.

---

**How replacements work**

- Word-boundary regex match (case-insensitive)
- Applied after transcription, before output delivery
- Profile-specific bundled vocabulary is merged with your custom entries
- Custom entries override bundled entries for the same original phrase

> **Screenshot:** Vocabulary correction sheet with both fields filled
> → `help-vocabulary-correction-sheet.png`

**Related:** Voice Commands · Transcription · Profiles

---

### 10. Voice Commands

**Built-in commands**

Say these phrases at any time during or after dictation:

| Say | What happens |
|---|---|
| "Scratch That" | Deletes the last transcribed sentence |
| "All Caps [text]" | Uppercases the specified text |
| "New Line" or "Next Line" | Inserts a newline character |

---

**Custom voice commands**

Quick Settings → Input → Voice Commands → Manage Custom Commands.

Custom commands use the prefix "Dex" followed by a keyword you define. Examples:

| Say | Inserts |
|---|---|
| "Dex comma" | , |
| "Dex period" | . |
| "Dex tab" | [tab character] |

Custom commands are checked first; built-in commands are the fallback.

---

**Caveats**

- Recognition depends on Whisper transcribing the trigger phrase accurately
- All command matching is case-insensitive
- Very short command phrases may be clipped by an aggressive silence timeout

> **Screenshot:** Custom Commands sheet with example entries
> → `help-voice-commands-sheet.png`

**Related:** Custom Vocabulary · Trigger Setup · Recording & Audio

---

### 11. Profiles

**What profiles do**

Profiles adjust DexDictate's bundled vocabulary, flavor ticker quotes, and watermark icon for different regional variants of English.

| Profile | Bundled vocabulary |
|---|---|
| Standard | US English defaults |
| Canadian | Canadian English spelling and terms |
| Aussie | Australian English spelling and terms |

---

**Switching profiles**

Quick Settings → Mode → Profile selector.

Click "Return to Standard" to go back to the default.

---

**Flavor ticker**

A rotating line of profile-specific motivational text shown below the app title (when enabled). Toggle in Quick Settings → Mode → Show Flavor Ticker.

---

**Stats ticker**

Shows current session statistics — word count, duration, WPM. Toggle in Quick Settings → Mode → Show Dictation Stats.

**Related:** Appearance & Menu Bar · Custom Vocabulary

---

### 12. Appearance & Menu Bar

**Themes**

Quick Settings → Appearance → Theme.

| Theme | Look |
|---|---|
| System | Follows macOS light/dark mode; material background |
| Cyberpunk | Dark with cyan accents |
| Minimalist | Softer, reduced chrome |
| High Contrast | Enhanced contrast for accessibility |

---

**Menu bar icon style**

Quick Settings → Appearance → Menu Bar Icon.

| Mode | What shows |
|---|---|
| Mic + Text | Waveform icon with status text |
| Mic Only | Waveform icon alone |
| Custom Icon | Choose from 18 bundled icons |
| Logo Only | DexDictate logo |
| Emoji | Any emoji you enter |

> **Screenshot:** Appearance section of Quick Settings showing theme and icon options
> → `help-appearance-settings.png`

**Related:** Profiles · Floating HUD

---

### 13. Floating HUD

**What it is**

A small floating panel that shows DexDictate's status independently of the menu bar. Useful when dictating into full-screen apps where the menu bar is hidden.

---

**Status colors**

| Color | Meaning |
|---|---|
| Red | Actively recording |
| Yellow | Transcribing |
| Green | Ready / idle |
| Orange | Error state |

---

**Enabling the HUD**

Quick Settings → Output → Show Floating HUD.

**Moving the HUD**

Drag it by its background. Position is saved automatically and restored on next launch.

**Hiding the HUD**

Toggle off in Quick Settings, or close the window. It will reopen on next launch if the setting is on.

> **Screenshot:** Floating HUD in recording state (red) and idle state (green), side by side
> → `help-floating-hud-states.png`

**Related:** Appearance & Menu Bar · Recording & Audio

---

### 14. Safe Mode

**What it does**

Safe Mode applies a low-risk preset: hold-to-talk trigger, clipboard-only output (no auto-paste), and no sound effects. Use it when you want DexDictate to behave conservatively — for troubleshooting, testing, or dictating into sensitive apps.

**Enabling Safe Mode:** Quick Settings → Output → Safe Mode toggle.

When Safe Mode is on, your current settings are snapshotted internally. Turning it off restores all your previous settings exactly as they were.

---

**Stable Dictation Defaults**

Resets transcription-specific settings (model, utterance preset, trim configuration) to known-good values, without affecting output or appearance preferences.

Location: Quick Settings → System → Restore Stable Defaults (if visible in your build).

---

**Restore Defaults**

Footer → Restore Defaults resets **all** settings to factory defaults. Custom vocabulary and voice commands are **not** affected.

> **Screenshot:** Safe Mode toggle in Quick Settings Output section, toggle ON
> → `help-safe-mode-toggle.png`

**Related:** Diagnostics · Output & Pasting

---

### 15. Benchmarking & Models

**What benchmarking does**

DexDictate can benchmark available Whisper models against a reference audio corpus and measure:

- **Word Error Rate (WER)** — transcription accuracy vs. a known transcript
- **Latency** — average and 95th-percentile transcription time

---

**The bundled corpus**

DexDictate ships with a reference audio corpus. You can also record your own corpus using the Benchmark Capture window — which reflects your voice and environment more accurately than the bundled samples.

---

**Benchmark Capture**

Quick Settings → System → Benchmark → Capture Corpus.

Read the on-screen prompts aloud while recording. DexDictate saves the recordings as a WAV corpus for future benchmark runs.

---

**Auto model promotion**

When enabled, DexDictate can automatically switch to a better model if it passes quality gates (WER and latency thresholds) on your hardware.

Quick Settings → System → Auto-promote models.

---

**Manual model selection**

Quick Settings → System → Model → switch to Manual and pick a model directly.

---

**Note on experimental features**

The trailing silence trim and accuracy retry features are off by default. They can improve results in some setups but may behave differently depending on your microphone and environment.

> **Screenshot:** Benchmark Capture window with a prompt visible and recording controls
> → `help-benchmark-capture.png`

> **Screenshot:** Model section in Quick Settings showing active model
> → `help-model-settings.png`

**Related:** Transcription · Diagnostics

---

### 16. Shortcuts & Siri

**App Intents (macOS 13+)**

DexDictate supports three Siri Shortcuts / App Intents:

| Intent | Siri phrase | What it does |
|---|---|---|
| Start Dictation | "Start dictation with DexDictate" | Starts recording if not already active |
| Stop Dictation | "Stop listening in DexDictate" | Stops recording if active |
| Toggle Dictation | "Toggle dictation with DexDictate" | Toggles recording state |

---

**Using Shortcuts**

Open the Shortcuts app → search "DexDictate" in the app actions list → add to a shortcut or assign a Siri phrase.

**Note:** App Intents require DexDictate to be running. If it is not running, Siri will attempt to launch it first.

**Related:** Trigger Setup · Getting Started

---

### 17. Diagnostics

**When DexDictate isn't working as expected**

---

**Trigger not firing**

1. Check permissions — both Accessibility and Input Monitoring must be granted (see **Permissions**)
2. Fully quit DexDictate and relaunch it
3. Confirm your shortcut is configured correctly in Quick Settings → Input

---

**Transcription is empty or wrong**

1. Confirm Microphone permission is granted
2. Check your input device in Quick Settings → Input → Input Device
3. Try Safe Mode (clipboard-only, rules out output issues)
4. Try the bundled `tiny.en` model in Quick Settings → System → Model

---

**Text is pasting in the wrong place, or not pasting**

1. Ensure the target app is in focus when you release the trigger
2. Check per-app rules in Quick Settings → Output → Manage
3. Try enabling Accessibility API insertion

---

**Reading the diagnostics log**

DexDictate writes structured logs to:

```
~/Library/Application Support/DexDictate/debug.log
```

Open this file in any text editor to review recent events and error messages.

---

**Using Safe Mode for troubleshooting**

Safe Mode isolates most output-related issues. If dictation works in Safe Mode but not normally, the problem is likely an output setting or a per-app rule.

> **Screenshot:** Permission banner visible inside the main popover
> → `help-diagnostics-permissions-banner.png`

**Related:** Permissions · Safe Mode · Output & Pasting

---

### 18. About

**DexDictate** is a local-first macOS dictation app built for speed, privacy, and reliability on Apple Silicon.

- All transcription runs on-device using OpenAI's open-source Whisper model
- No audio or text is sent to external servers
- Source code: [github.com/WestKitty/DexDictate_MacOS](https://github.com/WestKitty/DexDictate_MacOS)

**Version information** is displayed in the footer of the main popover.

**Related:** Getting Started · Diagnostics
