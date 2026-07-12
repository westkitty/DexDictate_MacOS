# Live Caption Surface Visibility Repair

## User symptom

Nemotron's partial-audio-pipeline defect was repaired and proven via real-model tests
(`docs/bug_fixes/nemotron_activation_and_live_transcription.md`, "Ready-but-no-partials
defect" section) — `engine.liveTranscript` genuinely updates while speaking. Despite that,
the user still saw absolutely nothing appear anywhere in the app while dictating: no
caption, no popup, no floating window, no visible transcript.

## Confirmed failure category

**UI-7 combined with UI-8**, compounded by a third, independent defect not on the original
checklist:

1. **UI-7 — the only consumer that's normally visible during real dictation is inside the
   menu-bar popover, which is closed during real use.** `DexTranscriptCard` (in
   `PopoverRootView`) reads `engine.liveTranscript` directly and would show it correctly —
   but a `MenuBarExtra` popover is not a persistent window; the ordinary dictation workflow
   is "click into a text field in some other app, then dictate," which closes the popover
   before or during the very first attempt.
2. **UI-8 — the one persistent, always-visible surface (`FloatingHUDView`, which already
   correctly embeds `LivePreviewCaptionView`) is gated behind an entirely separate setting,
   `showFloatingHUD`, that defaults `false`.** `DexDictateApp.swift` only called
   `hudController.show()` if that setting was on; enabling Live Preview (default **on**,
   confirmed in `AppSettings.swift`) had zero effect on whether any window appeared.
3. **A third defect that would have broken the Floating HUD even for a user who manually
   turned `showFloatingHUD` on:** `FloatingHUDWindow` is an `NSPanel` subclass that never
   set `hidesOnDeactivate`. **`NSPanel` defaults this property to `true`** (unlike
   `NSWindow`, which defaults `false` — this is a well-documented but easy-to-miss AppKit
   asymmetry). DexDictate is an `LSUIElement` menu-bar app whose entire purpose is showing
   this HUD *while the user types into some other app*. The moment the user clicks into
   that target app — the normal dictation workflow — DexDictate resigns active status, and
   the panel silently hides itself, regardless of the "Show Floating HUD" setting.

A fourth, smaller gap was also found: `DexNanoHUDView` (the experimental compact HUD
variant) only ever shows `engine.liveTranscript` during `.transcribing` (the post-recording
handoff), never during `.listening` — it doesn't wire in `LivePreviewController` at all.

## Why provider tests passed while the user saw nothing

The previous investigation proved `engine.liveTranscript` genuinely changes with real
partial text from Nemotron — that is a fact about `TranscriptionEngine`'s internal state,
verified directly and correctly. It says nothing about whether any *window* is on screen to
render that state. These are two entirely separate concerns (data flow vs. window
lifecycle), and this investigation is specifically about the second one. No part of the
prior fix touched, or needed to touch, window/HUD code.

## Existing surfaces found

| Surface | Shows live text? | Visible during real dictation? |
|---|---|---|
| `DexTranscriptCard` (slim popover) | Yes, unconditionally | No — popover closes once you click into your target app |
| `FloatingHUDView` (standard Floating HUD) | Yes, via `LivePreviewCaptionView` (already correct) | No — gated behind `showFloatingHUD` (default off), and would auto-hide via `hidesOnDeactivate` even if on |
| `DexNanoHUDView` (Nano HUD) | Only during `.transcribing`, never `.listening` | Same gating as standard HUD, plus this content gap |

## Actual display-contract defect

Enabling "Live Preview" (a feature specifically about seeing live captions) had **no
effect whatsoever** on whether any surface appeared. The only surface that could show live
text automatically required the user to separately discover and enable an unrelated
setting ("Show Floating HUD"), and even then would have silently disappeared during actual
use due to the `hidesOnDeactivate` default. This is precisely the broken contract described
in the task: a feature that appears broken because its visible effect depends on a second,
undocumented dependency.

## Fix

**`Sources/DexDictateKit/LivePreview/LivePreviewController.swift`** — added
`@Published public private(set) var shouldShowCaptionSurface: Bool`, set `true` in
`beginSession()` and `false` (unconditionally) in `endSession(clearImmediately:)`. This
gives Live Preview its own, independent authority over "is there something worth showing
right now" — true from the moment `.listening` begins through the `.transcribing`
finalizing phase, false once the engine returns to idle (matching the existing
`caption`/`isFinalizing` lifecycle exactly, since it's driven by the same
`beginSession()`/`endSession()` calls).

**`Sources/DexDictateKit/LivePreview/FloatingHUDVisibilityDecision.swift`** (new) — two
pure, dependency-free enums:
- `FloatingHUDVisibilityDecision.isVisible(showFloatingHUD:shouldShowCaptionSurface:)` —
  the window should be visible if *either* reason wants it.
- `FloatingHUDVisibilityDecision.useNanoContent(...)` — Nano HUD's compact layout has no
  room for a caption row, so whenever Live Preview is the reason the window is visible, the
  standard (caption-capable) `FloatingHUDView` is always used; Nano HUD is reserved for the
  case where the window is visible *only* because of the persistent "Show Floating HUD" +
  "Nano HUD" settings, with no live caption currently needed.
- `FloatingHUDFramePositioning.correctedFrame(_:visibleFrames:)` — recovers a window
  position that referenced a display disconnected since the last saved frame.

These live in `DexDictateKit` (not alongside the controller in the `DexDictate` executable
target) for the same reason `LivePreviewController` itself does — so
`Tests/DexDictateTests` can exercise them via `@testable import DexDictateKit` without
adding the `@main`-attributed executable target as a test dependency.

**`Sources/DexDictate/FloatingHUD.swift`**:
- `FloatingHUDWindow.init` now explicitly sets `self.hidesOnDeactivate = false`.
- `FloatingHUDController` gained `refreshVisibility()` — the single entry point for every
  visibility decision, subscribed to `livePreviewController.$shouldShowCaptionSurface` (so
  Live Preview's own state changes trigger it automatically) and called whenever
  `showFloatingHUD`/`useExperimentalNanoHUD` change. It computes the decision via
  `FloatingHUDVisibilityDecision` and shows/hides/rebuilds the window's content accordingly.
- The old `show()` (no-args, only ever built content from `useExperimentalNanoHUD` and only
  built once), `toggle(shouldShow:)`, and `refresh()` methods were removed — all three call
  sites' concerns are now handled correctly by `refreshVisibility()` alone, which also
  fixes a related latent gap: `show()` never rebuilt content if `useExperimentalNanoHUD`
  changed while the window was hidden (previously papered over by a separate `refresh()`
  call after every settings change — now `refreshVisibility()` itself detects the content
  mismatch and rebuilds).
- Off-screen frame recovery: when (re)building the window, `NSScreen.screens` visible
  frames are checked against the restored autosave frame; if it doesn't intersect any
  current screen (e.g. an external display was disconnected since last launch), the frame
  is recentered on the primary available screen instead of leaving the window unreachable.

**`Sources/DexDictate/DexDictateApp.swift`** — the `.onAppear` block and the
`.onChange(of: settings.showFloatingHUD)` / `.onChange(of: settings.useExperimentalNanoHUD)`
handlers now all call `hudController.refreshVisibility()` instead of the removed
`show()`/`toggle(shouldShow:)`/`refresh()` methods.

## Window lifecycle / focus / non-activation behavior

- **Style mask**: unchanged — `[.nonactivatingPanel, .hudWindow, .utilityWindow, .titled]`.
  `.nonactivatingPanel` already meant clicking the HUD never activates the app or makes it
  key/main — this was already correct and required no fix.
- **`hidesOnDeactivate`**: **fixed** — explicitly `false` (was implicitly `true`, NSPanel's
  default).
- **Level**: unchanged — `.floating`, stays above normal app windows.
- **Collection behavior**: unchanged — `[.canJoinAllSpaces, .fullScreenAuxiliary]`, visible
  across Spaces and full-screen apps.
- **Mouse events**: unchanged logic, still correctly conditional — `ignoresMouseEvents` is
  `true` for the standard (caption) content (nothing to click, so clicks pass through to
  whatever's underneath) and `false` for Nano HUD content (which has a tappable hub button).
- **Off-screen recovery**: added (see above).

## Settings behavior

- **`Sources/DexDictate/SettingsWindow/DictationSettingsPage.swift`** — Live Preview's
  description now says the caption "appears on its own the moment you start dictating and
  disappears when you're done, with no other setting required," and explicitly states that
  "Show Floating HUD" is unrelated and has no effect on it.
- **`Sources/DexDictate/SettingsWindow/GeneralSettingsPage.swift`** — "Show Floating HUD"
  (previously a bare, undescribed toggle) now has an explanatory description via
  `SettingToggleWithInfo`, clarifying it's a separate, always-on general status window and
  cross-referencing Live Preview.

No contradictory toggles remain: "Show Floating HUD" controls a persistent general-status
window; "Live Preview" controls its own caption surface automatically, independent of that
setting, per the task's explicit "Live Preview controls the caption surface directly"
preference.

## Files changed

- `Sources/DexDictateKit/LivePreview/LivePreviewController.swift`
- `Sources/DexDictateKit/LivePreview/FloatingHUDVisibilityDecision.swift` (new)
- `Sources/DexDictate/FloatingHUD.swift`
- `Sources/DexDictate/DexDictateApp.swift`
- `Sources/DexDictate/SettingsWindow/DictationSettingsPage.swift`
- `Sources/DexDictate/SettingsWindow/GeneralSettingsPage.swift`
- `Tests/DexDictateTests/FloatingHUDVisibilityTests.swift` (new)

## What did not change

- Nemotron/audio-buffer-ordering: untouched (previous session's fix stands as-is).
- Smart Cleanup: untouched.
- Apple Speech permissions: untouched.
- Final (batch Whisper) transcription and output insertion: untouched.
- Typography (`DexSettingsTypography.swift` components) and Dexter watermark rendering:
  untouched — `GeneralSettingsPage.swift`/`DictationSettingsPage.swift` edits only changed
  `Toggle`/`SettingToggleWithInfo` copy strings, not any typography component or the
  watermark view.
- No storage keys renamed — `showFloatingHUD`, `useExperimentalNanoHUD`, `livePreviewEnabled`
  all keep their existing `@AppStorage` keys and default values.
- `DexNanoHUDView`'s lack of a `.listening`-state caption was deliberately **not** patched
  to add captions into its own compact layout — see "Remaining limitation" below for why,
  and how the canonical-layout choice already covers it structurally.

## Tests added

`Tests/DexDictateTests/FloatingHUDVisibilityTests.swift` (new, 18 tests) — tests the
coordinator's decisions, not SwiftUI views, and never constructs an actual
`NSWindow`/`NSPanel`:

- `FloatingHUDVisibilityDecision.isVisible`/`useNanoContent` — 7 tests covering every
  combination of the three boolean inputs.
- `FloatingHUDFramePositioning.correctedFrame` — 3 tests (already-visible, off-screen
  recovery, empty-screens edge case).
- `LivePreviewController.shouldShowCaptionSurface`'s real lifecycle (real `TranscriptionEngine`
  + real `LivePreviewController`, no fakes, same pattern as the existing
  `LivePreviewInvariantTests.swift`) — 8 tests: becomes true on listening start, stays false
  when Live Preview is disabled, stays true through finalizing, becomes false on completion,
  becomes false on cancellation, resets correctly for a new session (including clearing
  stale caption text), stays false after being disabled mid-session (kill-switch-equivalent
  path), and a structural no-popover-dependency demonstration.

## Validation status

- `swift build` — success (only the two pre-existing, unrelated warnings, unchanged).
- `swift test` — 485/485 passing across 3 consecutive full runs (3 environment-dependent
  skips). One isolated run showed 2 transient failures not reproduced in any of 4 other full
  runs across this and the prior session — consistent with the same environmental flakiness
  already noted in `nemotron_activation_and_live_transcription.md`, not a defect in these
  changes.
- `./build.sh` — success; installed to `/Applications/DexDictate.app`.
- `git diff --check` — clean.
- Manual GUI validation: **not performed.** This environment has no Accessibility
  permission for AppleScript/System Events UI scripting (`UI elements enabled` → `false`
  under `osascript`, confirmed by direct attempt). See the final response's "Andrew
  validation command" for the exact manual check.

## Remaining limitations

- `DexNanoHUDView` still does not render a live caption during `.listening` — by design,
  per this fix's "canonical caption layout" choice: whenever Live Preview needs to show a
  caption, the window automatically uses the standard `FloatingHUDView` instead of Nano HUD,
  so a user who has Live Preview enabled always sees captions regardless of their Nano HUD
  preference. Nano HUD's own `.listening` state (no caption, just the mic meter) is only
  ever seen when Live Preview has nothing to show (disabled, or genuinely no words yet) —
  this was judged the safer, smaller-footprint choice over threading `LivePreviewController`
  into Nano HUD's narrow, `.fixedSize()` compact layout, which risks breaking its whole
  design premise for a HUD variant that's still explicitly experimental.
- No visual/GUI validation was performed in this environment (see above); Andrew should
  confirm the caption window actually appears the moment dictation starts (with "Show
  Floating HUD" left off), stays visible while clicking into another app to type, and
  disappears again once dictation ends.
