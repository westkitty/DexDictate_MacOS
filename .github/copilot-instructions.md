# DexDictate macOS – Copilot Instructions

## Architecture & data flow
- SwiftUI menu bar app driven by `DexDictateApp` + `MenuBarExtra` in [Sources/DexDictate/DexDictateApp.swift](Sources/DexDictate/DexDictateApp.swift).
- Core runtime flow: `PermissionManager` polls macOS permissions → `InputMonitor` installs a CGEventTap for the configured trigger → `TranscriptionEngine` starts `AVAudioEngine` and local Whisper transcription. See [Sources/DexDictateKit/Permissions/PermissionManager.swift](Sources/DexDictateKit/Permissions/PermissionManager.swift), [Sources/DexDictateKit/Permissions/InputMonitor.swift](Sources/DexDictateKit/Permissions/InputMonitor.swift), [Sources/DexDictateKit/TranscriptionEngine.swift](Sources/DexDictateKit/TranscriptionEngine.swift).
- Global state comes from `Settings.shared` using `@AppStorage` enums; UI toggles read/write those values. See [Sources/DexDictate/Settings.swift](Sources/DexDictate/Settings.swift) and [Sources/DexDictate/SettingsView.swift](Sources/DexDictate/SettingsView.swift).
- On-device recognition only: DexDictate uses bundled/imported Whisper models managed by `WhisperModelCatalog`, with clipboard + optional paste handled in `TranscriptionEngine`.

## Critical workflows (macOS-specific)
- Build + sign + install: run `./build.sh`, `./build.sh --user`, or `./build.sh --system`. `./build.sh --release` also packages zip + dmg artifacts into `_releases/`. The script fails under Rosetta and bootstraps `tiny.en.bin` through `scripts/fetch_model.sh`.
- Permission handling is native-only. Do not script TCC database resets; keep fixes inside the Swift permission flow.
- First-time dev setup: `./scripts/setup_dev_env.sh` creates VERSION + signing cert; cert creation logic is in [scripts/create_signing_cert.sh](scripts/create_signing_cert.sh).

## Project-specific patterns & conventions
- Use `@MainActor` for `TranscriptionEngine` and schedule UI state updates from background callbacks via `Task { @MainActor in ... }` (see `InputMonitor.start()` and speech callbacks).
- `InputMonitor` consumes middle mouse events (button 2) and uses `Settings.triggerMode` to decide hold-to-talk vs toggle. This is the only global input entry point.
- Permission recovery: `PermissionManager` watches Accessibility changes and calls `engine.retryInputMonitor()` after trust is granted. Keep onboarding and runtime wired to the same manager instance.
- Settings are centralized in `Settings.shared` (singleton). Avoid new global singletons unless necessary; `PermissionManager.shared` exists specifically to prevent permission-state drift across onboarding and runtime UI.

## Integration points
- macOS permissions: Accessibility + Input Monitoring are required for CGEventTap; Microphone is required for dictation.
- External frameworks in use: `AVFoundation`, `AppKit`, `AudioToolbox`, `ApplicationServices`, and `SwiftWhisper` via Swift Package Manager (see [Package.swift](Package.swift)).

## Where to look first
- UI + menu bar wiring: [Sources/DexDictate/DexDictateApp.swift](Sources/DexDictate/DexDictateApp.swift)
- Input handling and state transitions: [Sources/DexDictateKit/Permissions/InputMonitor.swift](Sources/DexDictateKit/Permissions/InputMonitor.swift) + [Sources/DexDictateKit/TranscriptionEngine.swift](Sources/DexDictateKit/TranscriptionEngine.swift)
- Permission polling + recovery: [Sources/DexDictateKit/Permissions/PermissionManager.swift](Sources/DexDictateKit/Permissions/PermissionManager.swift)
