# DexDictate Audit Report

**Audit date:** 2026-04-10
**Repository:** `/Users/andrew/Projects/DexDictate_MacOS`
**Version examined:** 1.5.2
**Auditor:** Claude Code (forensic engineering examination)
**Scope:** Architecture, bug sweep, feature inventory, operational readiness

This is a forensic audit. Claims are grounded in direct code inspection. Nothing is invented.

---

## 1. What Is DexDictate Right Now?

DexDictate is a production macOS menu-bar dictation application. It runs locally on macOS 14+ (Apple Silicon arm64), captures audio via AVAudioEngine, transcribes speech using whisper.cpp (tiny.en model, 74 MB bundled), and inserts the resulting text into the foreground application via clipboard paste or the Accessibility API.

It is structured as a Swift Package with three targets:
- `DexDictateKit` — Core library (audio, transcription, permissions, output, settings)
- `DexDictate` — Menu-bar app UI (SwiftUI + AppKit, 27 files)
- `VerificationRunner` — Verification and benchmarking CLI

There is no cloud component, no telemetry, no network calls in the runtime path. The system is intentionally offline-first by design and enforcement.

**Current state:** Working production application (v1.5.2 released). Architecture is coherent and well-maintained.

---

## 2. What Is DexDictate Trying to Be?

Based on code and documentation:
- A local, privacy-first voice dictation tool for macOS power users
- Menu-bar utility with minimal surface area (no persistent main window)
- Plug-in to existing macOS text workflows via clipboard/paste/Accessibility API
- Extensible through profiles (vocabulary variants, UI variants)
- A benchmarking-capable platform for evaluating local transcription quality

It is not trying to be a streaming transcription service, a cloud-backed product, or a cross-platform tool.

---

## 3. What Parts of That Intent Are Already Implemented?

All core intent is implemented:
- Audio capture via AVAudioEngine with device selection and failover
- Local Whisper transcription with 3 decode profiles
- Global hotkey capture via CGEvent tap
- Text output via clipboard + paste, Accessibility API, or copy-only (sensitive context)
- Custom vocabulary correction and voice commands
- Profile system (Standard, Aussie)
- Full onboarding flow with permission handling
- Floating HUD, history window, help window
- Benchmarking pipeline with WER/latency evaluation
- AppIntents (Siri/Shortcuts) integration

---

## 4. What Major Features Are Missing?

| Missing | Notes |
|---|---|
| Non-English language support | tiny.en is English-only; multi-language would require different model |
| Auto-update mechanism | No Sparkle or equivalent |
| Streaming / live transcription | Batch model only; this is a design choice |
| Linux / cross-platform support | Intentionally macOS-only |
| SwiftLint in CI | Config exists, not wired into CI |
| UI snapshot testing | No XCUITest or SwiftUI snapshot harness |
| Leading silence trim (re-enabled) | Disabled (`ExperimentFlags.enableSilenceTrim = false`) pending redesign |

---

## 5. Actual Entrypoints

| Entrypoint | Location | How Invoked |
|---|---|---|
| App lifecycle | `DexDictateApp.swift` (@main) | OS launch / dock / menu bar |
| Engine start | `DexDictateApp.onAppear` → `engine.startSystem()` | At app window open |
| Hotkey trigger | `InputMonitor.swift` (CGEvent tap) | Global keyboard/mouse event |
| VerificationRunner | `Sources/VerificationRunner/main.swift` | `swift run VerificationRunner` or from build artifacts |
| Build | `build.sh` | `./build.sh` |

---

## 6. Where Core Logic Lives

| Subsystem | Primary File |
|---|---|
| Pipeline orchestration | `Sources/DexDictateKit/TranscriptionEngine.swift` (~800 lines) |
| State machine | `Sources/DexDictateKit/EngineLifecycle.swift` |
| Audio recording | `Sources/DexDictateKit/Services/AudioRecorderService.swift` |
| Transcription | `Sources/DexDictateKit/Services/WhisperService.swift` |
| Output delivery | `Sources/DexDictateKit/Output/OutputCoordinator.swift` |
| Settings | `Sources/DexDictateKit/Settings/AppSettings.swift` |
| Permissions | `Sources/DexDictateKit/Permissions/PermissionManager.swift` |

---

## 7. Where Configuration Lives

