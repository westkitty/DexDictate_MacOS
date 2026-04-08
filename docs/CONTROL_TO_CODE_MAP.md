# DexDictate Control to Code Map

This document maps the visible controls in the app to the code paths they drive.

## 1. Onboarding Window

### 1.1 Back / Next / Get Started

- `Back` decrements the onboarding page index.
- `Next` increments the page index.
- `Get Started` marks onboarding complete and closes the window.

Code:
- `Sources/DexDictate/OnboardingView.swift`

### 1.2 Open Accessibility Settings

- Requests Accessibility permission if needed.
- Reveals the next permission-step UI state.

Code:
- `Sources/DexDictate/OnboardingView.swift`
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`

### 1.3 Open Input Monitoring Settings

- Opens the correct System Settings deep link for Input Monitoring.

Code:
- `Sources/DexDictate/OnboardingView.swift`
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`

### 1.4 Trigger Test

- Runs a local event-tap readiness probe.
- Reports whether Accessibility and Input Monitoring are both sufficient and whether the tap can be created.

Code:
- `Sources/DexDictateKit/Permissions/OnboardingValidation.swift`
- `Sources/DexDictate/OnboardingView.swift`

### 1.5 Microphone Test

- Starts a short capture window and checks whether actual audio level is observed.

Code:
- `Sources/DexDictateKit/Permissions/OnboardingValidation.swift`
- `Sources/DexDictate/OnboardingView.swift`

### 1.6 Shortcut Recorder

- Captures the next key or mouse input as the new trigger shortcut.

Code:
- `Sources/DexDictate/ShortcutRecorder.swift`
- `Sources/DexDictate/OnboardingView.swift`

## 2. Main Popover: Controls

### 2.1 Start Dictation

- Starts the shared transcription engine.
- Sets up the input monitor and Whisper model if needed.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 2.2 Transcribe File...

- Opens a file picker for local audio.
- Sends the chosen file through the transcription pipeline.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`
- `Sources/DexDictateKit/Services/AudioFileImporter.swift`

### 2.3 Turn Off Dictation

- Stops the engine and returns it to the stopped state.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 2.4 Quit App

- Terminates the application.

Code:
- `Sources/DexDictate/ControlsView.swift`

### 2.5 Undo removal

- Restores the most recently removed history entry.
- Appears only after `scratch that` removed something.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`
- `Sources/DexDictateKit/TranscriptionHistory.swift`

### 2.6 Retry Last in Accuracy Mode

- Re-runs the last utterance using the accuracy decode profile.
- Requires saved audio for the utterance.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 2.7 Learn Correction

- Opens a correction sheet prefilled with the latest history item.
- Saves a vocabulary replacement when confirmed.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictate/VocabularyCorrectionSheet.swift`
- `Sources/DexDictateKit/VocabularyManager.swift`

## 3. Main Popover: History Panel

### 3.1 Detach History Window

- Opens the detached history window.

Code:
- `Sources/DexDictate/HistoryView.swift`
- `Sources/DexDictate/HistoryWindow.swift`

### 3.2 Expand / Collapse History

- Changes the inline history panel height.

Code:
- `Sources/DexDictate/HistoryView.swift`

### 3.3 Copy History Item

- Copies a specific history row to the pasteboard.

Code:
- `Sources/DexDictate/HistoryView.swift`
- `Sources/DexDictate/HistoryWindow.swift`

## 4. Main Popover: Quick Settings

### 4.1 Expand / Collapse Quick Settings

- Shows or hides the advanced control surface.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`

### 4.2 Profile Picker

- Changes the active profile.
- Synchronizes bundled vocabulary and dynamic content.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Profiles/ProfileManager.swift`

### 4.3 Return to Standard

- Switches the active profile back to Standard.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Profiles/ProfileManager.swift`

### 4.4 Show Flavor Ticker

