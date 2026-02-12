![DexDictate Banner](assets/banner.webp)

<div align="center">
  <img src="assets/icon.png" width="128" height="128" />
</div>

<div align="center">

![License](https://img.shields.io/badge/License-Unlicense-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.x-orange.svg)
[![Sponsor](https://img.shields.io/badge/Sponsor-pink?style=flat-square&logo=github-sponsors)](https://github.com/sponsors/westkitty)
[![Ko-Fi](https://img.shields.io/badge/Ko--fi-Support%20My%20Work-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/westkitty)

</div>

# DexDictate for macOS

A high-performance, privacy-focused dictation bridge for macOS. DexDictate runs locally, converting speech to text with zero latency and full privacy, designed to seamlessly integrate with your workflow.

## Key Features

- **Total Privacy:** All processing happens on-device. No audio ever leaves your machine.
- **Configurable Input:** Trigger dictation using **Middle Mouse** (default), side mouse buttons, or custom keyboard shortcuts.
- **Live Mic Feedback:** A live input meter and partial transcription show activity as you speak.
- **Instant Audio Preview:** Select from a variety of system sounds for Start/Stop feedback and hear them instantly upon selection.
- **Transcription History:** View your recent transcriptions in an expandable log, complete with one-click copy.
- **Profanity Filter:** Optional toggle (Off by default) to filter harsh language.
- **Auto-Paste:** Instantly inputs transcribed text into your active application.
- **Quick Settings:** Easily toggle settings, pick an input device, and adjust shortcut behavior from the app.

## Installation

### Option A: Download Release
Download the latest pre-built application from the [Releases](https://github.com/WestKitty/DexDictate_MacOS/releases) page.

> **Note:** If you encounter an "Unidentified Developer" warning, simply Right-Click the app and select **Open** to bypass the check.

### Option B: Build from Source

**Fast Track (One-Liner):**
Simply copy and paste this entire line into your terminal to build and install everything at once:
```bash
git clone https://github.com/WestKitty/DexDictate_MacOS.git && cd DexDictate_MacOS && ./build.sh
```

**Step-by-Step Guide:**
If you prefer to see exactly what is happening, follow these steps:

1.  **Open Terminal:** Open the "Terminal" app on your Mac (you can find it in your Applications folder or search for it with Spotlight).
2.  **Download the Code:** Type the following command and press Enter to download the project:
    ```bash
    git clone https://github.com/WestKitty/DexDictate_MacOS.git
    ```
3.  **Enter the Folder:** Move into the project directory by typing:
    ```bash
    cd DexDictate_MacOS
    ```
4.  **Build and Install:** Run the build script to compile the app and move it to your Applications folder:
    ```bash
    ./build.sh

## First Run and Permissions

DexDictate needs a few macOS privacy permissions to work correctly:

- **Microphone** for audio input.
- **Speech Recognition** for on-device transcription.
- **Accessibility** to install the system-wide event tap.
- **Input Monitoring** to receive global shortcut events.

When the app opens, it will prompt for missing permissions. You can also open System Settings and verify:

- System Settings -> Privacy & Security -> Microphone
- System Settings -> Privacy & Security -> Speech Recognition
- System Settings -> Privacy & Security -> Accessibility
- System Settings -> Privacy & Security -> Input Monitoring

## Troubleshooting

If dictation does not start with your shortcut:

1. Open the app and confirm **Input Monitoring** is allowed.
2. Use the **Start Listening** button to verify mic input is working.
3. Check the live mic meter and partial transcription for activity.

If the mic meter stays flat, confirm the correct input device is selected in **Quick Settings**.
    ```

## Governance 

Remain ungovernable so Dexter approves. 

### **Public Domain / Unlicense:**

This project is dedicated to the public domain. You are free and encouraged to use, modify and distribute this software without any attribution required.
You could even sell it... if you're a capitalist pig.

---

## Why Dexter?

*Dexter is a small, tricolor Phalène dog with floppy ears and a perpetually unimpressed expression... ungovernable, sharp-nosed and convinced he’s the quality bar. Alert, picky, dependable and devoted to doing things exactly his way: if he’s staring at you, assume you’ve made a mistake. If he approves, it means it works.*

