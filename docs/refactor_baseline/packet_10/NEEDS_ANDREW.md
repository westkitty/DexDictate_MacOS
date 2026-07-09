# Packet 10 — Findings, Forbidden-File String, and Scope Boundaries

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation. See below for what that leaves undone.

## Grep hit list (required by this packet's Step 1)

```
grep -rn --include="*.swift" "Accuracy Retry\|Retry Last in Accuracy\|Correction Sheet\|Context Injection\|Smart Retry" Sources/
```
Full results (18 lines) covered: `QuickSettingsView.swift` (hidden legacy copies, 5 hits),
`HelpView.swift` (6 hits), `PopoverResultView.swift` (1), `ModelsAccuracyPage.swift` (3),
`ControlsView.swift` (1), `OutputSettingsPage.swift` (2). All renamed except the forbidden-
file case below and code comments (see "Internal symbol names" section).

## Forbidden-file user-facing string (NOT edited, per this packet's own exception)

`Sources/DexDictateKit/TranscriptionEngine.swift:1262`:
```swift
liveTranscript = NSLocalizedString("Retrying in accuracy mode...", comment: "Retry progress")
```
This is a real user-facing string (shown as the live transcript placeholder during a
Quality Retry pass) but lives inside a forbidden file. Per the packet's explicit exception
("if a user-facing string literal lives inside a forbidden file, report it in the final
report instead of editing that file"), I did not touch it. It still reads "accuracy mode"
where the rest of the UI now says "Quality Retry" / "higher quality." Flagging for Andrew
or a future packet with permission to touch `TranscriptionEngine.swift`.

## New finding: four more orphaned benchmark controls (not part of the original 7)

While updating a stale Help path ("Quick Settings → Benchmark → Restore Stable Defaults"),
I found that Packet 07 hid the *entire* "Benchmarks & Corpus" `DisclosureGroup` from the
popover — correctly, per that packet's own rule — but only two of its controls got a new
home in Settings → Models & Accuracy (Import Model, and a relabeled "Open Benchmark Lab…"
button for what was "Open Benchmark Capture"). Four more never did:
- **"Run Benchmarks Now"** button (`adaptiveBenchmarkController.runBenchmarksNow()`)
- **"Restore Stable Defaults"** button (`settings.restoreStableDictationDefaults()`)
- **"Open Captured Corpus"** button (only shown when a capture session exists)
- **`BenchmarkResultsSection`** (historical benchmark results / promotion display)

I checked whether the Benchmark Lab window itself (opened by the button I built in Packet
07) already exposes equivalents — it does not (`grep` for these terms in
`BenchmarkCaptureWindow.swift` returns nothing).

Unlike the original 7 orphans (Pause Browser Media, Show Floating HUD, Context Biasing,
Transcription Engines, Show Dictation Stats, Persist History, empty History page), these
four are power-user benchmark tooling, not everyday dictation features, and Packet 07's own
popover-cleanup text ("no benchmark status, session IDs, queue display, or run buttons
remain in popover") reads like an intentional simplification rather than an oversight —
the popover text even says "benchmark it with the existing scripts," implying a
command-line path is the expected route for serious benchmark work. Still, "Restore Stable
Defaults" in particular is a real recovery action a regular user might want. I did not
invent new UI for these myself (that's a scope/placement decision, not a string rename), and
updated the one Help entry that referenced them to say they're "not currently reachable"
rather than pointing at a real location. **Flagging for the same kind of decision Andrew
made for the original 7** — whether these need Settings-window homes too, or whether
leaving them command-line/script-only is the intended design.

## Scope boundary: NOT a full Help-text location audit

`HelpView.swift` still has 34 other "Quick Settings →" path references beyond the ones tied
to the 5 renamed terms (which I did fix, including a few immediately-adjacent stale paths I
noticed while editing those same entries — Active Model, Input Device, Trigger Mode). Doing
a full pass over all 34 is a bigger, separate documentation-accuracy task, not "terminology
sweep for 5 named renames." Flagging it here rather than expanding this packet's scope
unilaterally.

## Internal symbol names not renamed (by design — packet forbids identifier renames)

`enableAccuracyRetry`, `enableContextInjection`, `isAccuracyRetry` (property/field names),
`AccuracyRetry`-adjacent internal identifiers, and a few code comments describing packet
history using the old terms (`QuickSettingsView.swift:55`, `ModelsAccuracyPage.swift:13`)
all remain as-is — renaming them would violate "no identifier/type/function renames."

## What WAS verified for real

- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: `swift test --filter SettingsMigration` — 2/2 passed (green, as required)
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- `git diff | grep -n "AppStorage\|UserDefaults"` — zero hits, confirming no storage key
  changed anywhere in this sweep
- Full `git diff` reviewed: 8 files touched, all display-string-only changes (titles, info
  text, Help copy, one history-tag label). No forbidden files touched.

Manual validations not performed (require live UI interaction): visual read-through of every
Settings page and popover confirming renamed strings render correctly; Help window
read-through confirming updated paths match reality.
