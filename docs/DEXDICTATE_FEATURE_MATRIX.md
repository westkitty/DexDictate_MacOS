# DexDictate Feature Matrix

Audit date: 2026-04-10. All claims grounded in direct source inspection.

Status definitions:
- **working** — Implementation present, logic complete, exercised by tests or verification
- **partial** — Implementation exists but deliberately incomplete or disabled
- **stub** — Scaffolding or enum present, no functional implementation
- **dead** — Code exists, not reachable from any current path
- **unclear** — Present but insufficient evidence to assess correctness

---

## Core Application Shell

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Menu-bar app (NSStatusItem / MenuBarExtra) | yes | `Sources/DexDictate/DexDictateApp.swift` | working | `.window` style MenuBarExtra |
| App lifecycle (launch, quit) | yes | `DexDictateApp.swift` (AppDelegate) | working | Registers icon, shows onboarding, starts engine |
| @main entry point | yes | `DexDictateApp.swift` | working | SwiftUI App protocol, `@NSApplicationDelegateAdaptor` |
| Launch at login | yes | `Sources/DexDictateKit/Settings/LaunchAtLogin.swift` | working | SMAppService (macOS 13+) |
| AppIntents integration (Siri/Shortcuts) | yes | `Sources/DexDictate/DictationIntents.swift` | working | Start, Stop, Toggle dictation intents |

---

## Onboarding

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| First-run onboarding flow | yes | `Sources/DexDictate/OnboardingView.swift` | working | 4 pages: welcome, mic, accessibility, input monitoring |
| Onboarding completion tracking | yes | `AppSettings.hasCompletedOnboarding` | working | @AppStorage persisted |
| Debug onboarding re-trigger | yes | `FooterView.swift` (hidden control) | working | `AppDelegate.presentOnboardingForDebug()` |
| Onboarding animation/video | yes | `LaunchIntroController.swift` | working | Optional startup animation |

---

## Permissions

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Microphone permission request | yes | `Sources/DexDictateKit/Permissions/PermissionManager.swift` | working | AVCaptureDevice authorization |
| Accessibility permission check | yes | `PermissionManager.swift` | working | Polling every 2s |
| Input Monitoring permission check | yes | `PermissionManager.swift` | working | Polling every 2s |
| Permission polling (2s timer) | yes | `PermissionManager.swift` | working | Not notification-based (by design for reliability) |
| Permission recovery on grant | yes | `TranscriptionEngine.retryInputMonitor()` | working | Re-creates event tap |
| Permission banner UI | yes | `Sources/DexDictate/PermissionBannerView.swift` | working | Shows if any permission missing |
| System Settings deep links | yes | `PermissionManager.swift` | working | x-apple.systempreferences URLs |
| Pre-flight validation | yes | `Sources/DexDictateKit/Permissions/OnboardingValidation.swift` | working | Blocks dictation if permissions missing |

---

## Audio Capture

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Microphone recording (AVAudioEngine) | yes | `Sources/DexDictateKit/Services/AudioRecorderService.swift` | working | All ops on dedicated serial audioQueue |
| Audio input device selection | yes | `Sources/DexDictateKit/Capture/AudioDeviceManager.swift` | working | CoreAudio device configuration |
| Audio input device scanning (live list) | yes | `Sources/DexDictateKit/Capture/AudioDeviceScanner.swift` | working | @Published list for QuickSettings |
| Device failover (user → system default) | yes | `Sources/DexDictateKit/Capture/AudioInputSelectionPolicy.swift` | working | Falls back gracefully |
| Sleep/wake recovery | yes | `AudioRecorderService.swift` | working | Handles NSWorkspace sleep/wake notifications |
| Live mic level (@Published) | yes | `AudioRecorderService.swift` | working | 0.0–1.0, published to main actor |
| Hold-to-talk trigger mode | yes | `TranscriptionEngine.swift` + `InputMonitor.swift` | working | Hotkey down → record, up → transcribe |
| Click-to-toggle trigger mode | yes | `TranscriptionEngine.swift` | working | `TriggerMode` setting |
| Audio resampling to 16 kHz | yes | `Sources/DexDictateKit/Services/AudioResampler.swift` | working | AVAudioConverter method (default) |
| Leading silence trim | yes | `AudioResampler.trimSilenceFast()` | **partial** | `ExperimentFlags.enableSilenceTrim = false` — disabled; noise-floor estimator clips speech onset |
| Trailing silence trim | yes | `AudioResampler.trimTrailingSilenceCalibrated()` | **partial** | Opt-in only (`enableTrailingTrim` flag) |
| Audio file import (drag-and-drop) | yes | `Sources/DexDictateKit/Services/AudioFileImporter.swift` | working | Full-file transcription mode |

