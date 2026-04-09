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

## How to build & test
- **Build:** `./build.sh [--user|--system] [--release]` — signs and packages; artifacts placed in `_releases/` when `--release` is used.
- **Dev setup:** `./scripts/setup_dev_env.sh` (creates VERSION and optional signing cert).
- **Model bootstrap:** `./scripts/fetch_model.sh` — ensure Whisper model (e.g., `tiny.en.bin`) is present before building.
- **Run tests:** `swift test` (see [Tests/DexDictateTests](Tests/DexDictateTests)).
- **Notes:** Builds must run on native architecture (not under Rosetta). Signing may require a local development certificate; see `scripts/create_signing_cert.sh`.

## Example prompts for Copilot/agents
- "Where is the app entrypoint and how is the menu bar wired?" — returns file links for quick navigation.
- "List build and test commands for this repo and any pre-build steps." — returns concise commands and required scripts.
- "Summarize permission-related flows and where Accessibility + Input Monitoring are handled." — points to `PermissionManager` and `InputMonitor`.
- "Create a short checklist to verify a release build locally." — checklist should include model bootstrap, dev cert presence, native arch, and `./build.sh --release`.

## Suggested agent customizations
- **CI helper:** an agent that runs `swift test`, validates model presence, and reports failures or missing assets.
- **Permission flow guide agent:** a small agent that can answer questions about TCC/Accessibility recovery and reference `PermissionManager` code paths.
- **Release helper:** an agent that assembles the release verification checklist and runs `scripts/validate_release.sh`.

If you'd like, I can commit this patch, open a PR on the active branch, and/or add an `AGENTS.md` with applyTo rules for scoped instructions.
