# BUG-005 Validation

## Automated

- `swift build`: clean, exit 0. `SettingsRootView.swift` and
  `SettingsWindowController.swift` both compiled successfully
  ("Build complete! (10.18s)").
- `swift test` (full suite): 410 tests, **0 failures** on first run — no
  known-flaky rerun was needed this time (the documented
  `MainActorActionTests.testRunAsyncExecutesOnMainActor` /
  `MainActorDispatchTests.testAsyncRunsOnMainThreadAsynchronously` flakiness
  did not occur). Log: `swift_test.log` in this directory.
- No targeted test filter exists for Settings navigation specifically (no
  automated test was added — see "Why no regression test" in
  `BUG_005_SETTINGS_NAVIGATION.md`), so the full suite is the only
  automated coverage for this change.
- `./build.sh`: clean, exit 0. Built for production (47.02s), signed with
  "DexDictate Development", installed to `/Applications/DexDictate.app`.
- Relaunch verification: `pkill -x DexDictate_MacOS` then
  `open /Applications/DexDictate.app`; confirmed via `ps aux` that a single
  `DexDictate` process is running post-relaunch.

## Static checks

- `git diff --stat`: touches exactly
  `Sources/DexDictate/SettingsWindow/SettingsRootView.swift` and
  `Sources/DexDictate/SettingsWindow/SettingsWindowController.swift` for
  this fix (plus pre-existing, unrelated `.resurrection/*` modifications
  that predate this session's work and are not part of this change).
- `git diff -- SettingsRootView.swift SettingsWindowController.swift | grep -i "AppStorage\|UserDefaults"`:
  no output — **no storage keys changed.**
- No forbidden files touched (no redesign, no bundled-asset changes, no
  `Package.swift` changes).

## Manual validation checklist — **NEEDS_ANDREW**

I cannot personally click through this LSUIElement menu-bar app on the live
desktop. Andrew, please confirm the following 9 steps:

1. Open Settings (via the menu-bar icon).
2. Click "General" in the sidebar — confirm the General page is already
   showing (default) and controls respond.
3. Click "Dictation" — confirm the detail pane switches to the Dictation
   page content (not still General).
4. Click "Audio & Microphone" — confirm the detail pane switches to the
   Audio & Microphone page content.
5. Click "Output & Insertion" — confirm the detail pane switches
   accordingly.
6. Click "Smart Cleanup" — confirm the detail pane switches accordingly.
7. Click "Advanced" — confirm the detail pane switches accordingly.
8. Click back to "General" — confirm it correctly switches back (not stuck
   on whatever was last selected).
9. Confirm controls on at least one non-General page (e.g. a toggle on
   Advanced or Audio & Microphone) respond to clicks, re-confirming BUG-004's
   fix is still intact alongside this one.

Expected result for all 9 steps: sidebar highlight and detail pane content
always match the clicked page.
