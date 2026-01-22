# DexDictate MacOS

<img src="Sources/DexDictate/Resources/Assets.xcassets/dog_background.imageset/dog_background.png" width="200" align="right" />

**Native, Offline, Private Dictation for macOS.**

DexDictate is a lightweight menu bar application that provides reliable Push-to-Talk dictation using Apple's native `SFSpeechRecognizer` framework.

**Repository:** [westkitty/DexDictate_MacOS](https://github.com/westkitty/DexDictate_MacOS)

## Features
- **Native Engine**: Uses Apple's on-device Speech framework (Offline capable, Zero dependencies).
- **Push-to-Talk**: Hold Middle Mouse to speak, Release to paste.
- **Glassmorphism UI**: Beautiful, modern SwiftUI interface with `.ultraThinMaterial`.
- **Privacy First**: Explicit Permission controls for Microphone and Accessibility.
- **Debug Console**: Built-in diagnostics for instant troubleshooting.

## Requirements
- macOS 14.0 (Sonoma) +
- Microphone

## Installation
Currently distributed as source.
1. Clone the repo.
2. Run `./build.sh` (Auto-signs with entitlements).
3. App installs to `~/Applications/DexDictate_MacOS.app`.

## Usage
1. Launch App.
2. Grant **Accessibility** & **Speech** permissions (Restart App after granting Accessibility).
3. **Hold Middle Mouse Button** to dictate.
4. Release to insert text.

## Troubleshooting
If dictation fails, check the **Debug Console** at the bottom of the app menu.
- `Input Tap Active`: System is working.
- `CRITICAL FAILURE`: Accessibility permission is blocked. Run `tccutil reset Accessibility com.westkitty.dexdictate.macos` and restart.
