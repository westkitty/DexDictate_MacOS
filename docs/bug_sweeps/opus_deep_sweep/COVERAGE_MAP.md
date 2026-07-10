# Opus Deep Sweep — Coverage Map

Branch: `speech-engine-exploration-benchmarks`
Starting HEAD: `e9a7f328`
Baseline: `swift build` clean, `swift test` 417 tests / 0 failures.

This sweep is the post-model-selection-closure stabilization pass. Model selection
(BUG-006/BUG-007) is regression-only per the packet and was not reopened — no new defect
found there.

Legend: ✅ inspected, correct · ⚠️ inspected, risk noted (see RISK_REGISTER) · 🔒 forbidden
file, read-only inspection + test coverage only.

## A. Settings window (`Sources/DexDictate/SettingsWindow/`)

| Area | File(s) | Result |
|---|---|---|
| Sidebar → detail routing (BUG-005) | `SettingsRootView.swift`, `SettingsSidebar.swift`, `SettingsPage.swift` | ✅ `selection` is local `@State` (BUG-005 fix intact); `List(selection:)` + switch both react to same source of truth |
| General | `GeneralSettingsPage.swift` | ✅ Status color, sounds, Launch at Login, Floating HUD, menu-bar style, Replay Onboarding, Restore Defaults — all bound to real `AppSettings`/controllers |
| Dictation | `DictationSettingsPage.swift` | ✅ Trigger mode, shortcut recorder, silence timeout, end preset, adaptive tail, browser-media pause, Live Preview toggle — all real bindings |
| Audio & Microphone | `AudioSettingsPage.swift` | ✅ Input device picker, silence trim — real bindings |
| Output & Insertion | `OutputSettingsPage.swift` | ✅ Auto-paste, accessibility insertion, copy-only-sensitive, review-before-insert, profanity filter+editors, per-app rules window — real bindings |
| Vocabulary & Commands | `VocabularyCommandsPage.swift` | ✅ Re-hosts unmodified `VocabularySettingsView`/`CustomCommandsView` |
| Models & Accuracy | `ModelsAccuracyPage.swift` | ✅ (regression-only) Active Dictation Model picker + Model Auto-Promotion + Quality Retry + Context Priming + Context Biasing + Model Library + Benchmark tools — shared `ModelSelectionActions` state; BUG-006/007 intact |
| Smart Cleanup | `SmartCleanupPage.swift` | ⚠️ Correct + honest; API-key keystroke Keychain write is inefficient not incorrect (RISK-003) |
| History | `HistorySettingsPage.swift` | ✅ Open History window, Show Dictation Stats, Persist History — real bindings |
| Dexter & Personality | `DexterPersonalityPage.swift` | ✅ (see section H) |
| Diagnostics & Recovery | `DiagnosticsPage.swift` | ✅ Permission rows, route health, Smart Cleanup status, Safe Mode, Reset Core Audio (NSAlert + full recovery sequence) |
| Advanced | `AdvancedPage.swift` | ✅ Trailing-trim experiment + Nano HUD toggle; retired experimental-UI copy is explanatory only |

## B. Popover

| Area | File(s) | Result |
|---|---|---|
| Slim popover shell | `PopoverRootView.swift` | ✅ Header/ticker/hero/controls/result/history/status/stop/footer; Quit uses NSAlert (BUG-001 fix); Stop button pinned below scroll, above footer (BUG-006B) |
| Hero (idle Start) | `PopoverHeroView.swift` | ✅ Start rendered only when `.stopped` |
| Result / Retry / Learn Correction | `PopoverResultView.swift` | ⚠️ Retry/Undo/Learn-Correction wired correctly; Learn-Correction uses `.sheet` from a MenuBarExtra popover — unverified live (RISK-001) |
| History teaser | `PopoverHistoryTeaser.swift` | ✅ |
| Chips / model dropdown | `DexStateFirstComponents.swift` | ✅ Model dropdown shares `ModelSelectionActions` with Settings; three-section grouping intact |

## C. Model selection — regression only

| Area | File(s) | Result |
|---|---|---|
| Catalog display names | `WhisperModelCatalog.swift` | ✅ `Base (Multilingual)`/`Small (Multilingual)` disambiguation present (BUG-007) |
| Selection actions | `ModelSelectionActions.swift`, `DexStateFirstComponents.swift`, `ModelsAccuracyPage.swift` | ✅ Settings ↔ popover share state; Other Engines role-labeled; download rows never checkmarked |

## D. Dictation core safety (🔒 forbidden — inspected via wiring + tests)

| Area | File(s) | Result |
|---|---|---|
| Engine lifecycle / start-stop | `TranscriptionEngine.swift` 🔒, `EngineLifecycle.swift` | ✅ Start/Stop wired via `MainActorAction.run { engine.stopSystem() }`; coordinators started idempotently in `DexDictateApp.onAppear` |
| Audio capture / recovery | `AudioRecorderService.swift` 🔒, `AudioRecorderRecoverySupport.swift` 🔒, `AudioTapInstaller.m` 🔒 | ✅ Untouched; covered by passing recovery/tap tests |
| Output / insertion | `OutputCoordinator.swift` 🔒, `ClipboardManager.swift` 🔒, `SecureInputContext.swift` 🔒 | ✅ Untouched; covered by passing output/clipboard/secure-input tests |

## E. Smart Cleanup (`Sources/DexDictateKit/SmartCleanup/`)

| Area | Result |
|---|---|
| Default off | ✅ `smartCleanupEnabled = false` |
| Raw preserved / runs after delivery | ✅ Reacts to `TranscriptionHistory.$items` (post-delivery); single attempt; raw stands on failure |
| No hardcoded hosts/ports | ✅ Base URL empty by default; port examples in help text only |
| API key handling | ⚠️ Keychain-backed (never plist); per-keystroke write (RISK-003) |

## F. Live Preview (`Sources/DexDictateKit/LivePreview/`, `Sources/DexDictate/LivePreview/`)

| Area | Result |
|---|---|
| Default off | ✅ `livePreviewEnabled = false` |
| Display-only, no extra tap | ✅ Subscribes to existing `engine.$liveTranscript`/`$inputLevel`; no output path |
| Finalizing badge clears (BUG-002) | ✅ `endSession(clearImmediately: true)` on all non-listening/transcribing states |

## G. Floating HUD & windows

| Area | File(s) | Result |
|---|---|---|
| Standard HUD click-through (BUG-004) | `FloatingHUD.swift` | ✅ `ignoresMouseEvents = !useExperimentalNanoHUD` |
| Nano HUD interactivity | `FloatingHUD.swift`, `DexNanoHUDView.swift` | ✅ Nano keeps mouse events; opens hub panel |
| Windows (Settings/History/Help/Launch) | controllers | ✅ Instantiated as normal windows; launch intro click-through preserved |

## H. Dexter identity preservation

| Area | File(s) | Result |
|---|---|---|
| Launch animation | `LaunchIntroController.swift` 🔒 | ✅ Present, untouched |
| Onboarding | `OnboardingView.swift` 🔒 | ✅ Present, untouched |
| Flavor ticker | `FlavorTickerView.swift` 🔒, `FlavorTickerManager.swift` | ✅ Present, untouched |
| Watermarks / profiles / quote packs | `WatermarkAssetProvider.swift` 🔒, `ProfileManager.swift` 🔒, `FlavorQuotePacks.swift`, `Resources/Assets.xcassets` | ✅ Present, untouched |
