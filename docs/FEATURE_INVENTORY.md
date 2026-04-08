# DexDictate Feature Inventory

This document lists the user-facing features and the supporting runtime functions that exist in the repository as of 2026-04-08.

## 1. Product Shape

DexDictate is a macOS 14+ menu-bar dictation app built with Swift Package Manager.

It is structured around:
- local Whisper transcription
- global trigger capture
- microphone recording
- output insertion or copy-only fallback
- session history
- custom vocabulary and voice commands
- profile-based UI/content variations
- benchmark capture and model promotion tooling
- local diagnostics

There is no cloud transcription path in the product runtime.

## 2. Launch and Shell

### 2.1 Menu Bar App

The app runs as a `MenuBarExtra(.window)` style menu-bar utility.

How to use:
- Launch the app.
- Open the menu-bar item.
- Use the popover for dictation, settings, history, and advanced controls.

Code:
- `Sources/DexDictate/DexDictateApp.swift`

### 2.2 First-Run Onboarding

The onboarding flow has four pages:
- welcome
- permissions
- trigger shortcut selection
- completion

How to use:
- Complete the pages in order on first launch.
- Grant the requested permissions.
- Pick a trigger shortcut.
- Click `Get Started`.

Code:
- `Sources/DexDictate/OnboardingView.swift`

### 2.3 Launch Intro Animation

If onboarding is already complete, the app plays a one-time intro animation after startup.

How to use:
- Automatic.
- No user control exposed.

Code:
- `Sources/DexDictate/LaunchIntroController.swift`

## 3. Permissions

### 3.1 Accessibility Permission

Used for:
- Quartz event tap setup
- trigger capture
- output insertion support

How to use:
- Grant it from onboarding or the privacy banner.

Code:
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`
- `Sources/DexDictate/PermissionBannerView.swift`

### 3.2 Input Monitoring Permission

Used for:
- receiving global input events
- keyboard and mouse trigger capture

How to use:
- Grant it in System Settings when prompted.
- On onboarding, follow the manual Input Monitoring steps.

Code:
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`
- `Sources/DexDictateKit/Permissions/InputMonitor.swift`

### 3.3 Microphone Permission

Used for:
- recording dictation audio
- microphone validation in onboarding

How to use:
- Grant it when the app prompts during dictation or in the validation panel.

Code:
- `Sources/DexDictateKit/Permissions/PermissionManager.swift`
- `Sources/DexDictateKit/Permissions/OnboardingValidation.swift`

### 3.4 Permission Banner

Shows missing permission state in the main popover and opens the relevant system settings pane.

How to use:
- Read the missing-permission summary.
- Click `Open Privacy Settings`.

Code:
- `Sources/DexDictate/PermissionBannerView.swift`

## 4. Dictation Triggering

### 4.1 Hold to Talk

Recording starts while the trigger is held and stops when it is released.

How to use:
- Select `Hold to Talk`.
- Hold the configured mouse button or key.
- Release to stop and transcribe.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Permissions/InputMonitor.swift`

### 4.2 Click to Toggle

Recording starts on one trigger press and stops on the next.

How to use:
- Select `Click to Toggle`.
- Press the configured trigger once to start.
- Press it again to stop.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Permissions/InputMonitor.swift`

### 4.3 Shortcut Recorder

Lets the user bind a keyboard shortcut or mouse button with modifiers.

How to use:
- Open Quick Settings.
- Click the shortcut recorder.
- Press the desired key or mouse button.

Code:
- `Sources/DexDictate/ShortcutRecorder.swift`

### 4.4 Default Trigger

The default trigger is the middle mouse button.

