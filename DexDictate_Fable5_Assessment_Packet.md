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
  - `swift test` (Reconciled: 382/382 passed with 0 failures; a prior transient `MainActorActionTests.testRunAsyncExecutesOnMainActor` failure was observed historically but passed cleanly in the reconciled run)
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
## 11. Dexter Identity Preservation Requirements

Dexter is the organizing identity of DexDictate, not a cosmetic theme layer. 

> [!IMPORTANT]
> **Dexter is the point. The product can become cleaner, more professional, and more shippable without becoming beige.**

Dexter-related features are non-negotiable core product requirements. Fable's UI/UX recovery plan must protect, integrate, and preserve these elements rather than sanitizing the app into a generic dictation utility.
- The interactive onboarding wizard, launch animation, RSS-style marquee ticker, randomized background watermarks, regional profile imagery, and Dexter quote/identity systems must be preserved.
- Fable is encouraged to reorganize, clarify, modernize, and polish these elements.
- Fable must **not** remove, genericize, bury, or flatten them.

### Confirmed Dexter-Related Features & Assets:
1. **Interactive Onboarding Wizard:**
   - *Code Paths:* [OnboardingView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/OnboardingView.swift)
   - *State Flow & Screens:* Multi-page wizard (WelcomePage, PermissionsPage, ShortcutPage, CompletionPage) using custom looping/reverse-looping player animations (`OnboardingPlayerRepresentable`).
   - *Bundled Video Assets:* 
     - `OnboardingWelcomeAnimation.mp4`
     - `OnboardingPermissionsAnimation.mp4`
     - `OnboardingShortcutAnimation.mp4`
     - `OnboardingCompletionAnimation.mp4`
   - *User-Facing Purpose:* Introduces the product, requests systems permissions (Accessibility, Input Monitoring, Microphone), lets users record a trigger hotkey, and validates audio input.
   - *Preservation Requirement:* Must be preserved as a core first-run experience; do not treat it as disposable setup scaffolding.

2. **Existing Imagery & Visual Identity:**
   - *Code Paths:* [WatermarkAssetProvider.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift)
   - *Asset Inventory:* Bundled PNG image files under resource bundle:
     - `DexDictate_active_processing_label__processing.png`, `DexDictate_active_recording_label__recording.png`
     - `DexDictate_app_settings.png`
     - `DexDictate_benchmark__failed__variant_a.png` / `variant_b.png`
     - `DexDictate_benchmark__running__variant_a.png` / `variant_b.png`
     - `DexDictate_copied_to_clipboard.png`
     - `DexDictate_error__misunderstood__variant_a.png`
     - `DexDictate_filter_profanity.png`
     - `DexDictate_floating_hud_window__variant_a.png` / `variant_b.png`
     - `DexDictate_listening__waiting__variant_a.png` / `variant_b.png` / `variant_c.png`
     - `DexDictate_loading_ai_model.png`
     - `DexDictate_mic_only_icon__variant_a.png` / `variant_b.png`
     - `DexDictate_mode__aussie_profile.png`
     - `DexDictate_mode__canadian_profile__variant_a.png` / `variant_b.png`
     - `DexDictate_offline_privacy__variant_a.png` / `variant_b.png`
     - `DexDictate_onboarding__completion.png`
     - `DexDictate_onboarding__shortcut_selection__variant_a.png` / `variant_b.png`
     - `DexDictate_onboarding__welcome__variant_a.png` / `variant_b.png`
     - `DexDictate_processing__typing__variant_a.png` / `variant_b.png` / `variant_c.png`
     - `DexDictate_random_cycle__headphones_portrait.png`
     - `DexDictate_random_cycle__red_button_prompt.png`
     - `DexDictate_random_cycle__side_eye_pose__variant_a.png` / `variant_b.png` / `variant_c.png`
     - `DexDictate_random_cycle__smiley_mask_splatter__variant_a.png` / `variant_b.png` / `variant_c.png`
     - `DexDictate_random_cycle__standing_pose__variant_a.png` / `variant_b.png` / `variant_c.png`
     - `DexDictate_result_feedback_badge__variant_a.png` / `variant_b.png`
     - `DexDictate_start_dictation__variant_a.png`
     - `DexDictate_success__saved__variant_a.png` / `variant_b.png`
     - `DexDictate_transcribe_file__variant_a.png` / `variant_b.png`
     - `DexDictate_transcription_history__collapsed.png`
     - `DexDictate_transcription_history__expanded__variant_a.png` / `variant_b.png`
     - `DexDictate_trigger_mode__hold_to_talk__variant_a.png` / `variant_b.png`
     - `DexDictate_undo_removal__variant_a.png` / `variant_b.png`
     - Canadian regional icons: `dexdictate-icon-canada-01.png` to `-05.png`
     - Australian regional icons: `dexdictate-icon-aussie-01.png` to `-02.png`
   - *UI Location:* Rendered in the popover background, HUD, settings pages, and onboarding screens.
   - *Preservation Requirement:* Future UI designs must preserve these assets, paths, and their visual presence.

