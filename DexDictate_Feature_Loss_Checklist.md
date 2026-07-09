# DexDictate Feature Loss Checklist

## Critical Preservation Checks

- [ ] **Local Whisper Dictation**
  - *Validation:* Compile project, start dictation via Middle Mouse, speak a sentence, stop recording, and verify the transcript is typed.
  - *Code/Test:* [TranscriptionEngine.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift), `WhisperServiceTests.swift`
- [ ] **Audio Route Recovery & Fallback**
  - *Validation:* Unplug headphones or change default system input device during idle or active recording, verify the app automatically switches default inputs and recovers.
  - *Code/Test:* [AudioRecorderRecoverySupport.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift), `AudioRecorderRecoveryPlannerTests.swift`
- [ ] **Reset Core Audio UI & Command**
  - *Validation:* Click "Reset Core Audio" in Advanced settings, verify prompt for administrator password occurs, and check that the audio scanner re-detects audio devices.
  - *Code/Test:* [CoreAudioResetService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/CoreAudioResetService.swift), [QuickSettingsView.swift#L753](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/QuickSettingsView.swift#L753)
- [ ] **Objective-C Exception Bridge**
  - *Validation:* Run test suite, check for zero crashes on tap manipulation.
  - *Code/Test:* [AudioTapInstaller.m](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateObjCSupport/AudioTapInstaller.m), `AudioTapInstallerTests.swift`
- [ ] **Focus Mismatch Guard**
  - *Validation:* Start recording, quickly click to focus a different application, stop recording, verify transcription is copied to clipboard rather than pasted.
  - *Code/Test:* [SecureInputContext.swift#L66](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/SecureInputContext.swift#L66), `OutputPipelineHardeningTests.swift`
- [ ] **Secure-Field Copy-Only Fallback**
  - *Validation:* Focus a password field in any browser or app, dictate text, verify the text is copied to the clipboard and not pasted.
  - *Code/Test:* [SecureInputContext.swift#L142](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/SecureInputContext.swift#L142), `SecureInputContextTests.swift`
- [ ] **Clipboard Restoration & Payload Cap**
  - *Validation:* Copy a string to the clipboard, start and stop dictation (with Auto-Paste enabled), verify transcript is pasted and original clipboard text is restored. Test that copying > 10MB data skips restoration.
  - *Code/Test:* [ClipboardManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/ClipboardManager.swift), `ClipboardManagerTests.swift`
- [ ] **Accessibility API Direct Insertion**
  - *Validation:* Enable "Use Accessibility API for Insertion", focus a text editor (e.g., Notes), dictate, verify text inserts directly at cursor without modifying clipboard.
  - *Code/Test:* [OutputCoordinator.swift#L227](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/OutputCoordinator.swift#L227), `AccessibilityInsertionTests.swift`
- [ ] **Per-App Insertion Overrides**
  - *Validation:* Configure an override rule for an app (e.g., set Slack to "Copy Only"), verify Slack behaves as configured while other apps paste.
  - *Code/Test:* [PerAppInsertionSheet.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/PerAppInsertionSheet.swift), `AppInsertionOverridesManagerTests.swift`
- [ ] **Smart Quality Retry (Accuracy Retry)**
  - *Validation:* Set manual retry, dictate very quiet noise to yield a low-confidence transcript, verify that the "Retry Last in Accuracy Mode" button appears in the popover.
  - *Code/Test:* [TranscriptionEngine.swift#L994](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift#L994), `ModelBenchmarking.swift`
- [ ] **Context Injection (Focused Field Reading)**
  - *Validation:* Type "My name is John. I work at ", start dictation, say "DexDictate", verify context reads prior text to prime Whisper.
  - *Code/Test:* [FocusedTextReader.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/FocusedTextReader.swift), `FocusedTextReaderTests.swift`
- [ ] **Custom Vocabulary and learned corrections**
  - *Validation:* Open history window, click "Learn correction", map "foo" -> "bar", dictate "foo", check that "bar" is typed.
  - *Code/Test:* [VocabularyManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/VocabularyManager.swift), `VocabularyLayeringTests.swift`
- [ ] **Voice Commands**
  - *Validation:* Define a command (e.g., keyword "scratch that" deletes the last word), dictate the keyword, and verify the action executes.
  - *Code/Test:* [CommandProcessor.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/CommandProcessor.swift), `CommandProcessorTests.swift`
- [ ] **Onboarding & Permission Polling**
  - *Validation:* Reset app defaults, run app, complete wizard pages, verify microphone/accessibility permissions are correctly monitored and requested.
  - *Code/Test:* [OnboardingView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/OnboardingView.swift), `OnboardingValidationTests.swift`
- [ ] **Launch at Login**
  - *Validation:* Toggle "Launch at Login" in Quick Settings, verify login item registers with System.
  - *Code/Test:* [LaunchAtLogin.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Settings/LaunchAtLogin.swift), `LaunchAtLoginControllerTests.swift`
- [ ] **Floating HUD & Tickers**
  - *Validation:* Start recording, verify HUD window opens and meter moves. Check that the flavor ticker scrolls quotes in the Popover.
  - *Code/Test:* [FloatingHUD.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/FloatingHUD.swift), `ProfileContentTests.swift`
- [ ] **Model Benchmarking & Promotion**
  - *Validation:* Open "Benchmark Capture" window, record Golden Prompts, run baseline benchmarks, check that results save to `benchmark_baseline.json`.
  - *Code/Test:* [ModelBenchmarking.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift), `BenchmarkPromotionPolicyTests.swift`

## Must-Not-Break Systems

1. **Audio Recording Loop:** Serial queue execution of `AVAudioEngine` capture to avoid background threading crashes.
2. **Local Transcription Queue:** Serial batch execution of whisper.cpp model threads to prevent race conditions or CPU spikes.
3. **Trigger Event Tap:** Quartz `CGEvent` listener that monitors hotkey bounds globally.
4. **macOS Accessibility Trust:** The polling loop checking permissions must never block the main thread.
5. **Settings Schema Migrator:** UserDefaults migration logic must stay backwards compatible.

## Refactor Gate

A refactor packet cannot be considered done unless:
- [ ] `swift build` and `swift test` succeed without new failures.
- [ ] Existing test suites (`AudioRecorderRecoveryPlannerTests`, `ClipboardManagerTests`, `SecureInputContextTests`, etc.) pass with zero failures.
- [ ] No feature listed in the Critical Preservation Checks disappears or loses UI exposure without human approval.
- [ ] Core Audio recovery and ObjC bridges are untouched unless explicitly modified under safety tests.
- [ ] Configuration URL endpoints do not leak data over cleartext/insecure connections.
- [ ] UI visual layouts are verified via manual walkthroughs, and screenshots/videos are captured for changes.