---

## Hotkey / Trigger

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Global keyboard event tap | yes | `Sources/DexDictateKit/Permissions/InputMonitor.swift` | working | CGEvent tap on `.maskReleased` |
| Hotkey binding UI | yes | `Sources/DexDictate/ShortcutRecorder.swift` | working | Custom global shortcut recorder |
| Keyboard trigger support | yes | `InputMonitor.swift` | working | Any key configurable |
| Middle mouse button trigger | yes | `InputMonitor.swift` | working | Button 2 |
| Right mouse button trigger | yes | `InputMonitor.swift` | working | Button 3 |
| Event tap retry on failure | yes | `InputMonitor.swift` | working | Exponential backoff up to 5s |
| `userShortcut` setting | yes | `AppSettings.swift` | working | Supersedes legacy `inputButton` |

---

## Transcription Pipeline

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Whisper local transcription | yes | `Sources/DexDictateKit/Services/WhisperService.swift` | working | whisper.cpp via SwiftWhisper |
| Embedded tiny.en model (74 MB) | yes | `Sources/DexDictateKit/Resources/tiny.en.bin` | working | English-only, bundled in app |
| Core ML encoder detection | yes | `WhisperService.swift` | working | Falls back to CPU if no mlmodelc present |
| 3 decode profiles (speed/balanced/accuracy) | yes | `WhisperService.swift` | working | Configurable at runtime |
| Multi-pass accuracy fallback | yes | `WhisperService.swift` (Accuracy profile) | working | `greedy.best_of = 2`, temperature retries |
| Phase vocoder speed-up | yes | `WhisperService.swift` (Speed profile) | working | Halves frequency bins |
| Token cap (max_tokens = 128) | yes | `WhisperService.swift` | working | Prevents runaway decodes on noise |
| Single-segment live mode | yes | `WhisperService.swift` | working | `single_segment = true` for live dictation |
| File transcription mode (multi-segment) | yes | `WhisperService.swift` | working | `single_segment = false` for imports |
| Transcription cancellation | yes | `WhisperService.swift` (transcriptionTask) | working | Prior task cancelled before new one |
| Disk space pre-check | yes | `WhisperService.swift` | working | Requires model size + 100 MB margin |
| Model SHA256 verification | yes | `WhisperModelCatalog.swift` | working | Via catalog |
| Model catalog (multi-model) | yes | `WhisperModelCatalog.swift` | working | Enumerate available + downloaded models |
| Live transcript (partial progress) | yes | `TranscriptionEngine.liveTranscript` | working | Updated via delegate callbacks |
| Accuracy retry (re-transcribe with higher quality) | yes | `TranscriptionEngine.swift` | working | On-demand via ControlsView |
| No cloud transcription | yes | (entire codebase) | working | No URLSession, no cloud APIs |

---

## Engine State Machine

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Explicit lifecycle FSM | yes | `Sources/DexDictateKit/EngineLifecycle.swift` | working | 6 states, all transitions logged |
| State: stopped → initializing → ready | yes | `EngineLifecycle.swift` | working | |
| State: ready → listening → transcribing → ready | yes | `EngineLifecycle.swift` | working | |
| State: any → error (input monitor fail) | yes | `EngineLifecycle.swift` | working | |
| Published engine state (@Published) | yes | `TranscriptionEngine.state` | working | Drives all UI state |
| Activity phase (fine-grained) | yes | `TranscriptionEngine.activityPhase` | working | idle/ready/listening/captured/resampling/transcribing/retryingAccuracy |
| Silence countdown (@Published) | yes | `TranscriptionEngine.silenceCountdown` | working | Shows auto-stop timer in UI |

---

