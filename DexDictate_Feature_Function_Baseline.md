# DexDictate Feature / Function Baseline

## 1. Audit Metadata

- **Repository Path:** `/Users/andrew/DexDictate_MacOS.nosync`
- **Branch:** `speech-engine-exploration-benchmarks`
- **Inspected Commit Hash:** `9eea598f11b77352f094af68ebd4f71f36dac0ef`
- **Local Date/Time:** `2026-07-09T02:25:00-04:00`
- **Auditor:** Google Antigravity
- **Initial Working Tree Status:** Staged clean, with active background scanner syncs.
- **Preservation Commit Hash:** `9eea598f11b77352f094af68ebd4f71f36dac0ef`
- **Safety Tag:** `pre-fable-audit-20260709-0222`
- **Push Status:** Successfully pushed to remote `speech-engine-exploration-benchmarks`.

## 2. Executive Summary

DexDictate is a feature-rich, local-first dictation tool for macOS. It has highly robust, production-ready subsystems for:
- **Audio Capture & Recovery:** Exception-bridged tap installs, default device fallbacks, configuration change listeners, and specialized device stall classification (error `-10868`).
- **Insertion pipelines:** Cursor targeting, active focus mismatch guards, sensitive context copy-only fallbacks, and pasteboard payload caps (10MB) during clipboard restore.
- **Model management:** Built-in benchmarking, local validation corpora, and automatic model promotion.

However, the product is severely limited by a **UI/UX crisis**:
- Core features like context biasing, commands, vocabulary sheets, and benchmarking are buried in nested collapsible cards or separate AppKit modal panels.
- The duplication of UI paths between Standard popovers and Experimental popovers splits development efforts.
- Overlapping terminology (balanced preset, accuracy preset, quality retry) increases cognitive load.

The current codebase contains **no network LLM/Ollama settings**. The provider architecture (`nemotron`, `parakeet`, `moonshine`, `appleSpeech`, `whisperKit`) is built entirely on local CoreML / ONNX models running on the Apple Neural Engine. Preparing for remote Ollama is highly compatible with the current architecture but requires introducing clean, configurable endpoint settings.

## 3. Current Architecture Map

- **App Entry Point:** [DexDictateApp.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/DexDictateApp.swift)
- **Menu Bar Shell:** [MenuBarIconController.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/MenuBarIconController.swift)
- **Settings Store:** [AppSettings.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Settings/AppSettings.swift)
- **Audio Recording:** [AudioRecorderService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderService.swift)
- **Audio Resampling:** [AudioResampler.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioResampler.swift)
- **Whisper Service:** [WhisperService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/WhisperService.swift)
- **Transcription Providers:** [TranscriptionProviderRegistry.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Transcription/TranscriptionProviderRegistry.swift)
- **Output insertion:** [OutputCoordinator.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/OutputCoordinator.swift)
- **History persistence:** [HistoryPersistenceManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/HistoryPersistenceManager.swift)
- **Permissions:** [PermissionManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/PermissionManager.swift)
- **Quartz Event Tap:** [InputMonitor.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/InputMonitor.swift)
- **Diagnostics:** [Safety.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Diagnostics/Safety.swift) & [Diagnostics.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Diagnostics/Diagnostics.swift)

## 4. Complete Feature Inventory