3. **RSS-Style News Marquee Ticker:**
   - *Code Paths:* [FlavorTickerView.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/FlavorTickerView.swift) and [FlavorQuotePacks.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Quotes/FlavorQuotePacks.swift)
   - *Current Behavior:* Always-scrolling marquee at the top of the popover displaying short flavor lines. Sourced locally from regional quote packs based on active profile (`standard`, `canadian`, `aussie`), with no external network requests.
   - *Preservation Requirement:* Do not remove or hide the RSS-style marquee ticker during refactor planning.

4. **Recurring Randomized Dexter Background Images:**
   - *Code Paths:* [WatermarkAssetProvider.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift) and [ProfileManager.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Profiles/ProfileManager.swift)
   - *Current Behavior:* Selects randomized watermarks (avoiding immediate repetition) and updates them via `refreshDynamicContent()` on events/clicks. Rendered at low opacity as backdrops.
   - *Preservation Requirement:* Must be preserved as a core brand feature, not treated as cosmetic clutter.

5. **Launch Animation:**
   - *Code Paths:* [LaunchIntroController.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictate/LaunchIntroController.swift)
   - *Current Behavior:* Selects randomly from `LaunchAnimation_01.mp4` through `LaunchAnimation_08.mp4`, plays muted at 1.5x speed in a floating overlay panel, holds for 1.5s on the final brand card, and animates/shrinks away. Includes overlay text fallback.
   - *Preservation Requirement:* Future UI designs may improve its presentation (e.g. alignment or window levels) but must not remove the launch animation.

### Refactor Risks:
- Accidentally sanitizing the app's playful personality during a settings panel redesign.
- Breaking the custom video loops and player states inside `OnboardingView` or `LaunchIntroController` (which use specific AppKit overlays and speed scaling).
- Failing to load assets from the resources bundle due to package folder relocations.

### What Fable May Improve:
- Reorganize settings cards, simplify hotkey mappings, layout alignment, typography, and tab organization.
- Improve the visual integration of the RSS-style marquee ticker to match professional macOS design standards.

### What Fable Must Not Remove:
- The launch intro panel animations.
- The interactive four-page onboarding wizard.
- The randomized Dexter watermark backdrops and regional localization profiles.
- The top-scrolling RSS-style ticker.

## 12. Live Transcription Requirement

Live transcription is a key product feature request that remains unresolved.

### Current Product State:
- DexDictate's production pipeline relies primarily on **batch/final transcription** (the audio is recorded, stopped, resampled, transcribed using Whisper, and finally typed or copied).
- **Parakeet ASR streaming** was attempted to show text as the user speaks. However, the performance and reliability did not meet expectations (causing partial stability issues and CPU contention).
- **Do not treat live transcription as solved.** Parakeet was a partial/unsuccessful path that needs reassessment.

### Requested Modes to Evaluate:
- **Batch Final Transcription:** Record audio silently (or with simple meters), stop capture, transcribe with local Whisper/provider, and insert final text (current baseline).
- **Live Preview Transcription:** Display raw, provisional caption lines inside the HUD or Menu Bar popover while speaking, but do not insert them into the target app until final commit.
- **Live Typing Transcription:** Directly insert/type partial strings into the focused application in real-time as the user is speaking.
- **Hybrid Mode (Recommended):** Show a live preview captions strip during dictation, and replace/commit the final high-accuracy cleaned text only after capture stops.

### Staged Implementation Path Recommendation:
1. **Phase 1: HUD Preview Only.** Establish a low-latency, stable live preview caption strip inside the DexDictate popover/HUD without modifying the cursor.
2. **Phase 2: Whisper Final Commit.** The final Whisper-based transcription remains the only text typed at the cursor (preserves accuracy).
3. **Phase 3: Optional Live Typing.** Introduce live typing at the cursor as an opt-in toggle only after preview stability is proven.
4. **Phase 4: Remote Smart Post-Processing.** Use the remote Ollama layer to clean up the final batch text on stop (not for low-latency live streaming).

