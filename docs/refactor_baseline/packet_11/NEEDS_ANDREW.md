# Packet 11 — API-Availability Findings + Screenshot Gaps

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation (profile matrix ×3, theme matrix ×4, shuffle ×5).

## API-availability findings (required by this packet's report template)

1. **No "watermark backdrop toggle" setting exists.** Checked `AppSettings.swift` for
   anything like `showWatermark`/`watermarkEnabled` — nothing. Per this packet's own stop
   condition ("do not invent new stored settings without reporting first"), I did not add
   one. I implemented only the **Shuffle Now** button, which does have a real backing API
   (`ProfileManager.refreshDynamicContent()`). The watermark currently always renders
   whenever a profile has assets and the popover is idle — there's no way to turn it off,
   and I haven't added one.
2. **No "regional icon" asset exists separately from watermark images.** The goal text says
   profile cards should show "existing regional icons," but there's no such asset category —
   `AppProfile` has no icon property, and `WatermarkAssetProvider` only exposes the full
   randomized watermark pools. I used the **first watermark asset per profile**
   (`profileManager.watermarkAssets(for:).first`) as a representative thumbnail on each
   profile card instead — a display-only choice, not a new stored setting or asset.
3. **No ticker "speed" setting exists.** `FlavorTickerView`'s scroll speed
   (`pointsPerSecond = 20`) is a hardcoded constant inside the forbidden file, not an
   exposed parameter. Only on/off (`showFlavorTicker`) and animate (`animateFlavorTicker`)
   exist and were migrated — no speed control was invented.

## Theme seam — fixed in both popovers

Found the exact cause: the header title text and its three `ChromeIconButton`s were
hardcoded white, while the surrounding background already correctly followed
`settings.themeBackgroundColor` (white under Minimalist) — so under Minimalist the header
was white-on-white, effectively invisible. The giant rotated "DEXDICTATE" watermark text a
few lines below the header already had the correct conditional
(`.minimalist ? black : white`) — I applied the same pattern to the header title and added
an optional `tint` parameter to `ChromeIconButton` (declared before the trailing-closure
`action` parameter so no existing call site breaks) so the header icons follow it too.
Every other `ChromeIconButton` call site (History window, Help window, etc.) is
unaffected — those windows don't participate in `settings.appearanceTheme` at all, so the
default `tint: .white` preserves their exact current appearance.

Also found: `PopoverRootView.swift` (the new Packet 09 popover) had **no theme background
handling at all** — it always showed the default system material regardless of theme
selection. Since this packet's acceptance criteria requires "all four themes apply without
the header/body seam" and this view is about to become the default popover (Stage B, see
below), I added the same background-selection logic the classic popover uses, plus the
same header fix. Not scope creep — without it, "no seam" would only be true for the
popover that's about to stop being used.

## Packet 09 Stage B — now safe to complete

Packet 09's Stage B was withheld because Profile picker, Return to Standard, both ticker
toggles, and the Theme picker were still only reachable through the classic popover's Quick
Settings stack, and the new popover has no UI for any of them. This packet gives all five a
home in Settings → Dexter & Personality. A fresh inventory
(`grep "showLegacy.*= false"` across `QuickSettingsView.swift`) shows every hide-flag is
now `false` — meaning every control that packet 08/08B/11 were responsible for has a
Settings-window home. The four still-orphaned benchmark controls flagged in Packet 10 (Run
Benchmarks Now, Restore Stable Defaults, Open Captured Corpus, `BenchmarkResultsSection`)
remain hidden — but they've been hidden since Packet 07 regardless of which popover is
default, so completing Stage B doesn't change their reachability at all. I'll complete
Packet 09 Stage B as a follow-up immediately after this packet's report.

## What WAS verified for real

- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: `swift test --filter ProfileContent` — 6/6 passed
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- Full `git diff` reviewed: 7 files touched (`ChromeButton.swift`, `DexDictateApp.swift`,
  `PopoverRootView.swift`, `QuickSettingsView.swift`, `DexterPersonalityPage.swift`,
  `SettingsRootView.swift`, `SettingsWindowController.swift`). No forbidden files
  (`ProfileManager.swift`, `WatermarkAssetProvider.swift`, `FlavorTickerView.swift`,
  `FlavorQuotePacks.swift` — all read-only, zero edits). No `@AppStorage` key
  added/removed/renamed.