## Command Processing

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| "scratch that" voice command | yes | `Sources/DexDictateKit/CommandProcessor.swift` | working | Deletes last sentence from history |
| "all caps" voice command | yes | `CommandProcessor.swift` | working | Uppercases content before command |
| "new line" / "next line" voice command | yes | `CommandProcessor.swift` | working | Inserts `\n` |
| "Dex [keyword]" custom hotword | yes | `CommandProcessor.swift` + `CustomCommandsManager.swift` | working | User-defined hotword → insert text |
| Regex word-boundary matching | yes | `CommandProcessor.swift` | working | Case-insensitive, boundary-aware |
| Custom commands persistence | yes | `CustomCommandsManager.swift` (UserDefaults) | working | JSON serialized |

---

## Vocabulary

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Custom vocabulary correction | yes | `Sources/DexDictateKit/VocabularyManager.swift` | working | User-defined text replacements |
| Bundled vocabulary packs | yes | `Sources/DexDictateKit/Vocabulary/BundledVocabularyPacks.swift` | working | Profile-driven |
| Layered priority (custom overrides bundled) | yes | `VocabularyManager.swift` | working | Deduplicated by lowercase key |
| Word-boundary enforcement | yes | `VocabularyManager.swift` | working | Only applies at word boundaries |
| Vocab persistence (UserDefaults JSON) | yes | `VocabularyManager.swift` | working | |
| Profile-driven vocab selection | yes | `ProfileManager.swift` | working | Aussie variant, standard, etc. |

---

## Output / Text Insertion

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Clipboard copy | yes | `Sources/DexDictateKit/Output/ClipboardManager.swift` | working | NSPasteboard |
| Clipboard paste (Cmd+V simulation) | yes | `ClipboardManager.copyAndPaste()` | working | Copies then sends Cmd+V CGEvent |
| Accessibility API insertion | yes | `OutputCoordinator.swift` | working | AXUIElement direct text insertion |
| Per-app insertion override | yes | `AppInsertionOverridesManager.swift` | working | Bundle ID → mode mapping |
| Sensitive context detection | yes | `Sources/DexDictateKit/Output/SecureInputContext.swift` | working | Password fields, secure input |
| Safe mode (copy-only) | yes | `Sources/DexDictateKit/Settings/SafeModePreset.swift` | working | Snapshot + conservative preset |
| Auto-paste toggle | yes | `AppSettings.autoPaste` | working | Global on/off |
| Profanity filter | yes | `Sources/DexDictateKit/ProfanityFilter.swift` | working | Bundled list + user additions/removals |
| Output coordinator pattern (protocol) | yes | `OutputCoordinator.swift` | working | Testable via mock injection |

---

## Settings / Configuration

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Preferences (all @AppStorage) | yes | `Sources/DexDictateKit/Settings/AppSettings.swift` | working | ~500+ lines, comprehensive |
| Settings migration / versioned keys | yes | `Sources/DexDictateKit/Settings/SettingsMigration.swift` | working | Handles schema upgrades |
| Safe mode preset | yes | `SafeModePreset.swift` | working | Snapshot/restore |
| Quick settings panel | yes | `Sources/DexDictate/QuickSettingsView.swift` | working | Embedded in popover |
| Utterance-end presets (stable/responsive/custom) | yes | `AppSettings.swift` | working | Controls tail delay + trim params |
| Experiment flags | yes | `Sources/DexDictateKit/ExperimentFlags.swift` | working | Runtime tuning, not hardcoded |

---

## UI / UX

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Menu bar icon (idle variants) | yes | `DexDictateApp.swift` (MenuBarStatusLabel) | working | Pulsing red while recording |
| Menu bar display mode | yes | `AppSettings.menuBarDisplayMode` | working | micAndText / micOnly / customIcon / logoOnly / emojiIcon |
| Custom menu bar icon | yes | `MenuBarIconController.swift` | working | User image selection + preview |
| Watermark backgrounds | yes | `WatermarkAssetProvider.swift` | working | Profile-driven, opacity 0.12 |
| Floating HUD (detached window) | yes | `Sources/DexDictate/FloatingHUD.swift` | working | Mic level, status, watermark |
| Transcription history (inline) | yes | `HistoryView.swift` | working | 5 most recent; expandable |
| History window (detached, searchable) | yes | `HistoryWindow.swift` | working | Full history + WPM stats |
| Help/FAQ window | yes | `HelpView.swift` + `HelpWindowController.swift` | working | Native window with screenshots |
| Flavor ticker | yes | `FlavorTickerView.swift` | working | Animatable, profile-driven |
| Stats ticker (WPM, words, duration) | yes | `StatsTickerView.swift` | working | Session statistics |
| Popover size | yes | `DexDictateApp.swift` | working | Fixed 320 × 540 pt |
| Design tokens | yes | `SurfaceTokens.swift` | working | Centralized colors/spacing |