### Implementation Risks:
- **Partial Transcript Instability:** Live streams frequently delete, insert, or rewrite preceding tokens, leading to visual flickering.
- **Text Duplication:** Glitches in streaming token boundaries can cause repeating segments.
- **Cursor Drift & Selection Loss:** Typing in real-time can displace the cursor or break target state.
- **Focus Shifts:** If the user changes focused fields mid-sentence, live typing will split the text across multiple inputs.
- **Correction Complexity:** Deleting or rewriting typed text dynamically is highly error-prone in macOS Accessibility APIs.
- **Latency & CPU Contention:** Streaming models (Parakeet/Nemotron) can saturate ANE/GPU threads, delaying the final batch Whisper start.
- **User Confusion:** Users may be confused between transient live previews and the final committed text.

### Preservation Rules:
- **No replacement of batch Whisper:** Do not weaken, replace, or compromise the batch Whisper final transcription pipeline while experimenting with live transcription. Local batch Whisper must remain the reliable fallback.
- **Proposals only:** Fable must propose a live transcription architecture and phased implementation strategy, but must not claim live transcription is already solved.

## 13. Andrew’s Product Intent

- **Comfort to Ship:** Andrew is currently blocked from shipping DexDictate because of the current UI/UX discoverability crisis and card fatigue.
- **Not a Generic Tool:** The goal is not to turn DexDictate into a generic, dry dictation utility. The visual identity of Dexter must remain front-and-center.
- **Coherent and Cohesive:** Propose a macOS-native layout that balances a professional, clean utility layout with the playful and distinct Dexter identity.
- **Refactoring Freedom:** Fable is fully authorized to propose restructuring the product menus, renaming settings flags for clarity, shifting settings cards, and designing tabs/submenus. The current UI layout does not need to be preserved.
- **Preservation Gating:** Fable must preserve the underlying audio recovery, clipboard restoration, and text insertion capabilities without changing their functional behaviors.

## 14. Fable Design Freedom and Hard Boundaries

### Fable May:
- Challenge the current menu bar popover structure and recommend standard tabbed settings pages.
- Propose new user-facing mode names and settings labels to resolve terminology overlaps (e.g. rename Accuracy Retry/Smart Retry to "Smart Auto-Correction").
- Propose new feature groupings (e.g. merge Custom Vocabulary and Voice Commands into a single tab).
- Design new progressive disclosure methods to hide advanced benchmark/promotion parameters from normal users.
- Propose sequential, risk-segmented refactor packages for Antigravity to build step-by-step.

### Fable Must Not:
- Recommend deleting any existing features (such as Benchmarking, Context Injection, or Per-App insertion overrides).
- Recommend moving away from SwiftUI/AppKit or Swift Package Manager.
- Recommend replacing local Whisper with cloud services as the primary transcription engine.
- Recommend removing or hiding Dexter identity features (onboarding animations, random backdrops, marquee tickers, launch panel).
- Recommend cloud-only inference or generic heavy agent frameworks (keep it standard OpenAI-compatible API calls).
- Recommend hard-coded hostnames or ports (all local tunnel endpoints must be configurable by the user).
- Conflate live transcription (ASR streaming) with Smart transcription (LLM-based post-processing/cleanup).
- Claim or assume that live transcription is already solved by Parakeet or other local engines.

## 15. UI Screenshot / Visual Evidence Inventory

Since visual screenshots of the popover and settings windows are not currently available to the remote model, they must be marked as **Needed** for visual validation during execution.

| UI Surface | Screenshot Available? | Needed for Fable? | Why |
|---|---|---|---|
| Menu bar popover | No | **Needed** | To assess the initial visual spacing and button hierarchy. |
| Quick Settings cards | No | **Needed** | To review the exact visual structure and card-fatigue scrolling layout. |
| Onboarding wizard | No | **Needed** | To verify that custom looping video overlays render correctly. |
| Launch animation stills | No | **Needed** | To verify that the AVPlayer floating panel overlays properly. |
| Floating HUD | No | **Needed** | To check visual placement and level meter rendering. |
| History window | No | **Needed** | To review the text search and learned correction panels. |
| Vocabulary / Command Editors | No | **Needed** | To assess visual consistency of AppKit detached sheets. |
| Per-app overrides sheet | No | **Needed** | To review app list layout and rule toggles. |
| Benchmark capture window | No | **Needed** | To check golden prompt display and WER scores list. |
| Experimental state-first UI | No | **Needed** | To analyze duplication and decide on UI unification. |

## 16. Test Status Reconciliation

The prior documentation contained minor contradictions regarding test counts and statuses. The test environment has been reconciled:

