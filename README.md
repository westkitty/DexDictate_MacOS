![DexDictate Banner](assets/banner.webp)

<div align="center">
  <img src="assets/dexdictate-icon-standard-05.png" width="128" height="128" />
</div>

<div align="center">

![License](https://img.shields.io/badge/License-Unlicense-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2014+-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.x-orange.svg)
[![Sponsor](https://img.shields.io/badge/Sponsor-pink?style=flat-square&logo=github-sponsors)](https://github.com/sponsors/westkitty)
[![Ko-Fi](https://img.shields.io/badge/Ko--fi-Support%20My%20Work-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/westkitty)

</div>

# DexDictate for macOS

Offline menu-bar dictation for macOS. Audio stays local, Whisper runs local, output stays under your control.

## What It Does

DexDictate listens for a global trigger, records microphone input, transcribes with local Whisper, applies local post-processing (commands, vocabulary, optional profanity filtering), then saves and optionally inserts the result into the active app.

No cloud transcription path exists in app runtime.

## Key Features

- Local-only transcription with bundled `tiny.en` Whisper model.
- Global trigger via mouse or keyboard shortcut, with `Hold to Talk` and `Toggle` modes.
- Optional sound cues, floating HUD, and live mic level feedback.
- Output modes: save-only, clipboard paste, Accessibility API insertion, or clipboard-only per app.
- Sensitive-field guardrail: copy-only fallback for likely secure inputs.
- Custom vocabulary replacements layered over bundled profile vocabulary.
- Built-in voice commands (`scratch that`, `all caps`, `new line`/`next line`) plus custom `Dex <keyword>` commands.
- Optional history persistence across launches.
- File transcription from picker or drag-and-drop audio file.
- Local benchmark tooling, strict corpus capture UI, and model comparison/promotion workflow.
- Launch-at-login control through macOS `SMAppService`.

## How It Works / Architecture Overview

1. `DexDictate` (SwiftUI/AppKit menu bar app) handles onboarding, controls, and windows.
2. `PermissionManager` polls Accessibility, Input Monitoring, and Microphone state.
3. `InputMonitor` installs a Quartz event tap for the configured global shortcut.
4. `AudioRecorderService` captures audio from the selected input device.
5. `TranscriptionEngine` resamples to 16 kHz, calls `WhisperService`, then runs post-processing.
6. `OutputCoordinator` decides whether to paste, copy-only, or save-only based on settings/context.
7. `VerificationRunner` and benchmark scripts validate invariants and transcription performance.

## Tech Stack

- Swift 5.9
- Swift Package Manager (SPM)
- SwiftUI + AppKit
- AVFoundation, CoreAudio, ApplicationServices, ServiceManagement
- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) (pinned revision in `Package.swift`)
- Bash and Python scripts for model bootstrap, benchmarking, and release validation
- GitHub Actions CI (`swift build`, `swift test`)

## Prerequisites

- macOS 14+
- Apple Silicon (`arm64`) terminal/session (the build script rejects Rosetta/Intel)
- Xcode 15+ (or Command Line Tools)
- Internet access once to download `tiny.en.bin` if missing

## Installation

### Build From Source (canonical)

```bash
git clone https://github.com/WestKitty/DexDictate_MacOS.git
cd DexDictate_MacOS
./build.sh
open /Applications/DexDictate.app || open ~/Applications/DexDictate.app
```

`./build.sh` will:

- ensure `tiny.en.bin` exists (downloads + checksum verification if needed)
- build app + helper
- sign (named cert if available, otherwise ad-hoc)
- install to `/Applications` when writable, else `~/Applications`

Explicit install targets:

```bash
./build.sh --user
./build.sh --system
INSTALL_DIR=/Applications ./build.sh
```

### Prebuilt Releases

If release artifacts are published for a tag, you can download them from [Releases](https://github.com/WestKitty/DexDictate_MacOS/releases).

## Configuration / Environment Variables

No `.env` file is required.

Supported environment variables:

- `INSTALL_DIR` (build time): overrides install destination used by `build.sh`.
- `DEXDICTATE_VERIFICATION_RUNNER_PATH` (runtime, optional): custom path for benchmark helper resolution.

Local data/config is stored under:

- `~/Library/Application Support/DexDictate/`

This directory is used for diagnostics, optional history persistence, benchmark captures/results, and imported model metadata.

## Usage

1. Launch `DexDictate.app`.
2. Complete onboarding and grant required macOS permissions.
3. Set your trigger shortcut in Quick Settings (default: middle mouse).
4. Hold or toggle the trigger to record.
5. Let DexDictate process and deliver output according to your output mode.
6. Optional: open Custom Vocabulary, Voice Commands, Per-App Insertion Rules, or Benchmark tools from Quick Settings.

## Development Workflow

1. Bootstrap model and build:
   ```bash
   ./scripts/fetch_model.sh
   swift build
   ```
2. Run unit/integration tests:
   ```bash
   swift test
   ```
3. Run invariant verification paths:
   ```bash
   swift run VerificationRunner
   ```
4. Build/install full app bundle for manual QA:
   ```bash
   ./build.sh
   ```
5. For transcription changes, run benchmark corpus flows before claiming improvement.

## Scripts / Commands

- `./build.sh [--user|--system] [--release]`: build, sign, install, optional packaging.
- `./scripts/fetch_model.sh`: download/verify bundled Whisper model.
- `./scripts/setup_dev_env.sh`: quick local dev bootstrap.
- `./scripts/create_signing_cert.sh`: optional local self-signed cert for stable identity signing.
- `swift test`: run test suite.
- `swift run VerificationRunner`: run verification path checks.
- `./scripts/run_quality_paths.sh`: run build + verification runner.
- `./scripts/benchmark.sh --audio <wav>`: run latency benchmark on one file.
- `python3 scripts/benchmark.py --corpus-dir <dir>`: run strict corpus benchmark and emit reports.
- `./scripts/benchmark_regression.sh <wav> [baseline_ms]`: benchmark with regression gate.
- `./scripts/trim_benchmark_corpus.sh <input_dir> [output_dir]`: silence-trim a corpus (requires `ffmpeg`).
- `./scripts/validate_release.sh [path_to_app_bundle]`: validate release bundle and artifacts.

## Project Structure

```text
.
├── Sources/
│   ├── DexDictate/           # macOS app target (menu bar UI, onboarding, windows)
│   ├── DexDictateKit/        # core engine/services/settings/resources
│   └── VerificationRunner/   # verification + benchmark executable
├── Tests/DexDictateTests/    # unit/integration tests
├── scripts/                  # build/benchmark/release tooling
├── templates/                # Info.plist template for app bundle assembly
├── sample_corpus/            # sample benchmark corpus
├── docs/                     # architecture/experiment/handoff docs
├── build.sh                  # canonical build/install/release entry point
└── Package.swift             # SwiftPM manifest
```

## Deployment / Build Notes

- `./build.sh --release` packages `.zip` + `.dmg` into `_releases/` and generates checksums.
- `scripts/validate_release.sh` verifies bundle integrity, architecture, signing, entitlements, and artifact hashes.
- CI workflow in `.github/workflows/main.yml` runs `swift build` and `swift test` on `macos-latest`.
- Notarization is not automated in this repository.

## Known Limitations / Caveats

- Apple Silicon only (`arm64`); Intel Macs are out of scope for current build tooling.
- Bundled model is `tiny.en` (English). Imported model support is currently restricted to `base.en.bin` and `small.en.bin` filenames.
- Requires Accessibility + Input Monitoring + Microphone permissions for full functionality.
- Localization plumbing exists (`NSLocalizedString`) but this repo does not ship full language packs.
- Project is published as-is; active development is marked as concluded in `CONTRIBUTING.md`.

## Contributing

Bug reports and pull requests are welcome.

That said, this project is explicitly maintained as **as-is** and PR review/merge is not guaranteed. If you need a guaranteed path, fork it and run your own roadmap.

## License

This project is released under the **Unlicense** (public domain). See [LICENSE](LICENSE).

---

## Why Dexter?

*Dexter is a small, tricolor Phalène dog with floppy ears and a perpetually unimpressed expression... ungovernable, sharp-nosed and convinced he’s the quality bar. Alert, picky, dependable and devoted to doing things exactly his way: if he’s staring at you, assume you’ve made a mistake. If he approves, it means it works.*
