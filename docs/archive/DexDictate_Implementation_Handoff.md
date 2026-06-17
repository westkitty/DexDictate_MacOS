# DexDictate — UI Implementation Handoff

**Version:** 1.0  
**For:** Claude Code / Engineering  
**Companion file:** `DexDictate_UI_Design.html` (open in Safari or Chrome for the full interactive prototype)

---

## Purpose

This document is the canonical implementation contract for DexDictate's UI. It defines architecture rules, state machine, component responsibilities, visual tokens, UX copy, and the exact constraints that prevent the duplicate-menu-bar instability that prompted this design pass.

Engineering should treat this as the source of truth. When in doubt, consult this document before writing code.

---

## Critical Architecture Rules

These are non-negotiable. Violating any of these is the likely root cause of the prior UI instability.

### Rule 1 — One NSStatusItem, one owner

`DexDictateStatusItem` is created **exactly once**, in `applicationDidFinishLaunching`, by `AppDelegate`.

**No other code path creates an `NSStatusItem`.** The dictation engine, settings system, update checker, and permission checker must not call `NSStatusBar.system.statusItem(withLength:)` under any circumstances.

### Rule 2 — Starting the engine must not create UI

`DictateEngine` is a background actor. Its only outputs are:
- Mutations to `AppState`
- Structured `DictateError` values

It does not import AppKit. It does not instantiate views, windows, or status items. It does not post raw `NSNotification` objects that UI code pattern-matches to infer state.

### Rule 3 — Settings window is a singleton

`DictateSettingsWindowController.shared.show(panel:)` is idempotent:
- If the window is hidden → show it, navigate to `panel`
- If the window is already visible → call `makeKeyAndOrderFront(_:)`, navigate to `panel`
- **Never** instantiate a new `NSWindowController` for settings

### Rule 4 — Popover is a singleton

`DictatePopoverController.shared.toggle()` shows or hides the popover.
- The `NSPopover` is created once at startup and reused
- Content view is set once; it observes `AppState` reactively
- **Never** create a new `NSPopover` on each menu bar click

### Rule 5 — AppState is the single source of truth

All UI state flows through one `@MainActor ObservableObject` (`AppState`). The UI does not:
- Read engine process state to guess app status
- Infer state from window visibility
- Pattern-match lifecycle notifications to decide what to show

Every state transition must set `AppState.status`. The UI subscribes and reacts.

### Rule 6 — Duplicate detection before UI creation

On `applicationDidFinishLaunching`:
1. Call `NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)`
2. If count > 1, set `AppState.status = .duplicateInstance` immediately
3. Show the popover with the duplicate warning state
4. The "Quit Other Copy" CTA calls `terminateOtherInstances()`, then transitions to `.idle`

### Rule 7 — Permissions are checked, not assumed

- Check on launch and before each dictation attempt
- Missing permissions → `AppState.status = .permissionNeeded([.microphone, .accessibility])`
- Never show a modal sheet for missing permissions — surface them in the popover only
- Poll for accessibility grant with a 0.5s timer (max 60s) after opening System Settings

### Rule 8 — No UI in the engine layer

`DictateEngine` has zero knowledge of:
- `NSStatusItem`, `NSPopover`, `NSWindow`
- Any view, controller, or AppKit type
- Notification names that UI code observes for state inference

---

## App State Machine

```
┌─────────────┐
│   .idle     │ ◄──────────────────────────────────┐
└──────┬──────┘                                     │
       │ trigger (key/button)                       │
       ▼                                            │
┌─────────────┐   cancel                            │
│ .listening  │──────────────────────────────────── ►│
└──────┬──────┘                                     │
       │ trigger released / VAD silence             │
       ▼                                            │
┌─────────────┐   cancel / timeout                  │
│ .processing │──────────────────────────────────── ►│
└──────┬──────┘                                     │
       │ success                                    │
       ▼                                            │
┌─────────────┐   discard / auto-insert             │
│   .ready    │──────────────────────────────────── ►│
└──────┬──────┘                                     │
       │ insert                                     │
       ▼                                            │
┌──────────────────┐ success                        │
│ (insert attempt) │──────────────────────────────► ►│
└──────┬───────────┘                                │
       │ accessibility revoked                      │
       ▼                                            │
┌──────────────────┐   dismiss / fix                │
│ .insertionBlocked│────────────────────────────── ►│
└──────────────────┘                                │
                                                    │
── Error branches ─────────────────────────────────►│
.error(DictateError)         retry / dismiss ───── ►│
.permissionNeeded([perm])    fix / later   ───────  │
.duplicateInstance           resolve ─────────────  │
.noAudioDevice               fix device ──────────  │
.updateRequired              restart / later ─────► ┘
```