- Toggles the quote strip in the popover.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/DexDictateApp.swift`

### 4.5 Animate Flavor Ticker

- Toggles ticker animation when motion is permitted.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/FlavorTickerView.swift`

### 4.6 Show Dictation Stats

- Shows or hides the stats ticker.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/DexDictateApp.swift`

### 4.7 Persist History Across Sessions

- Turns history save/restore on or off.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/HistoryPersistenceManager.swift`

### 4.8 Play Start Sound / Start Sound Picker

- Enables or disables the start cue.
- Lets the user choose the cue sound.
- Preview plays when the picker changes.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/SoundPlayer.swift`

### 4.9 Play Stop Sound / Stop Sound Picker

- Enables or disables the stop cue.
- Lets the user choose the cue sound.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/SoundPlayer.swift`

### 4.10 Appearance Theme

- Changes the theme used for the popover surfaces.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.11 Safe Mode

- Applies the safe-mode preset and restores it when disabled.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Settings/SafeModePreset.swift`

### 4.12 Auto-Paste

- Enables or disables automatic paste after transcription.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.13 Copy Only in Sensitive Fields

- Enables the secure-field fallback.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`

### 4.14 Filter Profanity

- Enables profanity filtering.
- Reveals custom addition/removal text areas when on.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/ProfanityFilter.swift`

### 4.15 Profanity Additions / Removals Text Areas

- Adds custom filter words.
- Un-filters bundled words.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.16 Use Accessibility API for Insertion

- Switches the default output insertion strategy.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`

### 4.17 Per-App Insertion Rules / Manage...

- Opens the per-app override window.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/PerAppInsertionSheet.swift`

### 4.18 Show Floating HUD

- Toggles the floating HUD window.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/FloatingHUD.swift`

### 4.19 Launch at Login

- Registers or unregisters the app as a login item.
- May surface an approval warning and a button to open Login Items settings.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/LaunchAtLogin.swift`

### 4.20 Menu Bar Style Picker

- Chooses the main menu-bar presentation mode.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/MenuBarIconController.swift`

### 4.21 Dex Icon Picker

- Selects a bundled Dex icon for the menu bar.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/MenuBarIconController.swift`

### 4.22 Emoji Icon Picker

- Lets the user pick or paste an emoji for the menu bar item.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`

### 4.23 Open Benchmark Capture

- Opens the local benchmark recording window.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/BenchmarkCaptureWindow.swift`

### 4.24 Open Captured Corpus

- Opens the session folder in Finder.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/BenchmarkCaptureWindow.swift`

### 4.25 Active Model Picker

- Chooses the active Whisper model.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`

### 4.26 Model Selection Mode Picker

- Switches between automatic idle benchmarking and manual mode.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

### 4.27 End Preset Picker

- Changes utterance-end timing and trimming thresholds.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/ExperimentFlags.swift`

### 4.28 Trim Leading/Trailing Silence

- Toggles silence trimming before transcription.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Services/AudioResampler.swift`

### 4.29 Trailing Trim Experiment

- Toggles the trailing-only trim heuristic.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Services/AudioResampler.swift`

### 4.30 Accuracy Retry

- Enables or disables the retry button in the controls area.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 4.31 Correction Sheet

- Enables or disables the “Learn Correction” control.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.32 Import Model

- Opens a file picker and imports a supported local Whisper model.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`

### 4.33 Run Benchmarks Now

- Starts the manual benchmark run against the active and imported models.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

### 4.34 Restore Stable Defaults

- Resets the dictation-specific tuning settings to the stable baseline.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.35 Input Device Picker

- Chooses the microphone device.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Capture/AudioDeviceScanner.swift`

### 4.36 Silence Timeout Slider

- Adjusts the number of seconds before auto-stop after silence.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 4.37 Custom Vocabulary / Manage...

- Opens the custom vocabulary editor.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/VocabularySettingsView.swift`

### 4.38 Voice Commands / Manage...

- Opens the custom voice-commands editor.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/CustomCommandsSheet.swift`

