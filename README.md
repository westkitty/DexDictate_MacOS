# DexDictate

**DexDictate** is a macOS dictation utility powered by OpenAI's Whisper model, designed for high-accuracy local transcription.

## Status: Provided As-Is
> [!IMPORTANT]
> **This project is provided strictly "As-Is".**
> There is **NO** roadmap, **NO** planned future features, and **NO** active maintenance guarantee. It is released into the Public Domain for the community to use, fork, or modify as they see fit.

## Features (Current State)
- **Local Transcription**: Uses `whisper.cpp` for on-device inference.
- **Push-to-Talk**: Global hotkey support for dictation control.
- **Audio Feedback**: Sound cues for start/stop recording.
- **Clipboard Integration**: Automatically copies transcribed text to the clipboard.

## Installation

### Option 1: Build from Source
1. Clone the repository.
2. Ensure you have Xcode installed.
3. Run the build script:
    ```bash
    ./scripts/build_release.sh
    ```
4. Find the zipped application in the `_releases` folder.

## Troubleshooting

### macOS "Developer Cannot be Verified" Warning
Since this application is built locally and is not notarized by Apple, you may encounter a security warning preventing it from opening.

**To bypass this:**
1. Locate `DexDictate` in your Applications folder (or wherever you unzipped it).
2. **Right-Click** (or Control-Click) the app icon.
3. Select **Open** from the context menu.
4. In the dialog box that appears, click **Open** again.

This is a one-time verification step required by macOS for unsigned applications.

## License
Public Domain (The Unlicense). See `LICENSE` for details.
