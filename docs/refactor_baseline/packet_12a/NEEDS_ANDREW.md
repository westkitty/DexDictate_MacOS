# Packet 12A — Screenshot Gaps + MISSING Inventory Items

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation (⌘K palette open/execute, experimental UI on→off→on round-trip,
full dictation loop in both UIs).

## MISSING inventory rows (block Packet 12B — gated anyway, no action needed now)

See `docs/experimental_adoption_inventory.md` for full detail. Three MISSING rows:
1. Pinned "daily six" compact controls (trigger/model/mode/output chips) — new default
   popover only has full Settings pages, not one-tap compact pills.
2. **Live transcript + mic level meter while actively listening** — found during this
   inventory, not one of the three suggested adoptions. The new default popover
   (`PopoverRootView`, Packet 09) shows engine state and the *last completed* result, but
   nothing live while recording. This is a real usability gap in the popover that's now
   default — flagging prominently rather than silently expanding this packet's scope to fix
   it. Worth a dedicated pass (Packet 15, or its own packet).
3. Dexter Feed (stateful quote browser) — no standard-UI home at all; not attempted since it
   wasn't one of the three suggested safe adoptions and doesn't map cleanly onto any
   existing page structure.

None of these block anything in the *approved* sequence — Packet 12B requires Andrew's
separate explicit approval regardless, and I am not running it.

## Adoptions made this packet

- **Command Palette (⌘K)**: `DexCommandPaletteView` re-hosted unchanged into
  `PopoverRootView` as a screen-swap (matches the experimental popover's own technique to
  avoid sheet-triggered Dock bounce). Reachable via ⌘K or the footer overflow menu's new
  "Command Palette" item.
- **Inline Dexter result quote**: real toggle now in Settings → Dexter & Personality
  (replacing Packet 11's placeholder), new storage key `showInlineResultQuote` (default
  `false`), wired into `PopoverResultView` via `DexterCommentaryLine` when enabled.
- **Nano HUD**: confirmed already fully adopted in production `FloatingHUD.swift` — no new
  work needed, documented as "existing" in the inventory.

## What WAS verified for real

- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- Full `git diff` reviewed: 4 files touched (`PopoverResultView.swift`,
  `PopoverRootView.swift`, `DexterPersonalityPage.swift`, `AppSettings.swift`). Zero files
  in `Sources/DexDictate/ExperimentalUI/` touched — confirmed via `git diff --name-only`.
  No forbidden files. Exactly one new `@AppStorage` key added
  (`showInlineResultQuote` — does not repurpose any existing key).