---

## Profiles

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Standard profile | yes | `AppProfile.swift` + `ProfileManager.swift` | working | Default |
| Aussie English profile | yes | `AppProfile.swift` | working | Alternate vocabulary + watermarks |
| Profile-driven watermarks | yes | `WatermarkAssetProvider.swift` | working | Per-profile curated pools |
| Profile-driven flavor quotes | yes | `FlavorQuotePacks.swift` | working | |
| Profile selection persisted | yes | `AppSettings.localizationMode` | working | @AppStorage |

---

## Benchmarking / Diagnostics

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| Model benchmarking (WER, P95 latency) | yes | `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift` | working | Full corpus evaluation |
| Benchmark corpus | yes | `sample_corpus/` | working | Audio + reference transcripts |
| Benchmark baseline gate | yes | `benchmark_baseline.json` | working | WER and latency thresholds |
| Adaptive benchmark controller | yes | `DexDictateApp.swift` (AdaptiveBenchmarkController) | working | Triggers idle benchmarks |
| Benchmark results store | yes | `DexDictateApp.swift` (BenchmarkResultsStore.shared) | working | Persisted results |
| WAV writer (corpus capture) | yes | `BenchmarkWAVWriter.swift` | working | Capture reference recordings |
| VerificationRunner CLI | yes | `Sources/VerificationRunner/main.swift` | working | 8 verification paths, 200+ fuzz cases |
| Resource bundle validation | yes | `Safety.swift` | working | Validates tiny.en.bin + profanity list present |
| Safety logging | yes | `Safety.swift` | working | NSLog + local files |
| App Support directory setup | yes | `Safety.setupDirectories()` | working | Called at app init |
| Security audit | yes | `SECURITY_AUDIT_REPORT.md` | working | External audit completed |

---

## CI / Build

| Feature | Present | Location | Status | Notes |
|---|---|---|---|---|
| GitHub Actions CI | yes | `.github/workflows/ci.yml` | **partial** | Runs build + tests but minimal (see audit notes) |
| SPM build | yes | `Package.swift` | working | swift-tools-version 5.9 |
| Pinned dependency (SwiftWhisper) | yes | `Package.resolved` | working | Specific commit hash |
| Canonical build script | yes | `build.sh` | working | 242 lines; full release pipeline |
| Architecture enforcement (arm64 only) | yes | `build.sh` | working | Rejects Rosetta x86_64 |
| Code signing | yes | `build.sh` | working | "DexDictate Development" cert or ad-hoc fallback |
| Release packaging (.dmg, .zip, SHA256) | yes | `build.sh` | working | `--release` flag |
| Release artifact validation | yes | `scripts/validate_release.sh` | working | Arch, signing, entitlements, hashes |
| SwiftLint | yes | `.swiftlint.yml` | working | Configured; not in CI (lint not run by CI) |

---

## Missing / Absent Features

| Feature | Status | Notes |
|---|---|---|
| Streaming / real-time transcription | absent | By design: batch model after trigger release |
| Non-English language support | absent | tiny.en is English-only; would need different model |
| Cloud transcription fallback | absent | By design (local-only) |
| Linux support | absent | macOS 14+ only; AppKit, CoreAudio, AVFoundation, CGEvent not portable |
| Auto-update mechanism | absent | No Sparkle, no update check |
| Telemetry / analytics | absent | By design |
| Multi-language model download | absent | UI exists in catalog but limited to tiny.en in practice |
| Streaming output (type-as-you-speak) | absent | Would require streaming Whisper mode |
| SwiftLint in CI | absent | `.swiftlint.yml` exists but CI does not run lint |
| UI snapshot tests | absent | No XCUITest or SwiftUI snapshot test harness |