- **User settings:** `AppSettings.swift` (@AppStorage → UserDefaults)
- **Schema migration:** `SettingsMigration.swift` (versioned keys)
- **Runtime tuning:** `ExperimentFlags.swift` (applied from AppSettings at startup)
- **Build-time config:** `Package.swift`, `build.sh`, `templates/Info.plist.template`
- **Benchmark thresholds:** `benchmark_baseline.json`
- **Dependency pinning:** `Package.resolved`

No environment variables are used in the application runtime. The build script uses environment variables for signing identity and install paths.

---

## 8. Where External Tool Dependencies Are Invoked

The only external binary dependency is whisper.cpp, accessed exclusively through the SwiftWhisper Swift package (not a subprocess call). It is invoked at:

- `Sources/DexDictateKit/Services/WhisperService.swift` — model loading (`Whisper(fromFileURL:)`) and transcription (`transcribe(audioFrames:)`)

There are no subprocess calls (`Process`, `NSTask`, `shell()`) in the app runtime path. Scripts in `scripts/` use `curl` to download models (`fetch_model.sh`), but only during development setup, not at runtime.

---

## 9. Is There a Real Dictation/Transcription Pipeline?

Yes. The pipeline is complete and production-quality.

**Pipeline:**
```
Hotkey down
  → AudioRecorderService.startRecordingAsync() (AVAudioEngine, audioQueue)
  → Samples accumulate in tap buffer
Hotkey up
  → AudioRecorderService.stopAndCollect() → [Float] samples
  → AudioResampler.resampleToWhisper() → 16 kHz samples
  → WhisperService.transcribe() → whisper.cpp inference
  → TranscriptionEngine.handleWhisperResult()
    → CommandProcessor (voice commands)
    → VocabularyManager (text correction)
    → OutputCoordinator (copy/paste/API)
    → TranscriptionHistory.add()
  → Engine returns to .ready
```

Latency: 250–1000ms typical on tiny.en (device-dependent).

---

## 10. Audio Capture — Exact Files/Functions

| Function | File | Purpose |
|---|---|---|
| `startRecordingAsync()` | `AudioRecorderService.swift` | Arms AVAudioEngine tap, begins accumulating samples |
| `stopAndCollect() -> [Float]` | `AudioRecorderService.swift` | Atomically retrieves accumulated samples |
| `AudioDeviceManager.configure(uid:)` | `AudioDeviceManager.swift` | Sets CoreAudio input device |
| `AudioDeviceScanner` (ObservableObject) | `AudioDeviceScanner.swift` | Published list of available devices |
| `AudioInputSelectionPolicy.resolve()` | `AudioInputSelectionPolicy.swift` | User selection → system default failover |

Thread model: All AVAudioEngine operations run on `audioQueue` (dedicated serial DispatchQueue, QoS `.userInitiated`). Tap callback fires on AVAudioEngine internal audio thread. Samples transferred to `_accumulatedSamples` protected by `nonisolated(unsafe)` assertion.

---

## 11. Transcription — Exact Files/Functions

| Function | File | Purpose |
|---|---|---|
| `transcribe(audioFrames:config:)` | `WhisperService.swift` | Submit samples to whisper.cpp |
| `loadModel(url:)` | `WhisperService.swift` | Load .bin model file |
| `loadEmbeddedWhisperModel()` | `TranscriptionEngine.swift` | Load bundled tiny.en.bin from resource bundle |
| `resampleToWhisper(_:fromRate:)` | `AudioResampler.swift` | Resample to 16 kHz via AVAudioConverter |
| `trimTrailingSilenceCalibrated(...)` | `AudioResampler.swift` | Trailing silence trim (opt-in) |
| `loadSamples(from:)` | `AudioFileImporter.swift` | Load audio file for drag-and-drop mode |

---

## 12. Permissions — Exact Files/Functions

| Function | File | Purpose |
|---|---|---|
| `PermissionManager.shared` | `PermissionManager.swift` | Singleton; `accessibilityGranted`, `microphoneGranted`, `inputMonitoringGranted` |
| `startMonitoring()` | `PermissionManager.swift` | Start 2s polling timer (UI variant) |
| `startMonitoring(engine:)` | `PermissionManager.swift` | Runtime variant with engine recovery callback |
| `checkPermissions()` | `PermissionManager.swift` | Inspect actual OS TCC state |
| `InputMonitor.activate()` | `InputMonitor.swift` | Create CGEvent tap (requires accessibility) |
| `InputMonitor` retry | `InputMonitor.swift` | Exponential backoff if tap creation fails |
| `OnboardingValidation.validate()` | `OnboardingValidation.swift` | Returns pass/fail + list of missing permissions |