How to use:
- Do nothing; it is the factory default.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`

## 5. Audio Capture

### 5.1 Microphone Device Selection

The app can use a chosen microphone device or the system default.

How to use:
- Open Quick Settings.
- Pick a device from the input device selector.

Code:
- `Sources/DexDictateKit/Capture/AudioDeviceScanner.swift`
- `Sources/DexDictateKit/Capture/AudioDeviceManager.swift`
- `Sources/DexDictateKit/Capture/AudioInputSelectionPolicy.swift`

### 5.2 Live Input Meter

The app shows normalized microphone level while recording.

How to use:
- Start dictation.
- Watch the level indicator in the history panel or floating HUD.

Code:
- `Sources/DexDictateKit/Services/AudioRecorderService.swift`
- `Sources/DexDictate/HistoryView.swift`
- `Sources/DexDictate/FloatingHUD.swift`

### 5.3 Silence Timeout

Recording can auto-stop after a period of silence.

How to use:
- Open Quick Settings.
- Adjust the silence timeout slider.
- Set it to `0` to disable.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 5.4 Stop Tail Delay

The engine waits briefly after trigger release before stopping audio capture to avoid clipping the end of speech.

How to use:
- Not directly exposed as a simple setting.
- Controlled through utterance-end preset and experiment flags.

Code:
- `Sources/DexDictateKit/ExperimentFlags.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

## 6. Transcription

### 6.1 Local Whisper Dictation

Dictation is performed locally with Whisper.

How to use:
- Start dictation.
- Speak.
- Stop dictation.
- Read the output in the active app or in history.

Code:
- `Sources/DexDictateKit/Services/WhisperService.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`

### 6.2 Imported Audio File Transcription

An audio file can be transcribed from the file picker or from a drag-and-drop into the popover.

How to use:
- Click `Transcribe File...`, or
- drag an audio file onto the main popover.

Code:
- `Sources/DexDictate/ControlsView.swift`
- `Sources/DexDictate/ImportedFileTranscriptionSheet.swift`
- `Sources/DexDictate/DexDictateApp.swift`

### 6.3 File Import Support

The importer loads local audio files into mono PCM samples before resampling and transcription.

How to use:
- Use the file transcription feature.

Code:
- `Sources/DexDictateKit/Services/AudioFileImporter.swift`

### 6.4 Model Loading

The app can load the bundled `tiny.en` model and imported `base.en.bin` or `small.en.bin` models.

How to use:
- Open Quick Settings.
- Use `Import Model`.
- Select a supported file.
- Pick the active model from the model dropdown.

Code:
- `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`
- `Sources/DexDictateKit/Services/WhisperService.swift`

## 7. Output Handling

### 7.1 Auto-Paste

When enabled, the transcript is pasted into the frontmost app.

How to use:
- Leave Auto-Paste on.
- Dictate into a target application.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`

### 7.2 Save-Only Mode

When Auto-Paste is off, the transcript is only stored locally in history.

How to use:
- Disable Auto-Paste.
- Dictate normally.

Code:
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`

### 7.3 Copy-Only Sensitive Field Fallback

If the active field appears to be secure, the app copies instead of pasting.

How to use:
- Leave `Copy Only in Sensitive Fields` enabled.
- Dictate into password-like or secure-entry fields.

