![DexDictate banner](docs/images/readme/banner.webp)

<div align="center">
  <img src="assets/dexdictate-icon-standard-05.png" width="128" height="128" alt="DexDictate icon" />
</div>

<div align="center">

![License](https://img.shields.io/badge/License-Unlicense-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2014+-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.x-orange.svg)
[![Sponsor](https://img.shields.io/badge/Sponsor-pink?style=flat-square&logo=github-sponsors)](https://github.com/sponsors/westkitty)
[![Ko-Fi](https://img.shields.io/badge/Ko--fi-Support%20My%20Work-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/westkitty)

</div>

# DexDictate for macOS

DexDictate is a local-first macOS menu-bar dictation app for Apple Silicon Macs. It records from your microphone, transcribes on-device with Whisper, applies local post-processing such as voice commands and vocabulary correction, and then saves or inserts the result according to your output settings.

It matters because the usual tradeoff is irritatingly familiar: convenience on one side, privacy and control on the other. DexDictate is built around keeping that tradeoff narrower. Audio stays on your Mac, the app lives in the menu bar, and the repository includes the surrounding tooling needed to build, package, verify, and benchmark the product instead of pretending the app exists in a vacuum.

<p align="center">
  <img src="docs/images/readme/dexdictate-demo.gif" alt="Silent demo of DexDictate showing the menu-bar workflow and onboarding flow" width="960" />
</p>

## Install

### Packaged release

If release artifacts are published, download the latest `arm64` `.dmg` or `.zip` from [Releases](https://github.com/WestKitty/DexDictate_MacOS/releases).

- `DexDictate-<version>-macos-arm64.dmg`
- `DexDictate-<version>-macos-arm64.zip`

Typical `.dmg` install:

1. Open the disk image.
2. Drag `DexDictate.app` into `/Applications`.
3. Launch the app and complete onboarding.

### Build from source

```bash
git clone https://github.com/WestKitty/DexDictate_MacOS.git
cd DexDictate_MacOS
./build.sh
```

`./build.sh` fetches the default Whisper model if needed, builds the app and helper targets, signs the bundle, and installs into `/Applications` when writable or `~/Applications` otherwise.

Useful variants:

```bash
./build.sh --user
./build.sh --system
INSTALL_DIR=/Applications ./build.sh
```

## Project status

DexDictate is published as-is, but it is not a dead shell. The repository still contains a working app target, tests, verification paths, benchmark tooling, release packaging, and documentation. What it does not promise is an active roadmap or guaranteed review cadence.

## Highlights

- Local Whisper transcription with bundled `tiny.en`
- macOS menu-bar workflow with onboarding, quick settings, help, and history
- Global keyboard or mouse trigger capture with `Hold` and `Toggle` modes
- Output control spanning save-only, paste, clipboard-only fallback, and per-app rules
- Safety controls for likely secure fields plus a broader `Safe Mode` preset
- Built-in voice commands, bundled vocabulary packs, and user-defined corrections
- Repository includes benchmarking, verification, release validation, and packaging tooling

## Quick Start

1. Install DexDictate from a release or run `./build.sh`.
2. Launch the app and grant Accessibility, Input Monitoring, and Microphone access.
3. Open the menu-bar item and confirm the trigger shortcut. The default is middle mouse.
4. Dictate with `Hold` or `Toggle`, then adjust output and safety settings as needed.

## Feature Overview

### Core behavior

- Menu-bar utility with a four-step onboarding flow
- On-device transcription through [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper)
- Selected microphone or system-default input handling
- Live mic activity, floating HUD, and optional sound cues

### Output and control

- Auto-paste into the active app
- Clipboard-only fallback for likely secure inputs
- Optional Accessibility API insertion
- Per-app insertion overrides by bundle identifier
- Launch-at-login support through `SMAppService`

### Language and cleanup

- Built-in voice commands for editing and formatting
- Bundled vocabulary packs layered with user vocabulary
- Custom `Dex <keyword>` commands
- Optional profanity filtering

### Repository character

DexDictate is not just an app bundle dropped in a repo. It also carries its benchmark corpus, packaging scripts, verification helper, release validation path, supporting assets, and long-form project documentation. That wider tooling footprint is part of the project, not noise around it.

## For Users

What to expect:

- macOS 14+ on Apple Silicon (`arm64`)
- Three permissions for normal operation: Accessibility, Input Monitoring, Microphone
- Local runtime transcription with no cloud transcription path in the app itself

Useful knobs after first launch:

- Trigger mode and shortcut
- Input device selection
- Auto-paste and secure-field behavior
- Vocabulary, custom commands, and history persistence
- Floating HUD, sound cues, and per-app insertion rules

## For Developers

Repository shape:

- App target in `Sources/DexDictate/`
- Shared runtime and resources in `Sources/DexDictateKit/`
- Verification executable in `Sources/VerificationRunner/`
- Unit and integration coverage in `Tests/DexDictateTests/`

Constraints worth knowing up front:

- Apple Silicon only; the build script rejects Rosetta and Intel shells
- Source builds expect Xcode 15 or Command Line Tools
- The bundled default model is `tiny.en`

## Development Workflow and Tooling

Standard local path:

```bash
./scripts/fetch_model.sh
swift build
swift test
swift run VerificationRunner
./build.sh
```

Useful repository commands:

- `./build.sh [--user|--system] [--release]`
- `./scripts/setup_dev_env.sh`
- `./scripts/fetch_model.sh`
- `./scripts/run_quality_paths.sh`
- `./scripts/benchmark.sh --audio <wav>`
- `python3 scripts/benchmark.py --corpus-dir <dir>`
- `./scripts/benchmark_regression.sh <wav> [baseline_ms]`
- `./scripts/trim_benchmark_corpus.sh <input_dir> [output_dir]`
- `./scripts/validate_release.sh [path_to_app_bundle]`

Repository trust signals:

- GitHub Actions workflow runs `swift build` and `swift test` on pushes and pull requests to `main`
- Release tooling packages `.zip` and `.dmg` artifacts
- Release validation checks bundle integrity, architecture, signing, entitlements, and hashes

## Repository Layout

```text
.
├── Sources/
│   ├── DexDictate/         # menu-bar app target
│   ├── DexDictateKit/      # transcription, settings, permissions, output, resources
│   └── VerificationRunner/ # verification and benchmark helper executable
├── Tests/DexDictateTests/  # unit and integration tests
├── scripts/                # build, benchmark, setup, and validation tooling
├── docs/                   # feature inventory, help content, and long-form project docs
├── assets/                 # artwork, marketing images, icons, and source visuals
├── sample_corpus/          # benchmark sample audio and transcripts
├── templates/              # Info.plist template used during bundle assembly
├── build.sh                # canonical build, install, and release entry point
└── Package.swift           # Swift Package Manager manifest
```

## Additional Documentation

- [Feature inventory](docs/FEATURE_INVENTORY.md)
- [Contributing guidance](CONTRIBUTING.md)

## Contributing

Issues and pull requests are welcome. Review and merge are not guaranteed, so keep changes grounded, specific, and honest about what the repository actually supports. More detail lives in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

This repository is released under the [Unlicense](LICENSE).

## Why Dexter?

*Dexter is a small, tricolor Phalène dog with floppy ears and a perpetually unimpressed expression. He is the project mascot, the mood board, and the implied code review standard: alert, picky, dependable, and mildly offended by sloppy work. If he approves, it probably holds together.*
