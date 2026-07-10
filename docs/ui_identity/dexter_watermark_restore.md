# Dexter Identity Watermark Restore

Restores the subtle Dexter image watermark behind **all** Settings pages and **all**
Guide/Help pages so the app reads as *DexDictate*, not a generic settings utility.

## Root cause

The menu-bar popover (`AntiGravityMainView` in `Sources/DexDictate/DexDictateApp.swift`) has
always carried a low-opacity Dexter image behind its content (`cachedWatermarkImage`, rendered
at `opacity(0.12)` with `.allowsHitTesting(false)`).

The Settings window was built fresh as an empty shell (packet 02, commit `64bb643c`) and had
its controls migrated in one domain at a time (packets 03–15). That migration moved the
*controls* out of the popover but never carried over the popover's Dexter watermark
background. Each Settings page is a plain `ScrollView { VStack { … } }` with no identity
layer, so the window looked like a stock macOS settings pane.

The Help/Guide window (`HelpView.swift`) only ever had per-section **SF-symbol** watermarks
(`SectionWatermark`, e.g. `hand.wave`) — never the Dexter identity image.

There was no prior removed Dexter-image implementation for these two windows to recover from
git history; the identity image simply never existed there. This change re-establishes it,
mirroring the popover's existing pattern rather than inventing a new one.

## Dexter assets used

- **Fallback (always available):** `DexDictate_app_settings.png` — a flat Dexter illustration
  in the DexDictateKit resource bundle
  (`Sources/DexDictateKit/Resources/ProfileAssets/RandomCycle/DexDictate_app_settings.png`).
  It is part of the Standard random-cycle pool already used by `WatermarkAssetProvider`, so it
  is guaranteed bundled and resolvable via
  `Safety.resourceBundle.url(forResource:"DexDictate_app_settings", withExtension:"png")`.
  Verified present in the built app at
  `/Applications/DexDictate.app/…/DexDictate_MacOS_DexDictateKit.bundle/DexDictate_app_settings.png`.
- **Settings window (profile-aware):** when available, the shared view is fed
  `profileManager.currentWatermarkAsset?.url` — the same profile-driven Dexter image the
  popover uses — so the Settings watermark matches the popover and respects the active
  regional profile (Standard / Canadian / Aussie). Falls back to the stable asset above.

No Dexter assets were removed, renamed, flattened, or genericized. No images deleted.

## Files changed

| File | Change |
|------|--------|
| `Sources/DexDictate/DexterIdentityWatermark.swift` | **New.** Shared, reusable `DexterIdentityWatermark` SwiftUI view. Loads a Dexter `NSImage` (injected profile URL → stable bundled fallback), caches it, renders at low opacity, `.allowsHitTesting(false)` + `.accessibilityHidden(true)`. |
| `Sources/DexDictate/SettingsWindow/SettingsRootView.swift` | Wrapped the `detail:` content in a `ZStack` with `DexterIdentityWatermark(assetURL: profileManager.currentWatermarkAsset?.url)` behind `detailView`. One insertion point covers all 11 pages. |
| `Sources/DexDictate/HelpView.swift` | Added `DexterIdentityWatermark()` into the detail pane's `.background` `ZStack` (behind the existing gradient's content, behind page content). One insertion point covers all Guide sections. |

The engine, transcription, insertion/output, hotkey/mouse trigger, Smart Cleanup, Live
Preview, storage keys, and all existing Settings/Guide controls were untouched.

## Settings coverage (all 11 pages)

The watermark is applied once at `SettingsRootView`'s `detail:` closure, which hosts every
page via the `SettingsPage` switch — so it appears behind:

General · Dictation · Audio & Microphone · Output & Insertion · Vocabulary & Commands ·
Models & Accuracy · Smart Cleanup · History · Dexter & Personality · Diagnostics & Recovery ·
Advanced.

## Guide coverage (all sections)

Applied once at `HelpView`'s `detail:` pane, which hosts every `HelpSection` via
`HelpContentView`'s switch — so it appears behind all Guide pages:

Welcome · Getting Started · Permissions · Trigger Setup · Recording & Audio · Transcription ·
Output & Pasting · Transcription History · Custom Vocabulary · Voice Commands · Profiles ·
Appearance & Menu Bar · Floating HUD · Safe Mode · Benchmarking & Models · Shortcuts & Siri ·
Diagnostics · Experimental UI · About.

(The existing per-section `SectionWatermark` SF-symbols are preserved and now layer over the
Dexter identity image.)

## Interaction safety

- `DexterIdentityWatermark` sets **`.allowsHitTesting(false)`** — it can never intercept
  clicks, toggles, buttons, sidebar navigation, scrolling, sheets, popovers, or keyboard
  focus.
- It is always placed **behind** content: the bottom element of the Settings `ZStack`, and
  inside the Help detail's `.background` layer. It is never a high-`zIndex` overlay and never
  covers content.
- It is `.accessibilityHidden(true)` so it adds no VoiceOver noise.
- Opacity defaults to **0.06** (vs the popover's 0.12) because Settings/Guide panes are
  text-dense; contrast/readability of labels and forms is preserved.
- Layout is unaffected: the view expands to fill via `maxWidth/maxHeight: .infinity` as a
  background and does not push content.

## Validation results

- `swift build` — **success**.
- `swift test` — **417 tests, 0 failures.** (One accessibility/timing test flaked on the
  first run and passed on re-run; unrelated to this change.)
- `./build.sh` — **success**; release built, codesigned, installed to
  `/Applications/DexDictate.app`. `VerificationRunner` built; its watermark checks concern the
  popover/HUD (unchanged) and still hold.
- Launched `/Applications/DexDictate.app` — process runs cleanly (menu-bar accessory).
- Fallback asset confirmed present in the built bundle.

Pixel-level GUI screenshots were not captured: DexDictate is an `LSUIElement` menu-bar
accessory app that the computer-use access dialog cannot resolve for screenshot filtering.
Per the task, screenshots are non-blocking. Interaction safety is guaranteed structurally by
`.allowsHitTesting(false)` and by placing the layer behind content.