### State Enum

```swift
enum DictateStatus: Equatable {
    case idle
    case listening
    case processing
    case ready(transcript: String)
    case error(DictateError)
    case permissionNeeded([PermissionType])
    case insertionBlocked
    case duplicateInstance
    case noAudioDevice
    case updateRequired(version: String)
}

enum DictateError: Error, Equatable {
    case micUnavailable
    case transcriptionFailed
    case engineCrashed
    case timeout
}

enum PermissionType {
    case microphone
    case accessibility
}
```

---

## AppState

```swift
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var status: DictateStatus = .idle
    @Published var micDeviceName: String = "MacBook Pro Microphone"
    @Published var triggerMode: TriggerMode = .holdKey(combo: "⌥ Space")
    @Published var lastError: DictateError? = nil
    
    // Only written by DictateEngine and PermissionChecker
    // Only read by UI layer
}
```

---

## File / Class Map

```
DexDictate/
├── App/
│   ├── AppDelegate.swift               # Creates StatusItem + Popover + Settings — ONCE
│   └── AppState.swift                  # @MainActor ObservableObject — single source of truth
│
├── Engine/
│   ├── DictateEngine.swift             # Background actor — NO UI imports
│   └── TranscriptionResult.swift
│
├── Permissions/
│   └── PermissionChecker.swift         # Checks mic + accessibility, writes AppState
│
├── UI/
│   ├── StatusItem/
│   │   └── DexDictateStatusItem.swift  # NSStatusItem singleton
│   │
│   ├── Popover/
│   │   ├── DictatePopoverController.swift      # NSPopover singleton
│   │   └── Views/
│   │       ├── DictatePopoverView.swift         # Root SwiftUI view, observes AppState
│   │       ├── StatusHeaderView.swift
│   │       ├── MicInputRow.swift
│   │       ├── TriggerSummaryRow.swift
│   │       ├── TranscriptionPreviewBlock.swift
│   │       ├── ErrorBlock.swift
│   │       ├── PermissionsBlock.swift
│   │       ├── PrimaryActionButton.swift
│   │       ├── WaveformView.swift
│   │       └── PopoverFooter.swift
│   │
│   ├── Settings/
│   │   ├── DictateSettingsWindowController.swift   # NSWindowController singleton
│   │   └── Panels/
│   │       ├── MicrophoneSettingsPanel.swift
│   │       ├── TriggerSettingsPanel.swift
│   │       ├── OutputSettingsPanel.swift
│   │       ├── PermissionsSettingsPanel.swift
│   │       ├── DiagnosticsPanel.swift
│   │       └── AdvancedSettingsPanel.swift
│   │
│   └── Onboarding/
│       └── OnboardingWindowController.swift   # Shown once; checked via UserDefaults
│
└── Resources/
    └── Localizable.strings             # All UX copy (see Copy section below)
```

---

## Component Specifications

### DexDictateStatusItem

- Wraps `NSStatusItem` (system length)
- Button image updates based on `AppState.status`:
  - `.idle` → outline mic icon, no tint
  - `.listening` → filled mic icon, red tint
  - `.processing` → outline mic, amber tint
  - `.ready` → checkmark icon, green tint
  - `.error` / `.insertionBlocked` → warning icon, red tint
  - `.permissionNeeded` → lock icon, orange tint
  - `.duplicateInstance` → warning icon, orange tint
  - `.noAudioDevice` → slash mic icon, gray tint
  - `.updateRequired` → up arrow icon, blue tint
- Button click calls `DictatePopoverController.shared.toggle()`

### DictatePopoverController

