# Packet 03 — Screenshot / Manual Validation Gaps

Same LSUIElement/accessibility blocker as Packets 01–02 (see those NEEDS_ANDREW.md files for
detail) — I cannot click through the popover or the Settings window in this environment.

Not captured this packet:
- Screenshot: General page
- Screenshot: Appearance & System card after hiding rows

Manual validations not performed (require live UI interaction and/or real audio):
- Round-trip check for each migrated control (change in Settings → close → reopen →
  persisted; value honored by the app: icon changes live, sounds play/don't play, Launch at
  Login registers with the system)
- Replay Onboarding presents the wizard; completing/cancelling returns cleanly
- Visual confirmation that the old card no longer shows migrated rows

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- `./build.sh` succeeded; app launched and confirmed running via `ps aux`
- Full `git diff` reviewed: only `QuickSettingsView.swift` (rows hidden behind
  `showLegacyGeneralRows = false`, four private view structs widened to internal so
  `GeneralSettingsPage` can reuse them verbatim) and
  `SettingsWindow/GeneralSettingsPage.swift` (built out) touched. No forbidden files. No
  `@AppStorage`/`UserDefaults` key added, removed, or renamed — grepped the diff for
  `@AppStorage` lines, zero hits (all migrated controls bind through the same
  `AppSettings.shared` properties as before; only the UI call site moved).
- Confirmed `MenuBarSettingsSection`, `MenuBarIconPreview`, `MenuBarDisplayPreview`, and
  `EmojiIconPicker` are self-contained (no lifecycle hooks, no external private
  dependencies) before widening their access from fileprivate to internal — this was the
  only change needed to reuse them from a second file without duplicating any logic.
- Lifecycle finding (see PACKET_RESULT.md "Known issues"): `QuickSettingsView`'s own
  `onAppear` refreshes `launchAtLoginController` and `menuBarIconController` state, which
  only fires when the popover opens. Replicated the same two calls in
  `GeneralSettingsPage.onAppear` so Settings → General shows correct state even if opened
  before the popover ever has been.