Code:
- `Sources/DexDictateKit/Output/SecureInputContext.swift`
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`

### 7.4 Accessibility API Insertion

The app can try direct insertion at the cursor using Accessibility API instead of Cmd+V.

How to use:
- Enable `Use Accessibility API for Insertion`.
- Some apps may still fall back to clipboard paste if insertion fails.

Code:
- `Sources/DexDictateKit/Output/OutputCoordinator.swift`
- `Sources/DexDictateKit/AppInsertionOverridesManager.swift`

### 7.5 Per-App Insertion Rules

Rules can override insertion mode for specific apps.

How to use:
- Open `Per-App Insertion Rules`.
- Add the current app or enter a bundle ID manually.
- Pick the insertion mode for that app.

Code:
- `Sources/DexDictate/PerAppInsertionSheet.swift`
- `Sources/DexDictateKit/AppInsertionOverridesManager.swift`

## 8. History

### 8.1 Inline History Feed

The popover contains an expandable transcription history feed with live mic status and copy buttons.

How to use:
- Open the menu-bar popover.
- Expand the history if needed.
- Copy any entry with its copy button.

Code:
- `Sources/DexDictate/HistoryView.swift`

### 8.2 Detached History Window

A separate history window provides search, export, clear, copy, and correction learning.

How to use:
- Click the detach button in the inline history panel.
- Use search, export, and clear controls in the window.

Code:
- `Sources/DexDictate/HistoryWindow.swift`

### 8.3 History Persistence

History can be saved to disk and restored on launch.

How to use:
- Enable `Persist History Across Sessions`.

Code:
- `Sources/DexDictateKit/HistoryPersistenceManager.swift`

### 8.4 Undo Removal

If the latest history entry was removed by `scratch that`, it can be restored.

How to use:
- Trigger `scratch that`.
- If an undo button appears, click it.

Code:
- `Sources/DexDictateKit/TranscriptionHistory.swift`
- `Sources/DexDictate/ControlsView.swift`

### 8.5 Accuracy Retry

The last utterance can be re-run in accuracy mode when the app has audio for it.

How to use:
- Click `Retry Last in Accuracy Mode` when the button appears.

Code:
- `Sources/DexDictateKit/TranscriptionEngine.swift`
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

## 9. Text Correction

### 9.1 Learn Correction

The app can turn a corrected transcript into a custom vocabulary replacement.

How to use:
- In history, choose `Learn correction`.
- Enter the incorrect and correct phrases.
- Save the correction.

Code:
- `Sources/DexDictate/VocabularyCorrectionSheet.swift`
- `Sources/DexDictate/HistoryWindow.swift`

### 9.2 Correction Sheet Toggle

The correction sheet can be shown or hidden from Quick Settings.

How to use:
- Toggle `Correction Sheet`.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

## 10. Profiles and Content Variants

### 10.1 Profile Selection

The app supports Standard, Canadian, and Aussie profiles.

How to use:
- Change the `Profile` picker in Quick Settings.

Code:
- `Sources/DexDictateKit/Profiles/AppProfile.swift`
- `Sources/DexDictateKit/Profiles/ProfileManager.swift`

### 10.2 Bundled Vocabulary by Profile

Each profile loads its own bundled vocabulary pack.

How to use:
- Select a profile.
- Dictation output automatically applies the profile pack.

Code:
- `Sources/DexDictateKit/Vocabulary/BundledVocabularyPacks.swift`

### 10.3 Flavor Ticker Content

The flavor ticker shows profile-specific quote lines and avoids repeating recent lines.

How to use:
- Enable `Show Flavor Ticker`.
- Optionally enable animation.

Code:
- `Sources/DexDictateKit/Quotes/FlavorTickerManager.swift`
- `Sources/DexDictateKit/Quotes/FlavorQuotePacks.swift`

### 10.4 Watermark Asset Rotation

The app rotates watermark art by profile and avoids repeating the last-selected asset.

How to use:
- Change profile.
- The watermark updates automatically.

Code:
- `Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift`

## 11. Menu Bar Presentation

### 11.1 Display Modes

The menu bar item can display:
- mic + text
- mic only
- custom Dex icon
- app logo
- emoji icon

How to use:
- Change `Menu Bar Style` in Quick Settings.

Code:
- `Sources/DexDictate/MenuBarIconController.swift`
- `Sources/DexDictate/DexDictateApp.swift`
- `Sources/DexDictate/QuickSettingsView.swift`

### 11.2 Emoji Picker

Users can pick a custom emoji for the menu bar.

How to use:
- Select `Emoji` mode.
- Click `Choose Emoji`.
- Pick or paste an emoji.

Code:
- `Sources/DexDictate/QuickSettingsView.swift`

## 12. Visual Feedback

### 12.1 Floating HUD

The floating HUD shows current state and microphone level.

How to use:
- Enable `Show Floating HUD`.

Code:
- `Sources/DexDictate/FloatingHUD.swift`

### 12.2 Flavor Ticker

Shows rotating one-line text in the popover.

How to use:
- Enable `Show Flavor Ticker`.

Code:
- `Sources/DexDictate/FlavorTickerView.swift`

### 12.3 Dictation Stats Ticker

Shows word count, elapsed time, and estimated WPM.

How to use:
- Enable `Show Dictation Stats`.

Code:
- `Sources/DexDictate/StatsTickerView.swift`

## 13. Benchmarking and Model Management

### 13.1 Benchmark Capture Window

The app has a dedicated capture UI for recording a strict corpus of prompts into local WAV files.

How to use:
- Open `Benchmark Capture`.
- Record each prompt in sequence.
- Save the session locally.

Code:
- `Sources/DexDictate/BenchmarkCaptureWindow.swift`

### 13.2 Strict Benchmark Corpus

The strict corpus contains the curated prompts used for offline quality testing.

How to use:
- Record the prompts exactly as shown in the capture window.

Code:
- `Sources/DexDictateKit/BenchmarkCorpus.swift`

### 13.3 Benchmark Results Storage

Results are cached locally for the current environment and utterance-end preset.

How to use:
- Run benchmarks from Quick Settings.
- Review cached results in the benchmark section.

Code:
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

### 13.4 Model Import and Promotion

Imported models can be benchmarked and promoted automatically if they clear the thresholds.

How to use:
- Import a model.
- Run benchmarks.
- Let auto-promotion pick a candidate if allowed.

Code:
- `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`
- `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`

## 14. System Integration

### 14.1 Launch at Login

The app can register itself as a login item through `SMAppService`.

How to use:
- Toggle `Launch at Login`.

Code:
- `Sources/DexDictateKit/Settings/LaunchAtLogin.swift`

### 14.2 App Intents / Shortcuts

The app exposes Start, Stop, and Toggle dictation actions to the Shortcuts ecosystem.

How to use:
- Invoke those intents from Shortcuts or other App Intents-capable surfaces.

Code:
- `Sources/DexDictate/DictationIntents.swift`

## 15. Settings and Modes

### 15.1 Safe Mode

Safe Mode forces hold-to-talk, disables auto-paste, and turns off sound cues.

How to use:
- Toggle `Safe Mode` in Quick Settings.

Code:
- `Sources/DexDictateKit/Settings/SafeModePreset.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 15.2 Restore Defaults

