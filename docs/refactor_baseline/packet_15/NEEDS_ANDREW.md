# Packet 15 — Visual Polish

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation possible (menu bar style grid selection, Settings window in Light
Mode vs. Dark Mode, WarningCallout rendering, sidebar label truncation at the new width).

## HUD placement review

No specific HUD placement change was requested or pre-specified for this packet, and the
handoff's Packet 15 goal list only asks to "review" placement, not change it. I read
`FloatingHUD.swift` and confirmed the Nano HUD's positioning logic is unchanged from
Packet 12A (already adopted in production via `useExperimentalNanoHUD`). Reporting current
placement only — no code change made here since nothing was broken and no direction was
given on what a different placement should be.

## Known-MISSING items (carried forward from Packet 12A, unchanged)

Still outstanding, still blocking gated Packet 12B, still not actioned since 12B has not
been approved:
1. Pinned "daily six" compact controls (trigger/model/mode/output chips).
2. Live transcript + mic level meter while actively listening (real usability gap in the
   now-default slim popover, flagged in 12A, not fixed here — out of scope for a
   presentation-only polish packet).
3. Dexter Feed (stateful quote browser) — no standard-UI home.

## What WAS verified for real

- `swift build` — clean after every change.
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline exactly).
- `./build.sh` succeeded; app reinstalled to `/Applications/DexDictate.app` and relaunched;
  confirmed running via `ps aux` (PID present, `R` state, no crash).
- Full `git diff --stat -- Sources/` reviewed: 15 files changed
  (`PerAppInsertionSheet.swift`, `QuickSettingsView.swift`, all 10 built-out
  `SettingsWindow/*Page.swift` files, `SettingsRootView.swift`, `SettingsSidebar.swift`,
  `SurfaceTokens.swift`) plus one new file (`WarningCallout.swift`). No forbidden files
  touched (`grep` against the forbidden list — none matched).
- `git diff -- Sources/ | grep "@AppStorage"` — zero results. No storage-key changes; every
  edit this packet is presentation-only (padding tokens, a Picker→icon-grid swap on the
  existing `$settings.menuBarDisplayMode` binding, a sidebar `minWidth` bump, a new
  reusable warning-callout view wrapping byte-identical warning text, and one
  `.preferredColorScheme(.dark)` line).

## Notable judgment call: `.preferredColorScheme(.dark)` on the Settings window

Discovered mid-packet that the Settings window (a normal `NSWindow`, unlike the always-dark
popover) would render illegibly under system Light Mode, because dozens of controls
re-hosted from the popover across Packets 03–12A use hardcoded `.white`-opacity styling
(`SettingToggleWithInfo`, `MenuBarSettingsSection`, etc.). Rather than rewrite every reused
component's colors to adaptive semantic colors (large, multi-file, higher-risk for a
"visual polish, zero behavior change" packet), I forced `.preferredColorScheme(.dark)` on
`SettingsRootView`'s body — matches how the popover's own `system` theme already renders
dark, single line, fully reversible, documented inline with a code comment explaining why.
This is a visible behavior change (Settings window no longer follows System Light Mode)
but not a *feature* behavior change — flagging it explicitly since it's the one edit in
this packet that a user could actually notice, in case Andrew wants the larger adaptive-
color rewrite instead in a future packet.