---

## 13. Onboarding — Exact Files/Functions

| Element | File | Purpose |
|---|---|---|
| `OnboardingView` | `Sources/DexDictate/OnboardingView.swift` | 4-page SwiftUI onboarding |
| `AppSettings.hasCompletedOnboarding` | `AppSettings.swift` | Completion gating (UserDefaults) |
| `AppDelegate.presentOnboardingForDebug()` | `DexDictateApp.swift` | Hidden re-trigger for dev/QA |
| `LaunchIntroController` | `LaunchIntroController.swift` | Startup animation (optional) |

---

## 14. Settings and Quick Settings — Exact Files/Functions

| Element | File | Purpose |
|---|---|---|
| `AppSettings` singleton | `AppSettings.swift` | All user preferences (@AppStorage) |
| `QuickSettingsView` | `Sources/DexDictate/QuickSettingsView.swift` | Popover embedded settings |
| `SettingsMigration` | `SettingsMigration.swift` | Schema evolution handler |
| `SafeModePreset` | `SafeModePreset.swift` | Conservative preset snapshot/restore |
| `ExperimentFlags.applyRuntimeSettings(_:)` | `ExperimentFlags.swift` | Apply tuning from settings at startup |

---

## 15. Output Insertion — Exact Files/Functions

| Function | File | Purpose |
|---|---|---|
| `OutputCoordinator.deliver(_:)` | `OutputCoordinator.swift` | Route to correct delivery mode |
| `ClipboardManager.copy(_:)` | `ClipboardManager.swift` | NSPasteboard write |
| `ClipboardManager.copyAndPaste(_:)` | `ClipboardManager.swift` | Copy then Cmd+V CGEvent |
| `SecureInputContext.detect()` | `SecureInputContext.swift` | AXUIElement inspection for password fields |
| `AppInsertionOverridesManager.effectiveMode(for:)` | `AppInsertionOverridesManager.swift` | Per-app override lookup |

---

## 16. What Parts Are Clean and Reusable?

**Clean and reusable:**
- `DexDictateKit` as a library — clean public API, protocol-based output injection, well-tested
- `TranscriptionEngine` — cohesive coordinator; internal state is well-isolated
- `EngineLifecycle` state machine — could be extracted as a generic FSM utility
- `VocabularyManager` + `CommandProcessor` — clean data-in, text-out interfaces
- `AudioResampler` — stateless utility functions
- `OutputCoordinator` + mock injection — genuinely testable output layer
- `ExperimentFlags` — clean runtime tuning without feature-flag sprawl

---

## 17. What Parts Are Brittle, Duplicated, or Confused?

**Brittle:**

1. **`nonisolated(unsafe)` in `AudioRecorderService`** — `engine` and `_accumulatedSamples` are marked `nonisolated(unsafe)`. The code comment asserts these are only accessed on `audioQueue`, which appears correct from inspection, but this is a code-review guarantee, not a compiler guarantee. A future contributor who misses this constraint could introduce a data race.

2. **2-second permission polling** — Reliable but wasteful. Runs continuously while app is open. Not a bug, but adds background CPU overhead and is not responsive (up to 2s delay after user grants permission).

3. **`restart_app.sh`** — References `DexDictate_V2` (old app name). Will fail entirely. Dead dev tool.

4. **`Info.plist` LSMinimumSystemVersion = 13.0 vs Package.swift `.macOS(.v14)`** — The plist advertises macOS 13 minimum, but Swift Package Manager enforces macOS 14. A user on macOS 13 who sees the Info.plist minimum may attempt to run the app and get a crash, not a graceful error. The plist should read 14.0.

5. **CI does not download the model** — `swift build` on GitHub Actions will succeed only if the model file isn't required at build time (it isn't — it's a runtime resource). But `swift test` will exercise `ResourceBundleTests` which checks for `tiny.en.bin`. This test likely fails on CI without the model. Needs investigation.

