# Packet 02 — Screenshot / Manual Validation Gaps

Same blocker as Packet 01: DexDictate is an `LSUIElement` menu-bar-only app with no Dock
presence. `computer-use`'s `request_access` cannot match it by display name or bundle ID
(`com.westkitty.dexdictate.macos`) — "doesn't match any installed or running application" —
and this shell has no Accessibility (System Events) grant for AppleScript automation of its
menu bar item. Result: I cannot click the menu bar icon, open the popover, click the new
gear button, or drive the Settings window's sidebar to capture the required screenshots
(settings window on General; sidebar showing all 11 items; popover header with gear).

Not captured this packet:
- Screenshot: Settings window on General page
- Screenshot: sidebar showing all 11 items
- Screenshot: popover header with gear button visible

Manual validations not performed (require live UI interaction and/or a real dictation):
- Window opens/closes cleanly; sidebar navigates all 11 pages; reopening restores last page
- Dictation with the settings window open AND after close (no focus-stealing) — needs Andrew
  at the mic
- Quit Settings still opens correctly

What WAS verified for real:
- `swift build` — clean, no new warnings from this packet's files
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline exactly)
- `./build.sh` succeeded; app launched and confirmed running via `ps aux`
- Full `git diff` reviewed: only `Sources/DexDictate/DexDictateApp.swift` touched (13 lines:
  one `@StateObject`, one closure param/wire-up, one gear `ChromeIconButton`) plus the new
  `Sources/DexDictate/SettingsWindow/` directory (11 stub pages + sidebar + root view +
  window controller). `QuickSettingsView.swift` untouched, as required. No forbidden files
  touched. No `@AppStorage`/`UserDefaults` keys added or changed (grepped the diff).

Andrew: if you want real screenshots/interaction validation for this and later packets,
either grant this shell Accessibility access (System Settings → Privacy & Security →
Accessibility) so AppleScript/System Events can drive the menu bar, or let me know another
way to reach the app's UI programmatically. Until then, every UI-changing packet will
carry this same gap, documented per-packet rather than blocking the run (per your
"non-blocking, keep going" instruction).
