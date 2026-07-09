# Packet 09 — Stage B Withheld + Screenshot/Manual Validation Gaps

## Stage B (default flip) was NOT executed — here's why

Stage A is complete, tested, committed, and pushed: `PopoverRootView` and its three
sub-views exist, compile, and are reachable by setting `useSlimPopover = true` (no UI
exposes this yet — it's the Stage-A debug flag, default `false`). The classic
`AntiGravityMainView` remains the default popover, completely unchanged in behavior.

Stage B is "flip the default to the new popover." I did not do this. Reason:

Per Packet 08B's final inventory, five controls are still reachable **only** through the
classic popover's Quick Settings stack: Profile picker, Return to Standard button, Show
Flavor Ticker toggle, Animate Flavor Ticker toggle, and the Theme/Appearance picker. All
five are explicitly assigned to Packet 11 (Dexter & Personality), which has not run yet.

The new `PopoverRootView` (built exactly to this packet's contract) has **no UI for any of
these** — the contract doesn't include a profile switcher or theme picker anywhere in its
header/hero/result/history/status/footer layout, because the plan of record expects Packet
11 to have already given them a Settings-window home by the time this popover is what users
see.

I also checked whether there's a fallback path back to the classic popover if Stage B
flipped the default: there isn't. `useExperimentalStateFirstUI`'s `UIModeToggleButton` only
toggles the *older* state-first experimental UI, not `useSlimPopover`. No UI anywhere
exposes `useSlimPopover` as a user-facing switch (by design — it's meant to be an internal
flag that gets a one-way default flip in Stage B, not a persistent toggle).

**Net effect of flipping now:** profile switching and theme selection would become
completely unreachable in the running app — not "later, once Packet 11 runs," but from the
moment Stage B lands until Packet 11 actually completes. Since this is Andrew's real,
currently-running menu-bar utility (not just a test target), I'm treating this the same way
Packet 08's mandatory inventory treated its seven orphans: **do the safe part, withhold the
step that would strand a real control, document why, keep moving.**

**Plan:** continue to Packet 10 (independent of this), then Packet 11 (which gives Profile/
Theme/Ticker their Settings-window home). Once Packet 11 lands, I'll re-run the Quick
Settings inventory; if it's clean, I'll complete Packet 09 Stage B at that point (flip
`useSlimPopover`'s default to `true`) as a follow-up commit, before Packet 12A/15.

## Screenshot / manual validation gaps (same root cause as every prior packet)

Not captured: idle popover, recording state, post-dictation with badge, error banner,
overflow menu open — for either the classic or new popover. Same LSUIElement/accessibility
blocker documented since Packet 01.

Not manually validated (require live UI interaction and/or real audio):
- Full dictation loop from the new Start/Stop button and the hardware trigger (hold + toggle)
- Retry / Learn Correction appearing under the same conditions and functioning
- History teaser showing 3 most recent + Open History working
- No text over watermark; watermark rotates in idle hero
- Error banner appearing when Accessibility permission is revoked
- Overflow: Transcribe File, Safe Mode toggle, Quit
- Dexter checks: ticker, watermark rotation, launch animation — **profile switch check is
  the one this NEEDS_ANDREW is about**: it cannot be meaningfully performed against the new
  popover yet, since there's no profile-switching UI in it until Packet 11 lands.

What WAS verified for real: `swift build` clean; `swift test` 382/382 passed (matches
baseline); targeted `swift test --filter OutputPipelineHardening` 17/17 passed; `./build.sh`
succeeded; app launched and stayed running (checked twice) with `useSlimPopover` still
`false` (Stage A's required state); full `git diff` reviewed — only the 4 new popover files,
`DexDictateApp.swift` (minimal 3-way branch), and `AppSettings.swift` (one new
`useSlimPopover` key) changed; `FlavorTickerView.swift` and `WatermarkAssetProvider.swift`
completely untouched (zero-line diffs, confirmed); no forbidden files; no existing storage
key changed.
