# DexDictate Fable 5 Assessment Packet

## 1. Target Artifact Requested From Fable 5

State that Fable 5 should produce:
- A UI/UX recovery plan
- A behavior-preserving refactor strategy
- A feature-surfacing plan
- A mode/settings/navigation architecture
- A risk-aware implementation roadmap
- Google Antigravity-ready implementation packets

Fable must not be asked to directly implement code in this pass.

## 2. Intended Fable Task

Assess DexDictate as a macOS-native local-first dictation product with existing transcription, correction, retry, accuracy, history, toggle, command, vocabulary, audio recovery, output-routing, diagnostics, and remote Ollama provider requirements. Produce a UI/UX recovery and behavior-preserving refactor plan that surfaces existing features without losing functionality.

## 3. Source Inventory

- **Repository Root:** `/Users/andrew/DexDictate_MacOS.nosync`
- **Branch:** `speech-engine-exploration-benchmarks`
- **Inspected Commit Hash:** `9eea598f11b77352f094af68ebd4f71f36dac0ef`
- **Preservation Commit Hash:** `9eea598f11b77352f094af68ebd4f71f36dac0ef`
- **Audit Documents Created:**
  - [DexDictate_Fable5_Assessment_Packet.md](file:///Users/andrew/DexDictate_MacOS.nosync/DexDictate_Fable5_Assessment_Packet.md)
  - [DexDictate_Feature_Function_Baseline.md](file:///Users/andrew/DexDictate_MacOS.nosync/DexDictate_Feature_Function_Baseline.md)
  - [DexDictate_Feature_Loss_Checklist.md](file:///Users/andrew/DexDictate_MacOS.nosync/DexDictate_Feature_Loss_Checklist.md)
  - [DexDictate_Remote_Ollama_Stack_Baseline.md](file:///Users/andrew/DexDictate_MacOS.nosync/DexDictate_Remote_Ollama_Stack_Baseline.md)
- **Tests/Validation Commands Run:**
  - `swift test` (381/382 passed; 1 environmental failure in `MainActorActionTests.testRunAsyncExecutesOnMainActor` on line 37)
- **Key Source Files Inspected:**
  - [Package.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Package.swift)
  - [DexDictateApp.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/DexDictateApp.swift)
  - [TranscriptionEngine.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift)
  - [QuickSettingsView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/QuickSettingsView.swift)
  - [AudioRecorderService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderService.swift)
  - [AudioRecorderRecoverySupport.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift)
  - [WhisperService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/WhisperService.swift)
  - [OutputCoordinator.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/OutputCoordinator.swift)
  - [ClipboardManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/ClipboardManager.swift)
  - [SecureInputContext.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/SecureInputContext.swift)
  - [PermissionManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/PermissionManager.swift)
  - [InputMonitor.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/InputMonitor.swift)

## 4. Confirmed Facts

- **Product Purpose:** A local-first menu-bar dictation app utilizing `SwiftWhisper` to run OpenAI Whisper locally. Zero cloud networking for transcription is active in the production engine loop.
- **App Architecture:** A multi-target Swift Package containing a SwiftUI host app target, the core library `DexDictateKit`, the C-exception helper `DexDictateObjCSupport` (catching AVAudioEngine configuration exceptions), and a benchmark/CLI helper `VerificationRunner`.
- **Transcription Pipeline:** Recording runs mono audio captured via `AVAudioEngine`, resampled to 16kHz, trimmed for silence, and processed as a single batch through `WhisperService` on stop. Live preview captions are driven by streaming providers (`Nemotron3.5` or `AppleSpeech`) if enabled, while `WhisperService` produces the final committed text.
- **Recording Modes:** Supports Hold-to-Talk and Click-to-Toggle trigger options bound to mouse buttons (default: Middle Mouse) or keyboard shortcuts. Includes pre-trigger buffering (750ms capture before hotkey down) and adaptive stop tail scheduling.
- **Correction / Accuracy Mode:** Suspiciously short/low-confidence results trigger "Accuracy Retry" (re-running Whisper on the same cached buffer with higher quality params), either automatically or via a prompt button. The "Correction Sheet" allows confirming/editing text before insertion.
- **History / Recovery:** History is loaded/saved locally to app support (`HistoryPersistenceManager.swift`). Supports recovery of previous dictations, "scratch that" (removes last entry from target field and history), and undo-delete.
- **Output Insertion:** Routes text into the frontmost app either via Accessibility APIs (`AXValue` / `AXSelectedText`) or synthetic clipboard paste (Cmd+V). Before pasting, it verifies target activation and element focus to prevent leaking text into incorrect apps. Focus changes or secure-entry fields fall back to copy-only.
- **Audio Recovery:** Observes Core Audio default input device changes and AVAudioEngine configuration changes. Employs `AudioRecorderRecoveryPlanner` with retry delays `[0, 0.2, 0.5, 1.0]`, falling back to the default system microphone on preferred mic stall. Classifies error `-10868` (device invalid) and provides instructions to restart the `coreaudiod` service.
- **UI / Settings:** Main interaction occurs in a menu bar popover containing a footer, inline history, and a folding `QuickSettingsView` with collapsible disclosure cards. Includes a secondary experimental state-first UI featuring a HUD, command palette, and Dexter feed.

## 5. Existing Feature Summary

- **Local Whisper Dictation:** [High Confidence] Fully implemented and exposed.
- **Microphone Selection / Fallback:** [High Confidence] Fully implemented. Selectable in UI. Automatically falls back to default if preferred device fails.
- **Silence Timeout:** [High Confidence] Implemented. Slider in Input settings.
- **Auto-Paste & Accessibility Insertion:** [High Confidence] Fully implemented. Toggle in UI. Fallbacks and frontmost-app verification are active.
- **Copy-Only Secure-Field Fallback:** [High Confidence] Implemented in code. Automatically detects password fields.
- **Per-App Insertion Rules:** [High Confidence] Fully implemented. Managed via detached window sheet.
- **Inline & Detached History:** [High Confidence] Implemented. Expandable popover feed and a full-featured detached window.
- **Custom Vocabulary & Voice Commands:** [High Confidence] Fully implemented. Managed via detached sheets.
- **Onboarding / Permission Validation:** [High Confidence] Runs on first launch. Polls Microphone, Accessibility, and Input Monitoring permissions.
- **Adaptive Tail Delay & Silence Trim:** [High Confidence] Implemented in code and exposed under Speed & Accuracy settings.
- **Accuracy Retry:** [High Confidence] Implemented. Allows re-running the last audio buffer with balanced/accuracy parameters when Whisper returns poor results.
- **Core Audio Recovery:** [High Confidence] Automatically handles route shifts.
- **Reset Core Audio UI:** [High Confidence] Button in Advanced settings that executes `killall -9 coreaudiod` via administrator prompt.
- **Profile / Localization Presets:** [High Confidence] Australian and Canadian profiles load custom vocabulary and quote packs.
- **Floating HUD & Tickers:** [High Confidence] Implemented. HUD displays level meter/state. Popover shows rotating flavor quote ticker.
- **Benchmark / Model Promotion:** [High Confidence] Capture window records prompts to build a local validation corpus. promotion policy automatically swaps models.

## 6. Hidden or Poorly Surfaced Features

- **Accuracy Retry:**
  - *Current Evidence:* Code implementation in [TranscriptionEngine.swift:994-1100](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/TranscriptionEngine.swift#L994-1100).
  - *Why it matters:* Prevents Whisper from generating gibberish/empty output on difficult audio.
  - *UX Issue:* The trigger conditions are fully automated or show a dynamic button under very complex conditions.
  - *Proposed Label:* "Smart Quality Retry"
- **Context Injection:**
  - *Current Evidence:* Code implementation in [AppSettings.swift:262](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Settings/AppSettings.swift#L262) and [FocusedTextReader.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/FocusedTextReader.swift).
  - *Why it matters:* Lets Whisper read the last 200 characters of the target field to prime its vocabulary.
  - *UX Issue:* Hidden inside the collapsible "Accuracy & Speed" card.
  - *Proposed Label:* "Prime Whisper with Surrounding Field Text"
- **Voice Commands & Custom Vocabulary:**
  - *Current Evidence:* Buttons in "Input" disclosure card opening independent AppKit panels.
  - *Why it matters:* Essential for custom macros and domain bias.
  - *UX Issue:* Hidden in the "Input" section, even though vocabulary is an output/formatting feature.
  - *Proposed Label:* "Vocabulary & Voice Commands Manager"
- **Per-App Insertion Overrides:**
  - *Current Evidence:* Card button in "Output" card opening detached window.
  - *Why it matters:* Prevents pasting errors in specific apps.
  - *UX Issue:* Folded at the bottom of the "Output" section.
  - *Proposed Label:* "App-Specific Insertion Rules"

## 7. UI/UX Crisis Summary

The app is functionally rich but suffers from a **discoverability crisis** and **navigation bloat**:
1. **Collapsible card fatigue:** Almost all configurations are nested inside one massive scrolling list of `QuickSettingsView` cards. Important features (Vocabulary, Overrides) open separate detached windows.
2. **Duplicate UI paths:** The experimental "State-first Popover" replaces the main UI, but the "Feature Hub" duplicates standard settings controls using different visual styles. This splits the code maintenance.
3. **Terminology overlap:** The UI uses terms like "Balanced", "Accuracy Preset", "Accuracy Retry", "Smart Retry", and "Auto-promotion" interchangeably, creating high cognitive load.
4. **Visual Review Needed:** Visual layouts for the popovers, the HUD, the detached history window, and the custom commands sheets need user/designer review to align typography and margins.

## 8. Current Architecture Map

- **App Entry Point:** [DexDictateApp.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/DexDictateApp.swift)
- **Menu Bar UI Shell:** [MenuBarIconController.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/MenuBarIconController.swift)
- **Settings Store:** [AppSettings.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Settings/AppSettings.swift)
- **Audio Capture & Recovery:** [AudioRecorderService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderService.swift) & [AudioRecorderRecoverySupport.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift)
- **Transcription Registry & Providers:** [TranscriptionProviderRegistry.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Transcription/TranscriptionProviderRegistry.swift)
- **Whisper Service:** [WhisperService.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Services/WhisperService.swift)
- **Output insertion:** [OutputCoordinator.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Output/OutputCoordinator.swift)
- **History persistence:** [HistoryPersistenceManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/HistoryPersistenceManager.swift)
- **Permissions:** [PermissionManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/PermissionManager.swift)
- **Quartz Event Tap:** [InputMonitor.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Permissions/InputMonitor.swift)

## 9. Magic Echo Comparison Summary

- **Local-first system-wide dictation:** Already implemented (Whisper + Quartz Event Tap).
- **Raw transcription:** Already implemented (Whisper compatibility mode).
- **Smart/LLM-processed transcription:** Missing (planned for remote Ollama stack).
- **Raw fallback when smart fails:** Missing (needs remote provider connection monitoring).
- **On-screen awareness / Multi-window context:** Missing.
- **Voice commands / custom vocabulary:** Already implemented.
- **Past Echoes / History:** Already implemented (inline + detached window).
- **Remappable hotkeys:** Already implemented (ShortcutRecorder).
- **Silence detection thresholds:** Already implemented (silenceTimeout slider).
- **Local/offline model dependency:** Already implemented (tiny.en.bin / imported GGML models).
- **macOS Permissions:** Already implemented (Accessibility, Input Monitoring, Microphone).
- **OpenAI-compatible / Local Ollama settings:** Missing in runtime (to be added).

> [!WARNING]
> Do not adopt Magic Echo terminology wholesale. Prefer DexDictate’s real feature evidence and then propose clearer user-facing naming.

## 10. Remote Ollama Stack Requirements

- **Client Mac (MacBook):**
  - Runs DexDictate app.
  - Does not need to run the LLM locally.
  - Reaches Ollama on remote machine via local tunnel endpoint `http://127.0.0.1:11435/v1` (to prevent collision with MacBook-local instances).
- **Remote Inference Mac (BigMac):**
  - Runs Ollama server locally at `http://127.0.0.1:11434/v1`.
  - Performs actual model inference.
- **SSH Tunnel Command:**
  ```bash
  ssh -N -L 11435:127.0.0.1:11434 user@bigmac-ip
  ```
- **Product Setup:** The app should allow the user to configure the Local Tunnel Port (defaulting to 11435), Model Name, API Key placeholder (`ollama`), and optional remote host notes.

## 11. Constraints for Fable

- **No full rewrite:** Do not recommend moving away from the Swift Package Manager or SwiftUI menu-bar architecture.
- **No deletion of features:** Hidden features (Accuracy Retry, Vocabulary, Benchmarks) must be protected, surfaced, and preserved.
- **No Agent Frameworks:** Keep inference queries as standard OpenAI-compatible API calls.
- **No cloud-only requirements:** Maintain local-first Whisper as the baseline fallback.
- **Do not combine refactoring passes:** UI layout changes must be decoupled from risky audio-capture and Core Audio recovery modifications.

## 12. Non-Goals

- No active Swift code implementation or directory modification in this pass.
- No Windows/Linux support.
- No commercial metering or licensing systems.
- No active-window screen recording/awareness implementation until existing UI/UX is stabilized.

## 13. Unknowns / Missing Inputs

- **UI Screenshots:** Visual previews of the popovers are unavailable to the remote model. Visual QA requires human validation or visual scripts.
- **MainActorActionTests Failure:** The test `testRunAsyncExecutesOnMainActor` fails due to an environmental async timing discrepancy on lines 37-40 of `MainActorActionTests.swift`.
- **Tailscale/SSH Setup:** The local app cannot automate SSH tunnel creation; it must assume the user configures the tunnel externally.

## 14. Contradictions or Tensions

- **Local-first vs. Remote Inference:** The app's core promise is fully local-only dictation, but adding remote Ollama requires explaining to the user that audio is transmitted to a trusted home server (BigMac) over SSH/Tailscale, not public clouds.
- **Feature Richness vs. Screen Real Estate:** The popover is tiny (standard menu-bar width), yet it nests dozens of advanced controls. Surfacing them without creating visual clutter is a major challenge.

## 15. Fable Stopping Point

Fable 5 must stop after producing:
1. A **UI/UX recovery plan** with mockups/wireframes description.
2. A **settings reorganization proposal** aligning terminology.
3. A **behavior-preserving refactor strategy** detailing file movements.
4. **Phased implementation packets** for Google Antigravity execution.

## 16. Review Method

1. Human review and sign-off on the Fable 5 plan by Andrew.
2. Sequential execution of implementation packets by Google Antigravity.
3. Post-execution verification via `swift test` and `DexDictate_Feature_Loss_Checklist.md`.

---

## 17. Paste-Ready Fable Context Block

```markdown
### TASK DESCRIPTION
Assess DexDictate (macOS local Whisper dictation app) and design a UI/UX recovery + settings reorganization plan that surfaces existing hidden features (Vocabulary, Per-App rules, Context Injection, Accuracy Retry, Benchmarking) without changing core engine, audio capture, or recovery logic. Design a roadmap for future remote Ollama integration using SSH tunnels.

### SYSTEM SPECIFICATION
- OS: macOS 14+
- Frameworks: SwiftUI + AppKit (MenuBarExtra)
- Core Dependencies: SwiftWhisper (whisper.cpp), FluidAudio (CoreML ASR)
- Project Structure: Swift Package Manager with Library + Executable targets

### CONSTRAINTS
- No code changes. No deletions. No agent frameworks.
- Local Whisper is the primary fallback.
- Remote Ollama runs via client-local SSH tunnels (e.g. MacBook 127.0.0.1:11435 -> BigMac 127.0.0.1:11434).

### DELIVERABLES EXPECTED
- UI/UX Recovery & Terminology Consolidation Plan.
- Reorganized Settings Taxonomy.
- Behavior-Preserving Refactor Roadmap.
- Phased implementation packets for Google Antigravity execution.
```
