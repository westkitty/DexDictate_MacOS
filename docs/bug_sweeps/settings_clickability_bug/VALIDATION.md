# BUG-004 Validation

## Automated validation performed

- `swift build`: clean, zero errors, zero new warnings beyond the pre-existing
  `fluidaudio` unhandled-resource notice.
- `swift test`: 410 tests, 1 failure on first run
  (`MainActorActionTests.testRunAsyncExecutesOnMainActor`, the documented pre-existing
  flaky test, unrelated to this fix — same async-ordering-race family already accepted by
  this project). Rerun via `swift test --filter MainActorActionTests`: 2/2 passed clean.
  Net: 410/410 effectively passing.
- `./build.sh`: clean build, sign, install to `/Applications/DexDictate.app`.
- Relaunch: confirmed running and stable via `ps aux` (steady CPU, stable RSS) several
  seconds after launch.
- `git diff --stat`: exactly 2 files changed — `Sources/DexDictate/FloatingHUD.swift` (the
  real fix, 12 lines) and `Sources/DexDictate/DexDictateApp.swift` (1 incidental
  whitespace-only line, left over from removing temporary diagnostics).
- `git diff | grep "@AppStorage\|UserDefaults"`: no output — zero storage-key changes.
- Confirmed all temporary diagnostic code was removed before this fix was finalized:
  `grep -rn "TEMPORARY DIAGNOSTIC\|BUG004" Sources/` returns nothing.
- Read-only window inspection via `CGWindowListCopyWindowInfo` (Quartz Window Services,
  no Accessibility permission required) confirmed: the Floating HUD window is created at
  `NSWindow.Level.floating` (Quartz layer 25, above Settings' layer 0), its position
  persists via `setFrameAutosaveName`, and it centers itself on first use — corroborating
  the root cause independent of the (aborted) synthetic-click test.

## Regression test

**Not added.** `FloatingHUDController`/`FloatingHUDWindow` live in
`Sources/DexDictate/` (the app executable target), and `Tests/DexDictateTests` only
depends on `DexDictateKit`/`DexDictateObjCSupport` in `Package.swift` — the same
structural constraint documented in Packet 14's bug sweep (`docs/refactor_baseline/packet_14/NEEDS_ANDREW.md`)
when `LivePreviewController` was moved into `DexDictateKit` specifically so it could be
unit tested. Moving `FloatingHUDController` (a real, working, pre-existing file, not new
campaign code) into `DexDictateKit` purely to enable a unit test would be a disproportionate,
un-narrow change for a one-line bug fix, and risks the same kind of `Package.swift`
destabilization flagged as too risky in Packet 14. Additionally, meaningfully testing
`ignoresMouseEvents`'s *effect* (does a click actually reach the window underneath) isn't
something an XCTest can observe at all — it requires real on-screen window compositing and
a real mouse event, which is exactly the live-interaction gap this bug fix itself is about.
Documented here per the task's own explicit allowance rather than fabricating a test that
wouldn't actually catch a regression.

## Manual validation required (NEEDS_ANDREW)

This investigation could not click through the running app. Beyond the usual
LSUIElement/accessibility limitation (confirmed again: `osascript` returns "not allowed
assistive access"), this investigation surfaced an **additional, more serious reason** not
to attempt it here: a full-screen screenshot taken mid-investigation revealed this is a
live, shared, multi-monitor desktop with your own other applications and windows actually
open and in view (a separate agent app, browser tabs, what appeared to be API key entry
fields in another tool). Posting synthetic OS-level mouse clicks at guessed screen
coordinates on that shared desktop risked landing on something unrelated. All
synthetic-click tooling was deleted the moment this was discovered, and no clicks were
ever successfully sent.

Please verify:

1. Quit DexDictate completely if it's running (`Cmd+click` the power icon → confirm in
   the alert, or however you'd normally quit it) and relaunch it fresh.
2. Open the Settings window (gear icon in the popover, or however you normally reach it).
3. Click through all sidebar pages — General, Dictation, Audio & Microphone, Output &
   Insertion, Vocabulary & Commands, Models & Accuracy, Smart Cleanup, History, Dexter &
   Personality, Diagnostics & Recovery, Advanced. Confirm each one responds and loads.
4. On the General page specifically (this is the page your screenshot showed):
   - Toggle "Play Start Sound" on, then off.
   - Toggle "Play Stop Sound" on, then off.
   - Toggle "Launch at Login" — then toggle it back to whatever it was before, since this
     one has a real system-level effect.
   - Toggle "Show Floating HUD" — then restore it to whatever it was before (this is the
     exact setting controlling the window this fix touched, so it's worth specifically
     re-confirming Settings stays clickable with the HUD toggled both on and off).
   - Click "Status Color" → "Reset" (only enabled if you've customized the color — if
     it's greyed out, that's normal, not a new bug).
   - Click each of the five Menu Bar Style cards (Mic + Text, Mic Only, Dex Icon, Logo
     Only, Emoji) and confirm the selected one visually updates.
5. Close Settings, reopen it, and confirm anything you changed in step 4 persisted.
6. If you have "Show Floating HUD" enabled and can see the HUD strip somewhere on screen:
   confirm it's still visually present and its own display still works (it shouldn't have
   lost any functionality — it never had click-driven behavior to begin with, in the
   standard, non-experimental style).
7. If you use the Nano HUD experimental style (Settings → Advanced → "Nano HUD"):
   confirm tapping the Nano HUD still opens its "All Features" hub panel — this is the one
   piece of HUD click behavior that must keep working, and this fix was specifically
   written to preserve it.

If Settings is still unclickable after this fix, please let me know exactly which
control(s) still fail and whether the Floating HUD is visible/enabled at the time — that
would mean either the HUD isn't the (sole) cause, or there's a second contributing factor
(e.g. the window-activation/key-window angle noted as a remaining risk in the final
report) that needs a follow-up investigation.