**Redundant:**
- `docs/DEXDICTATE_BIBLE.md` and root `BIBLE.md` appear to cover the same material in different forms — small documentation maintenance burden.

**Confused:**
- `DictationError` in `Sources/DexDictateKit/Models/DictationError.swift` is declared `internal` (no access modifier → default internal), not `public`. It cannot be used outside DexDictateKit. This is fine if it's only used internally (it appears to be), but any future test or consumer that needs to match on DictationError cases cannot do so without a public API change.

---

## 18. What Parts Appear Experimental or Abandoned?

| Item | Location | Assessment |
|---|---|---|
| Leading silence trim | `ExperimentFlags.enableSilenceTrim = false` | Disabled with documented reason (noise-floor estimator clips speech onset). Needs redesign before re-enabling. |
| Trailing silence trim | `ExperimentFlags.enableTrailingTrim = false` | Opt-in experimental. Safe to leave as-is. |
| Linear resampler | `ExperimentFlags.resampleMethod` | `.avAudioConverter` is default; `.linear` exists but not recommended |
| `restart_app.sh` | Root directory | Dead — references removed app name `DexDictate_V2` |
| `.tmp_onboarding_review/` | Root directory | Untracked stale UX review directory |
| `output/` | Root directory | 157 MB untracked generated marketing images |

---

## 19. Dead Code

| Symbol | File | Evidence |
|---|---|---|
| `restart_app.sh` | Root | References `DexDictate_V2` — app no longer named that; script has no working path |
| `ExperimentFlags.resampleMethod = .linear` | `ExperimentFlags.swift` | Exists as option but `.avAudioConverter` is always default; `.linear` path appears untested |
| Legacy `inputButton` setting | `AppSettings.swift` | Superseded by `userShortcut`; kept for migration but no longer primary |

No dead classes or functions were identified in the core library — the codebase appears clean of accumulated dead code beyond the items above.

---

## 20. Documentation Accuracy

| Document | Accuracy | Issues |
|---|---|---|
| `README.md` | Good | Installation instructions accurate; recent commit history shows active maintenance |
| `BIBLE.md` | Good | Architecture principles match code |
| `docs/FEATURE_INVENTORY.md` | Good | Updated 2026-04-08; matches code as observed |
| `Info.plist` | **Wrong** | `LSMinimumSystemVersion = 13.0` should be `14.0` (matches Package.swift) |
| `restart_app.sh` | **Wrong** | References `DexDictate_V2` (old name); completely stale |
| `SECURITY_AUDIT_REPORT.md` | Good | External audit; results match observed code posture |
| `VERIFICATION_REPORT.md` | Good | Reflects VerificationRunner output |

---

## 21. Missing Tests

| Missing Test | Risk | Priority |
|---|---|---|
| `ResourceBundleTests` pass on CI (no model) | High — CI may silently skip or fail model tests | High |
| `AudioRecorderService` thread safety | Medium — `nonisolated(unsafe)` is a code-review guarantee only | Medium |
| `OutputCoordinator` with real AX API (integration) | Medium — mock-only tests don't catch OS AX API changes | Medium |
| UI flows (SwiftUI snapshot / XCUITest) | Low for core logic; medium for regression | Low |
| `SwiftLint` in CI | Low (style only, not correctness) | Low |
| `VerificationRunner` online/offline check | Covered (Black Path exists) | Done |

---

## 22. What Could Break on macOS?

| Risk | Scenario |
|---|---|
| CGEvent tap failure | macOS TCC changes, sandboxing policy changes — app falls to `.error` state; recovery exists |
| AVAudioEngine routing change | Device disconnect mid-recording; partially handled (sleep/wake recovery present) |
| AX API insertion failure | Target app changes secure input state between context check and paste; mitigation: copy fallback |
| Model resource missing | If resource bundle assembly fails in custom build, `Safety.swift` will log; app won't crash but transcription will fail |
| SMAppService login item | API is macOS 13+; Package.swift requires 14, so no version mismatch; but macOS behavior varies |
| Permission polling latency | 2s delay after user grants permission before app detects it |

---

## 23. What Could Break on Linux or Non-macOS?

**Everything.** DexDictate uses:
- `AVAudioEngine` (Apple-only)
- `CGEvent` tap (macOS-only)
- `AppKit` / `SwiftUI` (macOS-only)
- `SMAppService` (macOS-only)
- `NSPasteboard` (macOS-only)
- `AXUIElement` Accessibility API (macOS-only)
- `AVCaptureDevice` for microphone (iOS/macOS only)