### 4.39 Shortcut Recorder in Quick Settings

- Rebinds the active trigger shortcut from the settings panel.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictate/ShortcutRecorder.swift`

## 5. Detached Windows and Sheets

### 5.1 History Window Search

- Filters history entries by text.

Code:
- `Sources/DexDictate/HistoryWindow.swift`

### 5.2 History Window Export

- Exports filtered history to a plain-text document.

Code:
- `Sources/DexDictate/HistoryWindow.swift`

### 5.3 History Window Clear

- Clears all history entries.

Code:
- `Sources/DexDictate/HistoryWindow.swift`

### 5.4 History Window Copy

- Copies a single history item.

Code:
- `Sources/DexDictate/HistoryWindow.swift`

### 5.5 History Window Learn Correction

- Opens the correction sheet with the selected item as the incorrect phrase.

Code:
- `Sources/DexDictate/HistoryWindow.swift`
- `Sources/DexDictate/VocabularyCorrectionSheet.swift`

### 5.6 Imported File Transcript Sheet Copy

- Copies the imported transcript text.

Code:
- `Sources/DexDictate/ImportedFileTranscriptionSheet.swift`

### 5.7 Imported File Transcript Sheet Close

- Dismisses the imported transcript sheet.

Code:
- `Sources/DexDictate/ImportedFileTranscriptionSheet.swift`

### 5.8 Per-App Rule Add Current App

- Captures the frontmost app bundle ID and display name.

Code:
- `Sources/DexDictate/PerAppInsertionSheet.swift`

### 5.9 Per-App Rule Add Manually

- Shows empty fields so you can type a bundle ID yourself.

Code:
- `Sources/DexDictate/PerAppInsertionSheet.swift`

### 5.10 Per-App Rule Save / Cancel / Delete

- Saves a new override.
- Cancels the draft.
- Deletes existing overrides.

Code:
- `Sources/DexDictate/PerAppInsertionSheet.swift`
- `Sources/DexDictateKit/AppInsertionOverridesManager.swift`

### 5.11 Voice Commands Add / Cancel / Delete

- Adds a custom `Dex [keyword]` command.
- Cancels the draft row.
- Deletes existing custom commands.

Code:
- `Sources/DexDictate/CustomCommandsSheet.swift`
- `Sources/DexDictateKit/CustomCommandsManager.swift`

## 6. Footer

### 6.1 Restore Defaults

- Resets all app settings to the factory state.

Code:
- `Sources/DexDictate/FooterView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 6.2 About

- Opens the project repository in the browser.

Code:
- `Sources/DexDictate/FooterView.swift`

### 6.3 Version Tap Easter Egg

- Tapping the version label five times opens onboarding debug mode.

Code:
- `Sources/DexDictate/FooterView.swift`
- `Sources/DexDictate/DexDictateApp.swift`

## 7. Hidden or Less Obvious Control Paths

### 7.1 Drag and Drop File Transcription

- Dropping a file onto the main popover triggers audio-file transcription when the engine is ready.

Code:
- `Sources/DexDictate/DexDictateApp.swift`

### 7.2 Open Privacy Settings Button

- Opens the relevant privacy pane based on the missing-permission state.

Code:
- `Sources/DexDictate/PermissionBannerView.swift`
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`

### 7.3 Open Login Items Settings Button

- Appears when login-item approval is needed.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/LaunchAtLogin.swift`

### 7.4 Benchmark Results Cards

- Display cached benchmark results, the active result, and the current run state.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

### 7.5 Launch Intro and Floating HUD Auto-Show

- These are automatic behaviors driven by settings and launch state, not direct buttons.

Code:
- `Sources/DexDictate/DexDictateApp.swift`
- `Sources/DexDictate/LaunchIntroController.swift`
- `Sources/DexDictate/FloatingHUD.swift`