```swift
final class DictatePopoverController {
    static let shared = DictatePopoverController()
    private let popover = NSPopover()
    
    private init() {
        popover.contentViewController = NSHostingController(
            rootView: DictatePopoverView().environmentObject(AppState.shared)
        )
        popover.behavior = .transient
        popover.animates = true
    }
    
    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

### DictatePopoverView (SwiftUI)

Root view. Switches between state-specific sub-layouts. Width: 296pt fixed.

```swift
struct DictatePopoverView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView(status: appState.status)
            Divider()
            MicInputRow(
                deviceName: appState.micDeviceName,
                isListening: appState.status == .listening,
                isProcessing: appState.status == .processing
            )
            Divider()
            if showsTriggerRow {
                TriggerSummaryRow(mode: appState.triggerMode)
                Divider()
            }
            contentBlock
            actionArea
            Divider()
            PopoverFooter()
        }
        .frame(width: 296)
    }
}
```

### PrimaryActionButton

State-driven. Never imperative.

| AppState.status       | Label               | Style  | Action                          |
|-----------------------|---------------------|--------|---------------------------------|
| `.idle`               | Start Dictation     | Blue   | `engine.startRecording()`       |
| `.listening`          | Stop Recording      | Red    | `engine.stopRecording()`        |
| `.processing`         | Transcribing…       | Gray   | disabled                        |
| `.ready`              | Insert Text         | Green  | `engine.insertTranscript()`     |
| `.error`              | Try Again           | Blue   | `appState.status = .idle`       |
| `.permissionNeeded`   | Open System Settings| Orange | `NSWorkspace.open(privacyURL)`  |
| `.duplicateInstance`  | Quit Other Copy     | Blue   | `terminateOtherInstances()`     |
| `.noAudioDevice`      | Choose Microphone   | Blue   | `settings.show(panel: .mic)`    |
| `.insertionBlocked`   | Open System Settings| Orange | `NSWorkspace.open(privacyURL)`  |
| `.updateRequired`     | Restart DexDictate  | Blue   | `restartForUpdate()`            |

### WaveformView

Seven bars. Decorative — does not read actual audio levels.

```swift
struct WaveformView: View {
    let isActive: Bool
    let color: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<7) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: barHeight(for: i))
                    .animation(
                        isActive ? .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.08) : .default,
                        value: isActive
                    )
            }
        }
        .frame(height: 14)
    }
}
```

---

## Settings Panels

| Panel Key     | Label       | Contents                                                              |
|---------------|-------------|-----------------------------------------------------------------------|
| `microphone`  | Microphone  | Device selector, auto-switch toggle, VAD toggle, silence timeout      |
| `trigger`     | Trigger     | Primary shortcut (editable), toggle mode, double-tap Fn               |
| `output`      | Output      | Insert method selector, auto-insert toggle, clipboard restore toggle, auto-capitalize, punctuation |
| `permissions` | Permissions | Mic status badge + open button; Accessibility status badge + open button |
| `diagnostics` | Diagnostics | Engine status, instance count, Whisper model info, copy diagnostics, reset settings |
| `advanced`    | Advanced    | Launch at login, auto-update, duplicate protection, relaunch, force quit |

---

## Visual Design Tokens

### Colors

Use macOS semantic system colors where possible — they adapt automatically to dark/light mode.

| Token                 | Dark Mode     | Light Mode    | NSColor                        |
|-----------------------|---------------|---------------|--------------------------------|
| `color.idle`          | #636366       | #8e8e93       | `.systemGray`                  |
| `color.listening`     | #ff453a       | #ff3b30       | `.systemRed`                   |
| `color.processing`    | #ff9f0a       | #ff9500       | `.systemOrange`                |
| `color.ready`         | #32d74b       | #34c759       | `.systemGreen`                 |
| `color.info`          | #0a84ff       | #007aff       | `.systemBlue`                  |
| `color.error`         | #ff453a       | #ff3b30       | `.systemRed`                   |
| `color.warning`       | #ff9f0a       | #ff9500       | `.systemOrange`                |
| `surface.popover`     | #1c1c1e + blur| white + blur  | `NSVisualEffectView` (.menu)   |
| `surface.secondary`   | #2c2c2e       | system         | `.controlBackgroundColor`      |
| `surface.tertiary`    | #3a3a3c       | system         | `.quaternaryLabelColor`        |
| `text.primary`        | #f5f5f7       | #000000       | `.labelColor`                  |
| `text.secondary`      | #aeaeb2       | #3c3c43       | `.secondaryLabelColor`         |
| `text.tertiary`       | #636366       | #8e8e93       | `.tertiaryLabelColor`          |
| `border.default`      | rgba(255,255,255,0.10) | rgba(0,0,0,0.10) | `.separatorColor`   |

### Spacing

```
Popover width:         296pt (fixed)
Popover inner padding: 14pt horizontal, 11–13pt vertical per row
Status row height:     ~56pt
Mic row height:        ~30pt
Trigger row height:    ~28pt
Content block:         10–14pt vertical
Action area:           11pt vertical
Footer height:         ~32pt
Row divider:           1pt / NSColor.separatorColor

