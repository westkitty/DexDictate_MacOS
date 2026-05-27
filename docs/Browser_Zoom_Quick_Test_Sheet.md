# Browser Zoom Quick Test Sheet

This document specifies a localized, rapid smoke-test protocol to quickly evaluate DexDictate's audio capture stability and text-focus targeting while a browser-based Zoom web meeting runs in Safari or Google Chrome.

> [!IMPORTANT]
> **PURPOSE**: This is a quick smoke test only. **Browser Zoom compatibility is NOT claimed from this quick sheet alone**; complete verification requires executing the full checklist matrix specified in `docs/Zoom_QA_Checklist.md`.
>
> **NOT IN SCOPE**: The Zoom desktop native app (`us.zoom.xos`) is not targeted by this verification sheet.

---

## Baseline Stabilization Infrastructure (Commits Pushed)
All testing must assume the presence of the following pushed commits:
1. **`415ec654`**: Pre-paste target application revalidation.
2. **`3f36b14d`**: Surfacing CoreAudio `-10868` kAudioOutputUnitErr_InvalidDevice recovery guides in UI.
3. **`470c9e9c`**: Testability seams (`injectMockSamples`) inside `#if DEBUG` guards.
4. **`0b3cccea`**: Initial Browser Zoom validation protocol checklist specs.
5. **`01b9a3ba`**: Hardened mock audio edge-cases tests.
6. **`c854bdce`**: Surface expected vs. actual frontmost application bundle/process identifiers on paste-abort.

---

## The Five Quick Smoke Tests

### Test 1: Safari Zoom Web + Dictate into TextEdit
* **Setup**: 
  1. Open a Zoom web meeting (`zoom.us/wc/join/...`) inside Safari.
  2. Join "Computer Audio" using the Built-in microphone in Safari.
  3. Open TextEdit, focus a blank editor sheet, and place the cursor.
  4. Trigger DexDictate recording.
  5. Speak: "Safari WebRTC capture validation baseline."
  6. Release trigger to stop.
* **Expected Result**: Audio capture completes without stalls/errors. Text types cleanly into TextEdit.
* **Evidence to Collect**: Safari Version, input hardware device, and exact debug.log entries.
* **Status**: `[ ] Pass` / `[ ] Fail`

---

### Test 2: Chrome Zoom Web + Dictate into TextEdit
* **Setup**:
  1. Open a Zoom web meeting inside Google Chrome.
  2. Join "Computer Audio" using the Built-in microphone inside Chrome.
  3. Open TextEdit, focus a blank sheet, and place the cursor.
  4. Trigger DexDictate, speak: "Chrome WebRTC capture validation baseline."
  5. Stop recording.
* **Expected Result**: Audio session captures flawlessly. Text inserts cleanly into TextEdit.
* **Evidence to Collect**: Chrome Version, input device, and debug.log entries.
* **Status**: `[ ] Pass` / `[ ] Fail`

---

### Test 3: Safari Zoom Web Chat Focused + Short Dictation
* **Setup**:
  1. Go to the active Zoom web meeting tab in Safari.
  2. Click explicitly inside the web-hosted Chat input text area.
  3. Trigger DexDictate, speak: "Safari web chat focus test."
  4. Stop recording.
* **Expected Result**: Direct Accessibility API insertion or fallback pasteboard delivery successfully types the text directly inside the browser meeting chat input box.
* **Evidence to Collect**: Paste abort logs (if fallback was triggered).
* **Status**: `[ ] Pass` / `[ ] Fail`

---

### Test 4: Chrome Zoom Web Chat Focused + Short Dictation
* **Setup**:
  1. Go to the active Zoom web meeting tab in Google Chrome.
  2. Click explicitly inside the web-hosted Chat input text area.
  3. Trigger DexDictate, speak: "Chrome web chat focus test."
  4. Stop recording.
* **Expected Result**: Direct insertion or clipboard fallback types the text cleanly into the browser chat input field.
* **Evidence to Collect**: Focus revalidation status logs.
* **Status**: `[ ] Pass` / `[ ] Fail`

---

### Test 5: Secure Field Focused while Browser Zoom is Active
* **Setup**:
  1. Keep an active Zoom web meeting running inside Safari or Chrome in the background.
  2. Navigate to a password input box or secure login field in another tab.
  3. Trigger DexDictate, speak: "SensitivePassword789"
  4. Stop recording.
* **Expected Result**: Secure context is flagged. Keystroke simulation is immediately **blocked** (Copy-only mode). Text is copied only to the clipboard, and a secure notice is logged.
* **Evidence to Collect**: Verification that secure Copy-only mode triggered successfully.
* **Status**: `[ ] Pass` / `[ ] Fail`
