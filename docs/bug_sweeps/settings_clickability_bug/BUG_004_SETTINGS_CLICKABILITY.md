# BUG-004: Settings Window Controls Do Not Respond to Clicks

## Status

Fixed (highest-confidence root cause identified and addressed). See "Confidence and
remaining risk" below for what could not be verified live.

## Root cause

The Floating HUD (`Sources/DexDictate/FloatingHUD.swift`, `FloatingHUDWindow`) is created
at `NSWindow.Level.floating` — a level **above** every normal app window, including the
Settings window (`.normal`), the History window, and the Help window. Two things make it
land on top of Settings specifically, and stay there:

1. **It centers itself on first use.** `FloatingHUDController.show()` contains:
   ```swift
   if window?.frame.origin == .zero {
       window?.center()
   }
   ```
   The Settings window *also* centers itself (`SettingsWindowController.show()`:
   `newWindow.center()`). On a fresh install, or any time the HUD's autosaved position
   happens to reset to `.zero`, both windows center on the **exact same screen point** —
   guaranteeing maximum overlap right where a user's eye and cursor naturally go first.

2. **Its position persists indefinitely** via `window?.setFrameAutosaveName("FloatingHUDPosition")`,
   so once it lands somewhere overlapping Settings, it stays there across every future
   launch until the user manually drags it away (which nothing in the UI currently prompts
   them to do, since the HUD is easy to overlook — it's a small, semi-transparent
   `.ultraThinMaterial` strip).

Unlike `LaunchIntroController`'s intro panel — which explicitly sets
`ignoresMouseEvents = true` specifically so it never blocks interaction with whatever is
underneath it — `FloatingHUDWindow` set no such flag. Confirmed via `grep` that the
**standard** `FloatingHUDView` (the default HUD style; `useExperimentalNanoHUD` is off by
default) has **zero click-driven content** anywhere in its view body — no `Button`, no
`.onTapGesture`. It was blocking clicks to the window underneath for literally no
functional benefit of its own.

The **Nano HUD** variant (`DexNanoHUDView`, opt-in via `useExperimentalNanoHUD`) is
different: it wires `onOpenHub` to `FloatingHUDController.showHubPanel()`, so tapping it
*is* meant to do something. Both variants share the same `FloatingHUDWindow` class, so the
fix had to be conditional, not a blanket "ignore all mouse events."

## Why the prior bug sweep missed this

The post-campaign bug sweep (`docs/bug_sweeps/post_campaign_bug_sweep/`) was a code-level
audit — it checked storage keys, default-off states, dangling references, and diffed
every file touched by the UI/UX recovery campaign against forbidden-file lists. It did not
(and, per its own documented LSUIElement/accessibility blocker, could not) perform a live
click-through of the Settings window. `FloatingHUD.swift` was not touched by that campaign
at all (Packet 14 only added a `livePreviewController` parameter and extracted
`statusContent` to fix a SwiftUI type-checker timeout — the window-level/mouse-events
logic was untouched, unreviewed, and, it turns out, had carried this defect since
whenever the Floating HUD was first built, well before this whole campaign). A
window-overlap bug like this is invisible to static diffing and to every automated test in
the suite (none of them create real `NSWindow`s and check on-screen z-order) — it can only
surface via an actual human clicking through the running app, which is exactly what Andrew
did to report this.

## Files changed

- `Sources/DexDictate/FloatingHUD.swift` — added one line (`window?.ignoresMouseEvents =
  !AppSettings.shared.useExperimentalNanoHUD`) plus an explanatory comment, right after
  the Floating HUD window is created in `FloatingHUDController.show()`.
- `Sources/DexDictate/DexDictateApp.swift` — one incidental whitespace fix (removed a
  trailing-whitespace line left over from adding/removing temporary diagnostics during
  investigation; zero functional change).