Linux is not a target and not achievable without a near-complete rewrite of every subsystem.

---

## 24. Non-Portability Assumptions

- arm64 architecture explicitly required in `build.sh` (rejects Rosetta/x86_64)
- `Package.swift` `platforms: [.macOS(.v14)]` — hard minimum
- All audio, UI, permission, and output APIs are Apple-proprietary
- SwiftWhisper wraps whisper.cpp which does support Linux, but the Swift app layer does not

---

## 25. Does Current Structure Support Extension Work Safely?

Yes, with caveats:

**Safe to extend:**
- `DexDictateKit` has clean module boundaries — new subsystems can be added without touching existing ones
- `OutputCoordinator` uses protocol-based injection — new output modes can be added without modifying the coordinator
- `CommandProcessor` is small and isolated — new commands are additive
- `VocabularyManager` layering supports new profile packs without changing merge logic
- `AppSettings` uses @AppStorage — new settings won't conflict with existing ones
- `EngineLifecycle` FSM has explicit transitions — new states require deliberate additions, not silent drift

**Caveats before major extension:**
- Fix `Info.plist` minimum OS version mismatch first (medium risk)
- Verify or fix `ResourceBundleTests` on CI (model not fetched in CI environment)
- Remove or fix `restart_app.sh` (stale reference causes confusion)
- Validate that leading silence trim redesign is tracked — it's mentioned in ExperimentFlags but has no issue/ticket reference

---

## 26. What Would Make Adding Major New Features Unsafe?

Currently only minor risks. The main hazard for future extension:

1. If someone extends `TranscriptionEngine` without understanding `@MainActor` isolation, they could inadvertently create UI/audio thread conflicts
2. If CI continues to not run `SwiftLint`, style drift will accumulate over time
3. If the model resource is not validated in CI, silent resource failures could ship
4. If `nonisolated(unsafe)` in `AudioRecorderService` is misunderstood, a future contributor could introduce a data race

---

## 27. What Must Be Fixed Before Significant Expansion?

In priority order:

1. Fix `Info.plist LSMinimumSystemVersion` to `14.0` (inconsistency with Package.swift)
2. Fix or remove `restart_app.sh` (stale app name causes operational confusion)
3. Verify CI behavior for `ResourceBundleTests` (does it pass without the model on CI runners?)
4. Add SwiftLint to CI (style enforcement closes a gap before new contributors arrive)
5. Document the silence trim redesign requirement formally (ExperimentFlags comment is good but transient)

None of these are blockers for continued core feature work. They are hygiene items.

---

## 28. Safe / Fragile / Broken Zones

### Safe Zone
- `DexDictateKit` library architecture and module structure
- Transcription pipeline (audio → Whisper → text)
- Permission handling (PermissionManager, InputMonitor)
- Output delivery (OutputCoordinator, ClipboardManager)
- Vocabulary and command processing
- Engine state machine (EngineLifecycle)
- AppSettings and migration
- Verification infrastructure (VerificationRunner, 25 test files)
- Benchmarking pipeline

### Fragile Zone
- `nonisolated(unsafe)` guarantees in AudioRecorderService (code-review-only safety)
- Permission polling (2s latency; not notification-based)
- CI completeness (no SwiftLint, model not fetched, minimal validation)
- `Info.plist` OS minimum mismatch
- Silence trim (disabled, needs redesign)

### Broken Zone
- `restart_app.sh` (references removed app name — nonfunctional)
- CI `ResourceBundleTests` (unclear whether model is available; may silently fail)

---

## 29. Top 10 Highest-Value Fixes

