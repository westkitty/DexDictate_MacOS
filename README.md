![DexDictate Banner](assets/banner.webp)

<div align="center">
  <img src="assets/icon.png" width="128" height="128" />
</div>

<div align="center">

![License](https://img.shields.io/badge/License-Unlicense-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.x-orange.svg)

</div>

# DexDictate for macOS

A high-performance, privacy-focused dictation bridge for macOS. DexDictate runs locally, converting speech to text with zero latency and full privacy, designed to seamlessly integrate with your workflow.

## Key Features

- **Total Privacy:** All processing happens on-device. No audio ever leaves your machine.
- **Audio Feedback:** Non-intrusive auditory cues ("Tink" / "Basso") confirm start and stop actions.
- **Whimsical Profanity Filter:** An optional, built-in filter that creatively reinterprets harsh language into whimsical alternatives (e.g., "cop" → "state-sponsored terrorists").
- **Auto-Paste:** Instantly inputs transcribed text into your active application via accessibility injection.

## Installation

### Option A: Download Release
Download the latest pre-built application from the [Releases](https://github.com/WestKitty/DexDictate_MacOS/releases) page.

> **Note:** If you encounter an "Unidentified Developer" warning, simply Right-Click the app and select **Open** to bypass the check.

### Option B: Build from Source
To build the application yourself, ensure you have Xcode installed, then run:

```bash
./build.sh
```

This will compile the app and install it to your `~/Applications` folder.

## Governance

**Public Domain / Unlicense**
This project is dedicated to the public domain. You are free to use, modify, distribute, and sell this software without any attribution required.
