# Settings / Help Typography Unification

## Goal

Make Settings pages feel like the same product as the Help/Guide window — softer
hierarchy, primary text more opaque, secondary text less opaque — without redesigning
navigation, layout, or control behavior, and without touching the Dexter watermark.

## Existing Help typography behavior (source of truth)

`HelpView.swift`'s established, consistent pattern:

| Role | Font | Color |
|---|---|---|
| Section header (e.g. "Welcome") | `.title2.bold()` | `.white` (full opacity) |
| Sub-heading (`helpHeading`) | `.callout.weight(.semibold)` | `.white` (full opacity) |
| Body copy (`helpBody`) | `.callout` | `.white.opacity(0.88)` |
| Callout/tip box text | `.caption` | `.white.opacity(0.75)` |

Settings pages, by contrast, mostly used `.title2.bold()`/`.headline` with **no explicit
foreground** (defaults to `.primary` — visually equivalent under the forced
`.preferredColorScheme(.dark)`, but not deliberately pinned like Help), and used
`.caption`/`.caption2` + SwiftUI's semantic `.secondary` for descriptions — a flatter,
grayer tone than Help's deliberately-tuned opacity scale.

## Shared components added

New file: `Sources/DexDictate/SettingsWindow/DexSettingsTypography.swift`

Four small `View` wrappers, matching Help's exact scale above, so future pages inherit
the hierarchy automatically instead of every page re-deriving its own `.font`/
`.foregroundStyle` pair:

- `DexPageTitle(_:)` — `.title2.bold()`, `.white`. Matches Help's section header.
- `DexSectionTitle(_:)` — `.callout.weight(.semibold)`, `.white`. Matches `helpHeading`.
- `DexSectionDescription(_:)` — `.callout`, `.white.opacity(0.88)`. Matches `helpBody`,
  for substantial explanatory paragraphs.
- `DexSecondaryText(_:)` — `.caption2`, `.white.opacity(0.5)`. For short inline captions
  under a control (lower in the hierarchy than a full description).

Deliberately **not** created as raw `SurfaceTokens` font/color constants: the user's
task explicitly allowed either "shared typography tokens **or components**," and small
`View` wrappers let call sites read as `DexPageTitle(SettingsPage.general.title)` rather
than repeating `.font(...).foregroundStyle(...)` pairs at every call site — the stated
goal of "prefer shared modifiers/tokens over manually changing every `Text`."

## Settings pages affected

Applied to three pages this pass, chosen as the explicitly-named page (General) plus two
other high-traffic root pages, per the task's own scope guidance ("apply consistently...
especially the General page and other major root pages" — not an exhaustive 11-page
rewrite in one pass):

- **General** (`GeneralSettingsPage.swift`) — page title, "Interface" section header.
- **Dictation** (`DictationSettingsPage.swift`) — page title, "During Dictation" section
  header, the two short inline captions under Trigger Mode / Silence Timeout.
- **Output & Insertion** (`OutputSettingsPage.swift`) — page title, "Where text goes" /
  "Safety" / "Per-App Rules" section headers, the clipboard-restore explanation
  (`DexSectionDescription`), and the Per-App Rules caption (`DexSecondaryText`).

Control labels themselves (e.g. "Status Color", "Start Sound", toggle titles) were left
untouched — they're control labels, not description/hierarchy text, and the task asked
not to make controls look disabled or rewrite copy beyond what consistency requires.
`SettingToggleWithInfo`'s own internal styling was also left untouched (shared by many
toggles across every page; restyling it was out of scope for this focused pass and would
have expanded the diff far beyond the three named pages).

The remaining 8 Settings pages (Audio & Microphone, Vocabulary & Commands, Models &
Accuracy, Smart Cleanup, History, Dexter & Personality, Diagnostics & Recovery, Advanced)
were not touched this pass. `DexSettingsTypography.swift`'s four components are available
for them to adopt incrementally without any further architectural work.

## Accessibility / readability considerations

- No opacity drops below 0.5 (`DexSecondaryText`, the lowest tier) — matches Help's own
  floor and stays well above WCAG-adjacent minimums for secondary UI text on a dark
  background.
- No control (`Toggle`, `Picker`, `Button`) had its own styling touched — nothing was
  made to look disabled.
- `DexSectionDescription`/`DexSecondaryText` both keep `.fixedSize(horizontal: false,
  vertical: true)` (or rely on it via the wrapper) so multi-line explanatory text still
  wraps correctly at narrow Settings-window widths.

## Dexter watermark preservation

Not touched. `DexterIdentityWatermark` (behind every Settings/Help page via
`SettingsRootView`/`HelpView`'s shared `ZStack`) has its own fixed 0.06 opacity,
independent of this text-hierarchy pass. Confirmed by inspection: none of the three
edited files touch `SettingsRootView.swift` or the watermark rendering path at all.

## Validation status

- `swift build` — success.
- `swift test` — 432/432 passing (no test asserts on font/color values for these pages).
- `./build.sh` — success; installed to `/Applications/DexDictate.app`.
- Manual visual comparison of Settings vs. Help **not performed** — this environment has
  no Accessibility permission for AppleScript UI scripting, so the app's windows can't be
  driven or screenshotted here. See "Andrew validation steps" in the final response.