The app can reset all settings to their factory state.

How to use:
- Click `Restore Defaults` in the footer.

Code:
- `Sources/DexDictate/FooterView.swift`
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 15.3 Restore Stable Dictation Defaults

This resets the dictation-specific tuning knobs to a stable baseline.

How to use:
- Click `Restore Stable Defaults` in the benchmark section.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`

### 15.4 Theme and Appearance

The app supports several appearance themes and sound themes.

How to use:
- Pick an appearance theme in Quick Settings.
- Sound themes are applied through the sound-cue controls.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`

## 16. Diagnostics and Verification

### 16.1 Local Diagnostics

The app writes local diagnostics to the Application Support folder and Console.app.

How to use:
- Inspect `~/Library/Application Support/DexDictate/`.
- Open Console.app from the diagnostics path if needed.

Code:
- `Sources/DexDictateKit/Diagnostics/Safety.swift`
- `Sources/DexDictateKit/Diagnostics/Diagnostics.swift`

### 16.2 Verification Runner

The repo includes a verification executable that checks invariants and benchmark-related assumptions.

How to use:
- Run `swift run VerificationRunner`.

Code:
- `Sources/VerificationRunner/main.swift`

## 17. Dormant or Legacy Surface

These items exist in code but are not fully surfaced as primary user features.

- `inputButton` is legacy compatibility storage.
- `showVisualHUD` is a legacy alias for `showFloatingHUD`.
- `appendMode` is reserved and not implemented.
- `selectedEngine` is compatibility state; Whisper is the only runtime engine.
- `benchmarkGateEnabled` is persisted but not presented as a major current UI control.
- `selectedTheme` exists as a sound-theme preset, but the UI emphasis is on the start/stop sound selectors.

Code:
- `Sources/DexDictateKit/Settings/AppSettings.swift`
- `Sources/DexDictateKit/Settings/SettingsMigration.swift`

