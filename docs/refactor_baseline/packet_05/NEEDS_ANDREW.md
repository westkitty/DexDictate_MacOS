# Packet 05 — Screenshot / Manual Validation Gaps

Same LSUIElement/accessibility blocker as Packets 01–04 — cannot click through the popover
or Settings window in this environment.

Not captured this packet:
- Screenshot: Output & Insertion page
- Screenshot: Per-App Rules surface (window opened from the new page)
- Screenshot: remaining Output card (post-hide)

Manual validations not performed (require live UI interaction and/or real audio):
- Per-app rule round-trip (configure a rule for a specific app, confirm it copies instead
  of pastes, remove the rule, confirm behavior reverts)
- Password-field dictation → copy-only fallback trigger
- Clipboard-restore test (copy a string → dictate → confirm original clipboard restored)
- All toggle round-trips (auto-paste off → result copied not pasted, etc.)

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: `swift test --filter "AppInsertionOverrides|SecureInputContext|OutputCoordinator|ClipboardManager"` — 59/59 passed
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice to
  rule out a crash loop)
- Full `git diff` reviewed: only `QuickSettingsView.swift` (rows hidden behind two new
  flags, `showLegacyOutputRows` and `showLegacyCorrectionSheetRow`; Safe Mode and Show
  Floating HUD deliberately left visible, out of this packet's scope) and
  `SettingsWindow/OutputSettingsPage.swift` (built out) touched. `PerAppInsertionSheet.swift`:
  zero lines touched — see button-vs-embed decision below. No forbidden files touched. No
  `@AppStorage` key added/removed/renamed (grepped the diff).

## Button-vs-embed decision

`PerAppInsertionView` (in `PerAppInsertionSheet.swift`) is a self-contained content view with
its own fixed `.frame(width: 540, height: 460)`, designed as standalone window content — not
built to embed inline in a variable-width settings page. Per the packet's own stated
preference ("keep this sheet/window as-is... embed ONLY if trivially re-hostable with zero
logic edits"), I used the **button** approach: `OutputSettingsPage` has a
"Manage Per-App Rules…" button that opens a second window hosting the exact same
`PerAppInsertionView(manager: TranscriptionEngine.shared.appInsertionOverridesManager)` —
identical window-creation code to the popover's `openPerAppInsertionWindow()`, just a second
call site. Zero edits to `PerAppInsertionSheet.swift`. Because the same unmodified view
renders the rules surface either way, the destructive "Replace Entire Field" warning text
is preserved verbatim by construction (no transcription/duplication risk).