Button height:         34pt (primary), 26pt (secondary)
Button radius:         8pt (primary), 6pt (secondary)
Settings card radius:  10pt
Popover radius:        12pt
Settings card padding: 10–11pt vertical, 13pt horizontal
```

### Typography

```
Onboarding title:  17pt semibold  NSFont.systemFont(ofSize: 17, weight: .semibold)
Section title:     15pt semibold  NSFont.systemFont(ofSize: 15, weight: .semibold)
Status name:       13pt semibold  NSFont.systemFont(ofSize: 13, weight: .semibold)
Body / label:      13pt regular   NSFont.systemFont(ofSize: 13)
Dense info:        12pt regular   NSFont.systemFont(ofSize: 12)
Mic / trigger row: 11pt regular   NSFont.systemFont(ofSize: 11)
Metadata / caps:   10pt semibold  NSFont.systemFont(ofSize: 10, weight: .semibold)

All CAPS labels use letter-spacing of 0.06–0.08em.
Never use a custom font. Always use -apple-system or NSFont.systemFont.
```

---

## UX Copy (Localizable.strings)

```
/* Status labels */
"status.idle"           = "Idle";
"status.idle.sub"       = "Ready to start a dictation session";
"status.listening"      = "Listening…";
"status.listening.sub"  = "Speak now — release key to transcribe";
"status.processing"     = "Transcribing…";
"status.processing.sub" = "Just a moment";
"status.ready"          = "Ready to Insert";
"status.ready.sub"      = "Text is ready — review and insert";
"status.error"          = "Something went wrong";
"status.permission"     = "Permission Needed";
"status.permission.sub" = "DexDictate can’t run without these";
"status.duplicate"      = "Already Running";
"status.duplicate.sub"  = "Two copies of DexDictate are open";
"status.nodevice"       = "No Microphone Found";
"status.nodevice.sub"   = "Connect or select an audio input device";
"status.update"         = "Restart Required";

/* Primary buttons */
"btn.start"           = "Start Dictation";
"btn.stop"            = "Stop Recording";
"btn.transcribing"    = "Transcribing…";
"btn.insert"          = "Insert Text";
"btn.retry"           = "Try Again";
"btn.open_settings"   = "Open System Settings";
"btn.quit_duplicate"  = "Quit Other Copy";
"btn.select_mic"      = "Choose Microphone";
"btn.restart_update"  = "Restart DexDictate";
"btn.relaunch_clean"  = "Relaunch Cleanly";

/* Secondary buttons */
"btn.cancel"   = "Cancel";
"btn.discard"  = "Discard";
"btn.dismiss"  = "Dismiss";
"btn.later"    = "Later";
"btn.ignore"   = "Ignore";

/* Error messages */
"err.mic_unavailable"     = "The selected microphone was disconnected or is in use by another app.";
"err.transcription_failed" = "Audio was too short, unclear, or the engine timed out. Try again or check your microphone in Settings.";
"err.insertion_blocked"   = "Couldn’t insert text. DexDictate may have lost Accessibility permission.";
"err.engine_crashed"      = "The dictation engine stopped unexpectedly. Relaunch to continue.";
"err.timeout"             = "Transcription took too long and was cancelled.";

/* Error titles */
"err.title.mic_unavailable"      = "Audio Device Unavailable";
"err.title.transcription_failed" = "Transcription Failed";
"err.title.insertion_blocked"    = "Insertion Blocked";
"err.title.engine_crashed"       = "Engine Stopped";

/* Warnings */
"warn.duplicate.title"  = "Duplicate Instance Detected";
"warn.duplicate.msg"    = "Another copy of DexDictate appears to be running. This can cause duplicate menu bar icons. Quit the other copy to continue normally.";
"warn.update.title"     = "Update Ready";
"warn.update.msg"       = "DexDictate %@ is ready to install. Restart the app to complete the update. You can continue using the current version in the meantime.";

/* Permissions */
"perm.mic.name"         = "Microphone";
"perm.mic.desc"         = "Record audio for dictation";
"perm.access.name"      = "Accessibility";
"perm.access.desc"      = "Insert text into other apps";
"perm.status.granted"   = "Granted";
"perm.status.missing"   = "Missing";

