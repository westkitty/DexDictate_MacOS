# DexDictate macOS – Copilot Instructions

## Architecture & data flow
- SwiftUI menu bar app driven by `DexDictateApp` + `MenuBarExtra` in [Sources/DexDictate/DexDictateApp.swift](Sources/DexDictate/DexDictateApp.swift).
- Core runtime flow: `PermissionManager` polls macOS permissions → `InputMonitor` installs CGEventTap for middle mouse → `TranscriptionEngine` starts `AVAudioEngine` + `SFSpeechRecognizer` and handles paste. See [Sources/DexDictate/PermissionManager.swift](Sources/DexDictate/PermissionManager.swift), [Sources/DexDictate/InputMonitor.swift](Sources/DexDictate/InputMonitor.swift), [Sources/DexDictate/TranscriptionEngine.swift](Sources/DexDictate/TranscriptionEngine.swift).
- Global state comes from `Settings.shared` using `@AppStorage` enums; UI toggles read/write those values. See [Sources/DexDictate/Settings.swift](Sources/DexDictate/Settings.swift) and [Sources/DexDictate/SettingsView.swift](Sources/DexDictate/SettingsView.swift).
- On-device recognition only: `recognitionRequest.requiresOnDeviceRecognition = true` and clipboard + optional paste via `CGEvent` in `TranscriptionEngine`.

## Critical workflows (macOS-specific)
- Build + sign + install: run `./build.sh` (uses arm64, creates bundle, compiles assets via `actool`, codesigns with “DexDictate Development”, installs to `~/Applications/DexDictate_V2.app`). See [build.sh](build.sh).
- Permissions reset when event taps fail: `./reset_tcc_permissions.sh` (InputMonitoring/Accessibility) or `./fix_permissions.sh` (reset all for bundle id). Bundle ID is `com.westkitty.dexdictate.macos`.
- First-time dev setup: `./scripts/setup_dev_env.sh` creates VERSION + signing cert; cert creation logic is in [scripts/create_signing_cert.sh](scripts/create_signing_cert.sh).

## Project-specific patterns & conventions
- Use `@MainActor` for `TranscriptionEngine` and schedule UI state updates from background callbacks via `Task { @MainActor in ... }` (see `InputMonitor.start()` and speech callbacks).
- `InputMonitor` consumes middle mouse events (button 2) and uses `Settings.triggerMode` to decide hold-to-talk vs toggle. This is the only global input entry point.
- Permission recovery: `PermissionManager` watches Accessibility changes and calls `engine.retryInputMonitor()` after trust is granted.
- Settings are centralized in `Settings.shared` (singleton). Avoid new global singletons unless necessary.

## Integration points
- macOS permissions: Accessibility + Input Monitoring are required for CGEventTap; Microphone + Speech Recognition for dictation.
- External frameworks in use: `Speech`, `AVFoundation`, `AppKit`, `AudioToolbox` (no third-party deps; see [Package.swift](Package.swift)).

## Where to look first
- UI + menu bar wiring: [Sources/DexDictate/DexDictateApp.swift](Sources/DexDictate/DexDictateApp.swift)
- Input handling and state transitions: [Sources/DexDictate/InputMonitor.swift](Sources/DexDictate/InputMonitor.swift) + [Sources/DexDictate/TranscriptionEngine.swift](Sources/DexDictate/TranscriptionEngine.swift)
- Permission polling + recovery: [Sources/DexDictate/PermissionManager.swift](Sources/DexDictate/PermissionManager.swift)