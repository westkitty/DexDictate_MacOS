[![DexDictate banner](docs/images/readme/banner.webp)](https://github.com/westkitty/DexDictate_MacOS)

<p align="center">
  <img src="assets/dexdictate-icon-standard-05.png" width="128" alt="DexDictate Icon">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-Unlicense-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Platform-macOS%2014+-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Arch-Apple%20Silicon-orange.svg" alt="Architecture">
</p>

---

# DexDictate (macOS)

Local, privacy-first voice dictation for macOS.  
No cloud. No telemetry. No nonsense.

Dexter approves. Barely.

---

## What This Is

DexDictate is a fully local speech-to-text tool for macOS.

* **Runs entirely on-device**: No audio leaves your machine.
* **Zero Telemetry**: It does not "phone home" or track usage.
* **Performance First**: Built specifically for Apple Silicon to ensure minimal latency.
* **Minimal Friction**: Designed to stay out of the way until needed.

This is a local utility, not a cloud wrapper.

---

## Requirements (Read First)

* **macOS 14 (Sonoma)** or newer.
* **Apple Silicon** (M1, M2, M3, M4).

**Intel Macs are not supported.** The build script will reject x86_64 environments.

---

## 30-Second Install (Recommended)

```bash
git clone [https://github.com/westkitty/DexDictate_MacOS.git](https://github.com/westkitty/DexDictate_MacOS.git)
cd DexDictate_MacOS
./build.sh
open /Applications/DexDictate.app
```

---

## First Launch (macOS Permissions)

On first run, macOS will require the following permissions:

1.  **Microphone access**: To capture your voice.
2.  **Accessibility access**: To insert text into the active application.
3.  **Input Monitoring**: To listen for the global trigger shortcut.

**Grant these immediately.** If you skip them, the app will remain inert. This is a macOS security requirement, not a suggestion.

---

## Basic Usage

1.  **Launch the app**: It lives in your menu bar.
2.  **Trigger**: Use the global shortcut (Default is Middle Mouse, configurable in-app).
3.  **Speak**: A HUD will appear to show activity.
4.  **Text appears**: Your dictation is inserted directly at your cursor.

---

## Features

* **Local Whisper Transcription**: Powered by `tiny.en` (bundled).
* **Global Triggers**: Supports both `Hold` and `Toggle` modes.
* **Smart Output**: Auto-paste, clipboard fallback, and per-app insertion rules.
* **Safe Mode**: Automatic suppression in likely password/secure fields.
* **Voice Commands**: Built-in commands for formatting and vocabulary cleanup.

---

## Installation Options

### Option A — Build from Source (Recommended)

Use the `./build.sh` script. It handles model fetching, bundle assembly, and signing automatically.

### Option B — Open in Xcode

1.  Open `Package.swift` in Xcode 15+.
2.  Select the `DexDictate` target.
3.  Build and Run (**Cmd+R**).

---

## Project Structure

```text
DexDictate_MacOS/
├── Sources/
│   ├── DexDictate/         # Menu-bar UI & App Layer
│   └── DexDictateKit/      # Core logic, Whisper integration, & Settings
├── scripts/                # Benchmarking, setup, and dev tooling
├── assets/                 # Icons and branding assets
├── sample_corpus/          # Benchmark audio for verification
├── build.sh                # Primary build and install entry point
├── BIBLE.md                # Project moral architecture & Ethical Axis
└── README.md
```

---

## Security & Privacy

* All audio is processed locally using SwiftWhisper.
* No network calls are made for transcription or analysis.
* No analytics, no tracking, no logging of speech data.
* The project is released under the **Unlicense** for maximum transparency.

---

## Optional: Verify the Build (Advanced)

For contributors or the paranoid:

```bash
swift run VerificationRunner
```

This validates build integrity, architecture requirements, and expected outputs against the `sample_corpus`.

---

## Documentation

* **Moral Architecture**: [BIBLE.md](BIBLE.md)
* **Technical Inventory**: [docs/FEATURE_INVENTORY.md](docs/FEATURE_INVENTORY.md)
* **Security Audit**: [SECURITY_AUDIT_REPORT.md](SECURITY_AUDIT_REPORT.md)
* **Verification**: [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md)

---

## Limitations

* **Apple Silicon only**: Optimized for the Neural Engine.
* **macOS 14+ required**: Uses modern Apple APIs for permissions and UI.
* **System Permissions**: Dependent on Accessibility API for text injection.

---

## Positioning

DexDictate is not trying to be everything. It is:

* **Local**
* **Fast**
* **Private**
* **Minimal**

If you want cloud-orchestrated AI agents, this is the wrong tool. If you want your voice to become text without leaving your RAM, this is the right one.

---

## Contributing

If you are modifying behavior, verify your changes with the `VerificationRunner` before committing. Keep it simple. If it gets complicated, you are probably doing it wrong.

---

## License

This project is released under the [Unlicense](LICENSE).

---

## Why Dexter?

Dexter is a small, tricolor Phalène dog with floppy ears and a perpetually unimpressed expression. He is the project mascot, the mood board, and the implied code review standard: alert, picky, dependable, and mildly offended by sloppy work.

Dexter does not celebrate features. Dexter tolerates correctness.

**This passes.**
