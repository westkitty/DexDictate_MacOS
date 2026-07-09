# Packet 12B — Manual Validation Gaps + Judgment Calls

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation of: the popover post-retirement (confirming it looks/behaves
identically to before, minus the now-removed "New UI"/"Classic" switch button), the ⌘K
palette still working, the Nano HUD's "All Features" hub panel opening correctly from a
running HUD, Settings → Advanced showing only the Nano HUD toggle.

## Judgment call: `DexExperimentalHubViews.swift` was split, not moved wholesale

The handoff's Packet 12B step 2 names `DexExperimentalHubViews.swift` in its list of files
to remove entirely. Doing so would have broken `Sources/DexDictate/FloatingHUD.swift`'s
`showHubPanel()` method, which directly instantiates `DexExperimentalFeatureHubView` (the
Nano HUD's only way to reach Settings/History/Help/Quit without being a dead end — a real,
pre-existing production dependency, not something introduced by Packets 12A/12A-B). Rather
than stop the whole packet over this, I applied the same "keep + move out, note the move"
treatment the handoff itself pre-authorizes for `DexCommandPaletteView.swift`/
`DexNanoHUDView.swift`: split the file, kept `DexExperimentalFeatureHubView` (moved to
`Sources/DexDictate/DexExperimentalHubViews.swift`), deleted `DexExperimentalGUISwitcherView`
(the actual "Switch UI" surface, whose removal the handoff explicitly does name). Flagging
this extrapolation explicitly since it required judgment beyond the literal file list.

## Three Advanced-page toggle rows removed (state-first, command palette, Dexter feed)

Only "Nano HUD" remains in Settings → Advanced → Experimental UI. The other three flags
(`useExperimentalStateFirstUI`, `useExperimentalCommandPalette`, `useExperimentalDexterFeed`)
had their sole readers deleted along with the state-first surface — leaving their toggle
rows in place would have presented switches that silently do nothing. The underlying
storage keys are untouched (still defined in `AppSettings.swift`); only the now-inert
Settings UI rows are gone. If you'd rather these three toggles stayed visible (e.g. for
users who already have them set), that's a one-line revert of the `AdvancedPage.swift`
diff — flagging for your awareness rather than assuming either way.

## No new findings beyond the above

No new orphaned controls, no new forbidden-file strings, no storage-key changes.