/* Onboarding */
"onboarding.welcome.title" = "Welcome to DexDictate";
"onboarding.welcome.desc"  = "Dictate anywhere on your Mac. We need two permissions to get you started.";
"onboarding.mic.title"     = "Microphone Access";
"onboarding.mic.desc"      = "DexDictate needs your microphone to record speech. Audio is processed locally — never uploaded.";
"onboarding.access.title"  = "Accessibility Access";
"onboarding.access.desc"   = "To type text into apps on your behalf, DexDictate needs Accessibility permission in System Settings.";
"onboarding.access.waiting" = "Waiting for permission…";
"onboarding.done.title"    = "All Set";
"onboarding.done.desc"     = "DexDictate is ready. Hold ⌥ Space anywhere to start dictating.";

/* Onboarding buttons */
"onboarding.btn.start"         = "Get Started →";
"onboarding.btn.allow_mic"     = "Allow Microphone →";
"onboarding.btn.open_settings" = "Open System Settings →";
"onboarding.btn.start_dicting" = "Start Dictating";
"onboarding.btn.skip"          = "Set Up Later";
"onboarding.btn.not_now"       = "Not Now";
"onboarding.btn.later"         = "I’ll Do This Later";

/* Settings labels */
"settings.title"           = "DexDictate Settings";
"settings.nav.microphone"  = "Microphone";
"settings.nav.trigger"     = "Trigger";
"settings.nav.output"      = "Output";
"settings.nav.permissions" = "Permissions";
"settings.nav.diagnostics" = "Diagnostics";
"settings.nav.advanced"    = "Advanced";

/* Footer */
"footer.settings"     = "Settings";
"footer.diagnostics"  = "Diagnostics";
```

---

## Onboarding State Persistence (UserDefaults)

```swift
// Keys
let kDidGrantMicrophone     = "didGrantMicrophone"
let kDidGrantAccessibility  = "didGrantAccessibility"
let kDidCompleteOnboarding  = "didCompleteOnboarding"

// On launch:
// 1. If !kDidCompleteOnboarding → show OnboardingWindowController
// 2. If kDidCompleteOnboarding but permissions revoked → show .permissionNeeded in popover
// 3. If all complete and granted → proceed normally to .idle
```

---

## Duplicate Instance Recovery Flow

```
applicationDidFinishLaunching
  │
  ├── runningApplications(withBundleIdentifier:).count > 1?
  │     YES → AppState.status = .duplicateInstance
  │           → Show popover with duplicate warning
  │           → User taps "Quit Other Copy"
  │                 → terminateOtherInstances()
  │                 → Wait for termination (max 2s)
  │                 → AppState.status = .idle
  │           → User taps "Relaunch Cleanly"
  │                 → Quit all instances
  │                 → Relaunch via NSWorkspace
  │           → User taps "Ignore"
  │                 → AppState.status = .idle
  │                 → (duplicate may still be running — user accepted)
  │
  └── count == 1 → Continue normal launch
```

---

## Things This Design Explicitly Does NOT Include

The following were considered and deliberately excluded:

- **Account / sync / cloud features** — DexDictate is local-first. No login, no cloud backup.
- **Team features** — Single-user app. No sharing, no org management.
- **Mascot or character illustrations** — Practical and professional only.
- **Full-screen mode or dock icon** — Menu bar only. LSUIElement = YES.
- **In-app transcription history** — Out of scope for v1. Consider for a future release.
- **Language/model selector in the popover** — Belongs in Settings only.
- **Usage analytics or telemetry UI** — Not applicable to local-first app.

---

## Acceptance Criteria for Implementation

Before shipping, verify:

- [ ] Only one `NSStatusItem` exists in the menu bar at any time, including after sleep/wake cycles and login item restarts
- [ ] `DictateEngine.startRecording()` does not create any UI object
- [ ] Opening Settings twice does not open two windows
- [ ] Clicking the menu bar icon twice rapidly does not create two popovers
- [ ] Launching while another instance is running shows the duplicate warning state (not two icons)
- [ ] All 9 popover states render correctly and transition cleanly
- [ ] Permission polling transitions from `.permissionNeeded` to `.idle` automatically when permission is granted
- [ ] All UX copy matches `Localizable.strings` — no hardcoded strings in view code
- [ ] The app works in both light and dark mode without hardcoded color values
- [ ] First launch shows the onboarding flow; subsequent launches skip it

---

*End of handoff document. Open `DexDictate_UI_Design.html` for the visual prototype.*