### Feature: Local Whisper Dictation
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** Yes
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Records mic audio, resamples it, transcribes it locally using the active Whisper model, and outputs it.
- **Actual behavior:** Transcribes audio in a single batch upon stopping capture.
- **Current UI location:** Main popover record button, global hotkey trigger.
- **Trigger/input:** Mouse click or global shortcut toggle/hold.
- **Output behavior:** Pastes or copies transcribed text based on settings.
- **Code evidence:**
  - [TranscriptionEngine.swift:624-692](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift#L624-L692)
  - [WhisperService.swift:262-325](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/WhisperService.swift#L262-L325)
- **Storage/config dependencies:** `@AppStorage("activeWhisperModelID_v1")`
- **Related tests:** `WhisperServiceTests.swift`
- **Known bugs or rough edges:** Slow warm-up on cold starts; no streaming during batch dictation.
- **Preserve during refactor:** Yes
- **Improve during refactor:** Yes (reduce warm-up latency)
- **Magic Echo equivalent:** local-first system-wide dictation / raw transcription
- **DexDictate-only advantage:** Offline-first and fully local.
- **Risk if lost:** Critical (core functionality).

### Feature: Audio Route Recovery & Default Fallback
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** Yes (diagnostic values in Route Health card)
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Keeps the dictation session alive or recovers gracefully when microphones disconnect or system audio routes change.
- **Actual behavior:** Listens for `kAudioHardwarePropertyDefaultInputDevice` and AVAudioEngine changes; retries preferred device and falls back to system default.
- **Current UI location:** Quick Settings > Input > Route Health disclosure panel.
- **Trigger/input:** Core Audio hardware notifications.
- **Output behavior:** Updates active device settings and logs recovery stats.
- **Code evidence:**
  - [AudioRecorderService.swift:124-178](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderService.swift#L124-L178)
  - [AudioRecorderRecoverySupport.swift:105-221](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift#L105-L221)
- **Storage/config dependencies:** `@AppStorage("inputDeviceUID")`
- **Related tests:** `AudioRecorderRecoveryPlannerTests.swift`, `AudioRecorderRecoveryFailureTests.swift`
- **Known bugs or rough edges:** Route switches during active recording can cause brief audio gaps.
- **Preserve during refactor:** Yes
- **Improve during refactor:** Yes (make UI warning clearer)
- **Magic Echo equivalent:** Unclear/Missing
- **DexDictate-only advantage:** Massive reliability advantage over basic recorders.
- **Risk if lost:** High (causes app locks/crashes when AirPods disconnect).

### Feature: Reset Core Audio (coreaudiod reset)
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** Yes
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Restarts the macOS audio service (`coreaudiod`) to resolve device invalid stalls (-10868).
- **Actual behavior:** Executes `killall -9 coreaudiod` via NSAppleScript with administrator privileges.
- **Current UI location:** Quick Settings > Advanced > Reset Core Audio button.
- **Trigger/input:** User button click.
- **Output behavior:** Prompts for administrator access, resets daemon, and rebuilds active audio engine.
- **Code evidence:**
  - [CoreAudioResetService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/CoreAudioResetService.swift)
  - [QuickSettingsView.swift:753-792](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/QuickSettingsView.swift#L753-L792)
- **Storage/config dependencies:** None.
- **Related tests:** `AudioRecorderRecoveryFailureTests.swift`
- **Known bugs or rough edges:** Requires OS-level administrator privileges prompting the user.
- **Preserve during refactor:** Yes
- **Improve during refactor:** No (it is a system workaround)
- **Magic Echo equivalent:** Missing
- **DexDictate-only advantage:** Exceptional developer/power-user escape hatch.
- **Risk if lost:** Medium (users cannot resolve device stalls without reboot).

### Feature: Focus Mismatch Guard & Target Focus Verification
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** No
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Prevents inserting transcribed text into the wrong app if the user changes active windows during transcription.
- **Actual behavior:** Captures target window/element identity at trigger down, verifies active target before insertion; falls back to copy-only if active target mismatch is detected.
- **Current UI location:** No UI settings (runs automatically).
- **Trigger/input:** Transcription completion.
- **Output behavior:** Aborts paste, logs focus mismatch, and copies text to clipboard instead.
- **Code evidence:**
  - [TranscriptionEngine.swift:823-839](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift#L823-L839)
  - [SecureInputContext.swift:66-131](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/SecureInputContext.swift#L66-L131)
- **Storage/config dependencies:** None.
- **Related tests:** `OutputPipelineHardeningTests.swift`
- **Known bugs or rough edges:** Mismatch heuristics can trigger copy-only mode if system UI updates slowly.
- **Preserve during refactor:** Yes
- **Improve during refactor:** Yes (add user-facing HUD warning that focus shifted).
- **Magic Echo equivalent:** Missing
- **DexDictate-only advantage:** Crucial security/safety feature.
- **Risk if lost:** High (transcripts leak into wrong chat windows or editors).

### Feature: Secure-Field Heuristics (Copy-Only Fallback)
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** Yes (Quick Settings toggle)
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Prevents typing transcripts into password or secure entry fields.
- **Actual behavior:** Inspects focused Accessibility element attributes; flags matching password/token fields and switches output to copy-only.
- **Current UI location:** Quick Settings > Output > Copy Only in Sensitive Fields toggle.
- **Trigger/input:** Focus scanning during dictation.
- **Output behavior:** Copies to clipboard and prevents paste.
- **Code evidence:**
  - [SecureInputContext.swift:142-197](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/SecureInputContext.swift#L142-L197)
  - [OutputCoordinator.swift:195-202](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/OutputCoordinator.swift#L195-L202)
- **Storage/config dependencies:** `@AppStorage("copyOnlyInSensitiveFields")`
- **Related tests:** `SecureInputContextTests.swift`, `OutputCoordinatorTests.swift`
- **Known bugs or rough edges:** None.
- **Preserve during refactor:** Yes
- **Improve during refactor:** No
- **Magic Echo equivalent:** macOS permissions & sensitive context handling
- **DexDictate-only advantage:** Privacy protection.
- **Risk if lost:** Medium (security risk of pasting passwords/codes into text fields).

### Feature: Clipboard Restore (with 10MB payload limit)
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** No
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Restores the user's original clipboard contents after the app uses it for a synthetic paste (Cmd+V).
- **Actual behavior:** Snapshots clipboard before paste, writes transcript, triggers paste, and restores original clipboard only if the change count hasn't been altered by the user. Skips restore if original data > 10MB.
- **Current UI location:** No UI settings.
- **Trigger/input:** Paste event.
- **Output behavior:** Clipboard contents restored.
- **Code evidence:**
  - [ClipboardManager.swift:91-123](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/ClipboardManager.swift#L91-L123)
  - [ClipboardManager.swift:140-171](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/ClipboardManager.swift#L140-L171)
- **Storage/config dependencies:** None.
- **Related tests:** `ClipboardManagerTests.swift`
- **Known bugs or rough edges:** A slow paste can cause the restore to execute before the target application processes Cmd+V, pasting the restored content instead.
- **Preserve during refactor:** Yes
- **Improve during refactor:** Yes (use adjustable delays)
- **Magic Echo equivalent:** raw fallback / pasteboard support
- **DexDictate-only advantage:** Protects user clipboard data.
- **Risk if lost:** Medium (destroys user clipboard history).

### Feature: Model Benchmarking & Auto-Promotion
- **Status:** Implemented
- **Confidence:** High
- **Implemented in code:** Yes
- **Exposed in UI:** Yes (folded under model controls)
- **Tested:** Yes
- **Documented:** Yes
- **User-facing purpose:** Records a set of validation prompts to test custom models locally, promoting models that clear latency/WER thresholds.
- **Actual behavior:** Records WAV files matching `BenchmarkCorpus` prompts, executes `VerificationRunner` to calculate WER, and promotes candidate models if they score higher than the active model.
- **Current UI location:** Quick Settings > Accuracy & Speed > Benchmarks & Corpus group.
- **Trigger/input:** Button click or background idle triggers.
- **Output behavior:** Updates benchmark cache and updates model selection.
- **Code evidence:**
  - [ModelBenchmarking.swift:420-780](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift#L420-L780)
  - [BenchmarkCaptureWindow.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/BenchmarkCaptureWindow.swift)
- **Storage/config dependencies:** `@AppStorage("modelSelectionMode_v1")`
- **Related tests:** `AdaptiveBenchmarkControllerTests.swift`, `BenchmarkPromotionPolicyTests.swift`
- **Known bugs or rough edges:** None.
- **Preserve during refactor:** Yes
- **Improve during refactor:** Yes (needs dedicated UI layout)
- **Magic Echo equivalent:** Missing
- **DexDictate-only advantage:** High-confidence model validation without manual testing.
- **Risk if lost:** Low (power-user feature).

## 5. Magic Echo Equivalence Matrix

| Magic Echo feature | DexDictate equivalent | Status | Evidence | Gap / note | Priority |
|---|---|---|---|---|---|
| local-first dictation | Local Whisper Dictation | Already implemented | `WhisperService.swift` | Runs whisper.cpp fully locally. | High |
| raw transcription | Whisper Compatibility Mode | Already implemented | `WhisperKitTranscriptionProvider.swift` | No streaming preview, batch only. | High |
| smart transcription | Smart LLM processing | Missing | None | No remote/local LLM provider code exists. | High |
| raw fallback on fail | Fallback to Whisper | Missing | None | Needs LLM connection monitoring. | Medium |
| extended dictation | Click to Toggle Mode | Already implemented | `AppSettings.swift:383` | Supports toggle recording. | High |
| on-screen awareness | None | Missing | None | No screen capture or context reading. | Low |
| voice commands | Voice Commands / Custom Vocab | Already implemented | `CommandProcessor.swift` | Supports keyword macros. | High |
| custom vocabulary | Custom Vocabulary / Correction | Already implemented | `VocabularyManager.swift` | Supports learning spelling corrections. | High |
| Past Echoes / history | inline/detached history view | Already implemented | `HistoryWindow.swift` | Rich history with search/export. | High |
| remappable hotkeys | ShortcutRecorder | Already implemented | `ShortcutRecorder.swift` | Remaps mouse and keyboard. | High |
| silence detection | Silence Timeout | Already implemented | `AppSettings.swift:39` | Auto-stops recording. | High |
| OpenAI/Ollama settings | None | Missing | None | Current providers are ANE/CoreML only. | High |

## 6. DexDictate-Only Advantages

1. **Objective-C Exception Bridge:** [AudioTapInstaller.m](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateObjCSupport/AudioTapInstaller.m) wraps `AVAudioEngine` tap installations inside `@try/@catch` blocks, preventing the app from crashing when Core Audio configuration shifts unexpectedly.
2. **Audio Route Recovery Planner:** Methodically resolves missing inputs, retrying preferred devices with progressive delays `[0, 0.2, 0.5, 1.0]` before falling back to system default.
3. **Core Audio Reset Helper:** Surfaces an administrative command (`killall -9 coreaudiod`) directly in the app to resolve device stall failures (-10868).
4. **Focused Focus Validation:** Prevents target app focus mismatches from pasting text into wrong active fields.
5. **On-Device Benchmarking Corpus:** Captures a local voice sample corpus matching golden prompts to verify model promotion.
6. **Localization Profiles:** Australia and Canada profiles swap vocabulary sheets and quotes.

## 7. UI Surface Map

- **Menu Bar popover:** [DexDictateApp.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/DexDictateApp.swift). Contains controls, history feed, and the folded settings. Needs visual review.
- **Quick Settings View:** [QuickSettingsView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/QuickSettingsView.swift). scrolling card stack of 10+ panels. Highly cluttered; needs recovery.
- **Detached History Window:** [HistoryWindow.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/HistoryWindow.swift). Search, export, clear, and correction learning. High UX quality.
- **Vocabulary Editor Sheet:** [VocabularySettingsView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/VocabularySettingsView.swift). Detached window sheet. Hidden.
- **Onboarding Wizard:** [OnboardingView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/OnboardingView.swift). Multi-page permission guide. High quality.
- **Benchmark Capture Window:** [BenchmarkCaptureWindow.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/BenchmarkCaptureWindow.swift). Prompts, controls, and session storage. High quality but hard to find.
- **Floating HUD:** [FloatingHUD.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/FloatingHUD.swift). Renders level meter. Needs visual review.
- **State-First Popover (Experimental):** [DexStateFirstPopoverView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/ExperimentalUI/DexStateFirstPopoverView.swift). Duplicate settings hub. Creates confusion.

## 8. Feature Preservation Contract

| Feature | Must preserve? | Existing evidence | Minimum validation after refactor |
|---|---|---|---|
| Local Whisper Dictation | Yes | `WhisperService.swift` | Run `./scripts/benchmark.sh` (or `swift test`) |
| Audio Route Recovery | Yes | `AudioRecorderRecoveryPlanner.swift` | `AudioRecorderRecoveryPlannerTests` must pass |
| Accessibility Insertion | Yes | `OutputCoordinator.swift` | `AccessibilityInsertionTests` must pass |
| Clipboard Restore | Yes | `ClipboardManager.swift` | `ClipboardManagerTests` must pass |
| Focus Verification | Yes | `SecureInputContext.swift` | `OutputPipelineHardeningTests` must pass |
| Voice Commands | Yes | `CommandProcessor.swift` | `CommandProcessorTests` must pass |
| Custom Vocabulary | Yes | `VocabularyManager.swift` | `VocabularyLayeringTests` must pass |
| Settings Migration | Yes | `SettingsMigration.swift` | `SettingsMigrationTests` must pass |

## 9. Fragile / Do-Not-Touch List

- **AVAudioEngine Tap Installation:** [AudioRecorderService.swift:536-563](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderService.swift#L536-L563). Must pass through ObjC bridge. Format must be `nil` to inherit hardware format.
- **Quartz Event Tap Lifecycle:** [InputMonitor.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/InputMonitor.swift). Do not change thread/runloop scheduling; event tap must remain isolated.
- **Clipboard Backup Matching:** [ClipboardManager.swift:91-123](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/ClipboardManager.swift#L91-L123). Restores only if change count matches; do not alter wait delays.
- **Resampling conversion:** [AudioResampler.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioResampler.swift). Conversions must target 16kHz mono.

## 10. Hidden / Poorly Surfaced Features

- **Custom Vocabulary & Voice Commands:** Accessed via two small AppKit buttons. Recommend moving to a dedicated "Vocabulary & Commands" sidebar tab.
- **Accuracy Retry:** Recommend adding an explicit status banner ("Quality Retry Active") instead of a silent trigger.
- **Context Injection:** Clarify label to: "Inject Focused Field Context".
- **Per-App Overrides:** Move to a top-level settings card.

## 11. Duplicate / Overlapping Concepts

- **Accuracy Preset vs. Accuracy Retry vs. Balanced Preset:** Overlapping terminology in model loading and transcription execution.
- **Standard UI vs. Experimental UI:** Duplicate settings controllers exist in `QuickSettingsView.swift` and `DexStateFirstComponents.swift`.
- **Command vs. Dictation:** Ambiguity in Moonshine command pre-check vs. Whisper command execution.

## 12. Missing or Unclear Features

- **OpenAI-Compatible provider connection.**
- **Smart-to-raw transcription fallback.**
- **Remote Ollama setup UI.**
- **On-screen multi-window context awareness.**
- **Connection test buttons for remote providers.**
- **Live Transcription (unresolved):** Text appearing while the user is still speaking (Parakeet streaming was attempted but is unsuccessful).

## 13. Live Transcription Requirement

Live transcription is the only major requested capability that remains unresolved.

- **Current State:** The production path uses batch transcription (recording stops, then local Whisper/compatibility provider transcribes).
- **Parakeet Attempt:** Parakeet streaming was integrated but failed to meet expectations due to stability and threading issues. It is a partial path that requires complete architectural reassessment.
- **Preservation Contract:** The existing batch Whisper transcription pipeline must not be compromised or weakened. It serves as the primary high-confidence fallback.
- **Roadmap Architecture recommendation:** Fable should evaluate a staged path:
  1. *Phase 1:* reliable live preview captions inside DexDictate HUD/popover only (provisional text shown while speaking).
  2. *Phase 2:* final Whisper/accuracy transcript remains the committed output.
  3. *Phase 3:* optional live typing mode (inserting text dynamically) only after preview stability is proven.
  4. *Phase 4:* remote Ollama/Smart layer may clean final output, not drive low-latency live partials.
- **Key Risks:** Partial transcript instability, duplicate text emissions, cursor drift, focus changes during speech, correction/rewrite complexity, latency from local/remote models, and user confusion.

## 14. Validation Commands

- **Unit tests:** `swift test`
- **Quality Verification:** `./scripts/run_quality_paths.sh`
- **Release Verification:** `./scripts/validate_release.sh .build/DexDictate.app`
- **Benchmark Run:** `./scripts/benchmark.sh --audio sample_corpus/sample.wav`

## 15. Refactor Readiness Verdict & Next Step

- **UI/UX Planning:** **Ready.** Fable 5 can draft popover/settings redesigns and live transcription roadmaps.
- **Refactoring:** **Gated.** Do not refactor audio capture or event tap until the UI taxonomy is approved.
- **Ollama Stack:** **Gated.** Remote provider setting fields are blocked until settings reorganizations are completed.
- **Recommended Next Step:** Give the completed Fable packet and Fable prompt to Fable 5 for assessment. Do not implement new features or modify functional code until the Fable plan is reviewed and approved.