| # | Fix | Value |
|---|---|---|
| 1 | Fix `Info.plist LSMinimumSystemVersion` to `14.0` | Closes mismatch; prevents false expectations |
| 2 | Fix or delete `restart_app.sh` | Removes a functional landmine for new contributors |
| 3 | Verify CI ResourceBundleTests model availability | Closes potential silent CI failure |
| 4 | Add SwiftLint step to CI | Enforces consistency before style debt accumulates |
| 5 | Make `DictationError` public or document why it's internal | Closes API surface ambiguity |
| 6 | Add formal tracking (comment or doc) for silence trim redesign | Prevents it being forgotten |
| 7 | Replace permission polling with NSWorkspace/notification hybrid | Better responsiveness, lower background CPU |
| 8 | Gitignore or cleanup `output/` and `.tmp_onboarding_review/` | Reduces repo noise for new contributors |
| 9 | Add CI model download step (or gate test to skip if model missing) | Makes CI trustworthy |
| 10 | Document `nonisolated(unsafe)` AudioRecorderService contract in a code comment block | Makes the thread safety guarantee explicit for future contributors |

---

## 30. Top 10 Highest-Risk Issues

| # | Risk | Severity |
|---|---|---|
| 1 | `ResourceBundleTests` may silently fail on CI (no model fetched) | High |
| 2 | `nonisolated(unsafe)` in AudioRecorderService — data race possible if violated by future contributor | Medium |
| 3 | `Info.plist` OS minimum 13.0 vs actual requirement 14.0 | Medium |
| 4 | `restart_app.sh` stale reference could cause operational confusion in dev workflows | Medium |
| 5 | Permission polling 2s latency — noticeable UX delay after user grants permissions | Low-Medium |
| 6 | SwiftWhisper dependency on external fork (exPHAT/SwiftWhisper) — pinned but external | Low-Medium |
| 7 | Silence trim disabled without formal tracking/issue — risk of staying forgotten | Low |
| 8 | No auto-update mechanism — users on old versions have no notification | Low |
| 9 | `DictationError` internal visibility — limits future testability of error paths | Low |
| 10 | No UI test harness — SwiftUI regressions invisible to CI | Low |

---

## 31. Is the Repository Trustworthy Enough to Build On Right Now?

**Yes.**

DexDictate is a well-engineered, actively maintained macOS application with:
- Clean module separation and explicit architectural boundaries
- Comprehensive unit test suite (25 test files, ~200+ cases)
- A verification runner with 8 distinct validation paths and 200+ fuzz cases
- No TODO/FIXME/HACK comments in active source
- A third-party security audit on record
- No network calls, no telemetry, no undocumented external dependencies
- Pinned dependency versions for reproducible builds
- A canonical build script that validates architecture and assembles bundles correctly

The issues identified are operational hygiene problems (stale script, version mismatch, CI gaps), not architectural defects. They are all fixable in under a day of effort.

**The repository is safe to build on.** The five fixes listed in DEXDICTATE_FIX_PLAN.md should be addressed before significant new development, but none of them block incremental feature work.

---

## Architecture Summary

```
DexDictate.app
├── DexDictateApp (@main)
│   ├── TranscriptionEngine.shared (pipeline coordinator)
│   │   ├── AudioRecorderService (AVAudioEngine, audioQueue)
│   │   ├── WhisperService (whisper.cpp via SwiftWhisper)
│   │   ├── AudioResampler (16 kHz conversion)
│   │   ├── InputMonitor (CGEvent tap)
│   │   ├── OutputCoordinator (copy/paste/AX delivery)
│   │   ├── CommandProcessor (voice command parsing)
│   │   ├── VocabularyManager (text correction)
│   │   └── TranscriptionHistory (session history)
│   ├── PermissionManager.shared (mic/AX/input monitoring)
│   ├── AppSettings (UserDefaults via @AppStorage)
│   └── [UI controllers: HUD, History, Help, MenuBarIcon]
│
├── UI Views (SwiftUI)
│   ├── AntiGravityMainView (popover root, 320×540)
│   ├── OnboardingView (first-run)
│   ├── QuickSettingsView (embedded settings)
│   ├── HistoryView / HistoryWindow
│   ├── FloatingHUD (detached)
│   └── HelpView / HelpWindow (detached)
│
└── VerificationRunner (CLI)
    └── 8 verification paths + benchmark modes
```

**Architecture shape:** Hub-and-spoke. `TranscriptionEngine` is the hub; all pipeline subsystems are spokes with clean boundaries. UI observes engine state via @Published. No bidirectional coupling between UI and pipeline internals.

**Coupling level:** Low. Kit and UI are separate targets; UI only imports Kit via @StateObject injection.

**Cohesion level:** High. Each file has a single, clear responsibility.

**Assessment:** The architecture is coherent, maintainable, and supports long-term expansion without rewrites.