- **Command Run:** `swift test`
- **Latest Run Result:** Passed cleanly (0 failures, 0 unexpected)
- **Total Tests Executed:** 382 tests
- **Failures Detected:** None.
- **Transient Failures:** `MainActorActionTests.testRunAsyncExecutesOnMainActor` (on lines 37-40) has occasionally failed in previous runs due to transient async scheduler timing delays under high CPU load, but it passed cleanly during the latest audit run.
- **Test Output Log Path:** [task-259.log](file:///Users/andrew/.gemini/antigravity/brain/4b6be22c-8f52-4392-ad1c-e2f5a7322106/.system_generated/tasks/task-259.log)

## 17. Commit Ledger

| Purpose | Commit Hash | Pushed? | Notes |
|---|---|---|---|
| State Preservation Commit | `9eea598f11b77352f094af68ebd4f71f36dac0ef` | Yes | Captured baseline prior to Fable audit. |
| Initial Fable Baselines Commit | `6a96852f6b0344851df8a624f6ea64f661ce0aea` | Yes | Added the first four baselines and assessment packet. |
| Dexter Preservation Update | `a8f1f94de204c1448835a6b7488799d12c867303` | Yes | Added governing Dexter brand constraints. |
| Live Transcription Update | `83a1100208755b4a1fe05dcabeca9e967639feae` | Yes | Formulated live transcription gaps and staged path. |
| Fable Readiness Completion | `900df4cdedbef184e0a3ce9f5ca016763aa22ca5` | Yes | Final Fable packet update with boundaries, screenshots, test details. |

## 18. Constraints for Fable

- **No full rewrite:** Do not recommend moving away from the Swift Package Manager or SwiftUI menu-bar architecture.
- **No deletion of features:** Hidden features (Accuracy Retry, Vocabulary, Benchmarks) must be protected, surfaced, and preserved.
- **No Agent Frameworks:** Keep inference queries as standard OpenAI-compatible API calls.
- **No cloud-only requirements:** Maintain local-first Whisper as the baseline fallback.
- **Do not combine refactoring passes:** UI layout changes must be decoupled from risky audio-capture and Core Core Audio recovery modifications.

## 19. Non-Goals

- No active Swift code implementation or directory modification in this pass.
- No Windows/Linux support.
- No commercial metering or licensing systems.
- No active-window screen recording/awareness implementation until existing UI/UX is stabilized.

## 20. Unknowns / Missing Inputs

- **UI Screenshots:** Visual previews of the popovers are unavailable to the remote model. Visual QA requires human validation or visual scripts.
- **MainActorActionTests Async Timing:** The test `testRunAsyncExecutesOnMainActor` has been resolved/passed, but historically exhibited transient timing dependencies under load on lines 37-40 of `MainActorActionTests.swift`.
- **Tailscale/SSH Setup:** The local app cannot automate SSH tunnel creation; it must assume the user configures the tunnel externally.

## 21. Contradictions or Tensions

- **Local-first vs. Remote Inference:** The app's core promise is fully local-only dictation, but adding remote Ollama requires explaining to the user that audio is transmitted to a trusted home server (BigMac) over SSH/Tailscale, not public clouds.
- **Feature Richness vs. Screen Real Estate:** The popover is tiny (standard menu-bar width), yet it nests dozens of advanced controls. Surfacing them without creating visual clutter is a major challenge.

## 22. Fable Stopping Point

Fable 5 must stop after producing:
1. A **UI/UX recovery plan** with mockups/wireframes description.
2. A **settings reorganization proposal** aligning terminology.
3. A **behavior-preserving refactor strategy** detailing file movements.
4. **Phased implementation packets** for Google Antigravity execution.
5. A **proposed live transcription architecture and phased implementation strategy** (Fable must not claim live transcription is already solved).

## 23. Review Method

1. Human review and sign-off on the Fable 5 plan by Andrew.
2. Sequential execution of implementation packets by Google Antigravity.
3. Post-execution verification via `swift test` and `DexDictate_Feature_Loss_Checklist.md`.

---

## 24. Paste-Ready Fable Context Block

```markdown
### TASK DESCRIPTION
Assess DexDictate (macOS local Whisper dictation app) and design a UI/UX recovery + settings reorganization plan that surfaces existing hidden features (Vocabulary, Per-App rules, Context Injection, Accuracy Retry, Benchmarking) without changing core engine, audio capture, or recovery logic. Design a roadmap for future remote Ollama integration using SSH tunnels. Propose a live transcription architecture and phased implementation strategy (do not assume live transcription is solved).

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
- Live transcription architecture and phased implementation strategy.
```