No other files were modified. All temporary diagnostic code (a throwaway debug button in
`GeneralSettingsPage.swift`, a debug-flag-guarded auto-open hook in `AppDelegate`) was
added during investigation and fully removed before this fix was finalized — confirmed via
`grep -rn "TEMPORARY DIAGNOSTIC\|BUG004" Sources/` returning no results.

## Exact fix

```swift
// Sources/DexDictate/FloatingHUD.swift, inside FloatingHUDController.show()
window?.ignoresMouseEvents = !AppSettings.shared.useExperimentalNanoHUD
```

When the standard HUD is showing (the default), mouse events pass through it to whatever
window is underneath — restoring click access to Settings (or History, Help, or any other
normal window) even when the HUD happens to be sitting on top of it. When the Nano HUD is
showing (opt-in, `useExperimentalNanoHUD == true`), mouse events are still delivered to it
normally, preserving its tap-to-open-hub-panel behavior. `FloatingHUDController.refresh()`
already tears down and recreates the window whenever `useExperimentalNanoHUD` changes, so
this flag is always re-evaluated correctly against the current setting.

## How this was investigated

1. Read `SettingsWindowController.swift`, `SettingsRootView.swift`, `SettingsSidebar.swift`,
   `GeneralSettingsPage.swift`, `ChromeButton.swift`, `QuickSettingsView.swift`'s reused
   `SettingToggleWithInfo` — nothing in the SwiftUI view hierarchy itself looked broken
   (no disabled-parent propagation, no invisible full-window overlay in the view tree, no
   broken bindings).
2. Compared against `HistoryWindowController`/`HelpWindowController` — same
   `NSWindow`/`makeKeyAndOrderFront`/`NSApp.activate()` pattern, ruling out the window
   activation call itself as campaign-introduced or Settings-specific.
3. Added a temporary, environment-guarded debug hook to reproduce
   `SettingsWindowController.show()` directly from `applicationDidFinishLaunching` (so it
   didn't require clicking the menu-bar icon first) and a throwaway always-enabled test
   button in `GeneralSettingsPage`, purely to get the window open and rendered for
   inspection without needing Accessibility-driven UI automation (which this environment
   does not have — confirmed via `osascript`: `"osascript is not allowed assistive
   access. (-1719)"`).
4. Used `CGWindowListCopyWindowInfo` (Quartz Window Services — read-only, no Accessibility
   permission required) to inspect real on-screen window bounds, layers, and ownership.
   This revealed a second `DexDictate`-owned window at layer 25 (a `.statusBar`/high
   level) overlapping the Settings window's exact bounds for several seconds after
   launch — this turned out to be the launch intro animation panel, not the bug (it
   already correctly sets `ignoresMouseEvents = true`).
5. **Stopped attempting synthetic mouse-click injection immediately** after a full-screen
   screenshot revealed this is a live, shared, multi-monitor desktop with the user's own
   unrelated running applications and windows visible (a separate AI agent app, browser
   tabs with API key fields, etc.) — continuing to post OS-level synthetic clicks at
   guessed coordinates on a shared desktop was an unacceptable risk of misclicking into
   something unrelated. All synthetic-click tooling was deleted immediately and no further
   clicks were attempted.
6. Re-examined `FloatingHUD.swift` specifically because it was the one file, among
   everything read, that both (a) creates a window at a level above Settings, and (b) had
   no `ignoresMouseEvents` protection unlike its sibling `LaunchIntroPanel`. Confirmed via
   `grep` that the standard HUD content has no click-driven behavior to preserve, making
   the fix unambiguously safe.
7. Removed all temporary diagnostics, applied the real fix, rebuilt, and validated.

## Manual validation required (NEEDS_ANDREW)

This sweep could not click through the running app — same LSUIElement/accessibility
limitation as every prior packet in this project, and this investigation additionally
identified a **new, separate reason** not to attempt synthetic clicks here: doing so on
your live, shared desktop risks interacting with unrelated running applications. See
`VALIDATION.md` for the exact steps to confirm this fix live.
