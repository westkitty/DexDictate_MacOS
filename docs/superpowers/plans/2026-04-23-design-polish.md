# Design Polish Round 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply five targeted UI/UX improvements to the DexDictate main popover identified in a design critique pass.

**Architecture:** All changes are confined to the SwiftUI view layer. No engine, permission, audio, or settings-persistence code is touched. Each task is independently buildable. Build verification: `cd ~/Projects/DexDictate_MacOS && ./build.sh`.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (macOS 14+). No new dependencies.

---

## File Map

| File | What changes |
|------|-------------|
| `Sources/DexDictate/ControlsView.swift` | Remove `quitButton` var, `isQuitHovered` state, `quitApp()` method, and the always-visible Quit call site |
| `Sources/DexDictate/FooterView.swift` | Add a slim Quit button above "Restore Defaults" |
| `Sources/DexDictate/DexDictateApp.swift` | Lower watermark opacity 0.12→0.06, clip watermark to top half, reorder VStack (tickers move below ControlsView) |
| `Sources/DexDictate/ChromeButton.swift` | Frame 28×28 → 32×32, corner radius 7 → 8 |
| `Sources/DexDictate/HistoryView.swift` | Raise 0.5 opacity text to 0.58 |
| `Sources/DexDictate/QuickSettingsView.swift` | Raise 0.5 opacity text to 0.58 (label-only instances) |

---

## Task 1 — Move "Quit App" from ControlsView to FooterView

**Files:**
- Modify: `Sources/DexDictate/ControlsView.swift`
- Modify: `Sources/DexDictate/FooterView.swift`

- [ ] **Step 1: Remove quit infrastructure from ControlsView**

In `ControlsView.swift`, remove the `isQuitHovered` state, the `quitButton` computed property, and the `quitApp()` method, and the `// ── Always visible: Quit` call site in `body`.

The `body` VStack ends at `stopDictationButton` (in the `else` branch) — remove the line `quitButton` that appears after the `if/else` block:

```swift
// DELETE this block from the @State properties section:
@State private var isQuitHovered = false

// DELETE this entire computed property:
private var quitButton: some View { ... }

// DELETE this method:
private func quitApp() {
    NSApplication.shared.terminate(nil)
}

// In body, change the end of VStack from:
            // ── Always visible: Quit ──────────────────────────────────────────
            quitButton
        }
// To just:
        }
```

- [ ] **Step 2: Add a slim Quit button to FooterView**

`FooterView.body` is a `VStack(spacing: 6)`. Insert the Quit button at the **top** of that VStack, visually separated from the rest by a `Divider`-equivalent opacity rule:

```swift
var body: some View {
    VStack(spacing: 6) {
        // Quit lives here — separated from the action zone above by position in the footer
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Text(NSLocalizedString("Quit App", comment: ""))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quit DexDictate")

        Button(action: { settings.restoreDefaults() }) { ... }
        Button(action: { /* About link */ }) { ... }
        Button(action: registerVersionTapForOnboarding) { ... }
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd ~/Projects/DexDictate_MacOS && ./build.sh 2>&1 | tail -5
```
Expected last line: `Installed to /Applications/DexDictate.app`

- [ ] **Step 4: Commit**

```bash
git add Sources/DexDictate/ControlsView.swift Sources/DexDictate/FooterView.swift
git commit -m "fix: move Quit App from controls to footer to prevent accidental quit"
```

---

## Task 2 — Reduce Watermark Opacity and Restrict to Top Half

**Files:**
- Modify: `Sources/DexDictate/DexDictateApp.swift` (inside `AntiGravityMainView.body`)

The watermark is two layers inside the root `ZStack`: the app icon `Image` and the rotated `Text("DEXDICTATE")`. Both are currently at `opacity(0.12)`.

- [ ] **Step 1: Lower opacity and add vertical clipping on both watermark layers**

Find the two watermark layers (around lines 391–416 in `DexDictateApp.swift`). The watermark images should get opacity 0.06. The "DEXDICTATE" text should also drop to 0.06. Both should be aligned to the top of the ZStack so they fade out of the controls zone.

For the conditional asset image block (both branches have the same structure):
```swift
// BEFORE:
Image(nsImage: nsImage)
    .resizable()
    .scaledToFit()
    .frame(width: 200, height: 200)
    .opacity(0.12)
    .allowsHitTesting(false)

// AFTER:
Image(nsImage: nsImage)
    .resizable()
    .scaledToFit()
    .frame(width: 200, height: 200)
    .opacity(0.06)
    .frame(maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(false)
```

For the rotated "DEXDICTATE" text:
```swift
// BEFORE:
Text("DEXDICTATE")
    ...
    .foregroundStyle(
        settings.appearanceTheme == .minimalist
        ? Color.black.opacity(0.12)
        : Color.white.opacity(0.12)
    )
    .rotationEffect(.degrees(-18))
    .allowsHitTesting(false)

// AFTER:
Text("DEXDICTATE")
    ...
    .foregroundStyle(
        settings.appearanceTheme == .minimalist
        ? Color.black.opacity(0.06)
        : Color.white.opacity(0.06)
    )
    .rotationEffect(.degrees(-18))
    .frame(maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(false)
```

- [ ] **Step 2: Build and verify**

```bash
cd ~/Projects/DexDictate_MacOS && ./build.sh 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DexDictate/DexDictateApp.swift
git commit -m "fix: lower watermark opacity 12→6% and pin to top half of popover"
```

---

## Task 3 — Reorder Main Popover: Tickers Move Below Controls

**Files:**
- Modify: `Sources/DexDictate/DexDictateApp.swift` (inside `AntiGravityMainView.body`, the `ScrollView > VStack`)

Current order:
1. Title ZStack
2. FlavorTickerView (if showFlavorTicker)
3. StatsTickerView (if showDictationStats)
4. PermissionBannerView
5. HistoryView
6. ControlsView
7. QuickSettingsView
8. QuickSettingsStatusStrip
9. Spacer
10. FooterView

Target order (tickers move to position 7 & 8, after Controls):
1. Title ZStack
2. PermissionBannerView
3. HistoryView
4. ControlsView
5. FlavorTickerView (if showFlavorTicker)
6. StatsTickerView (if showDictationStats)
7. QuickSettingsView
8. QuickSettingsStatusStrip
9. Spacer
10. FooterView

- [ ] **Step 1: Cut the two ticker `if` blocks and paste them after ControlsView**

In `AntiGravityMainView.body` the `VStack(spacing: 15)` currently reads:

```swift
VStack(spacing: 15) {
    // title ZStack ...

    if settings.showFlavorTicker {
        FlavorTickerView(...)
    }

    if settings.showDictationStats {
        StatsTickerView(...)
    }

    PermissionBannerView(...)
    HistoryView(...)
    ControlsView(...)
    QuickSettingsView(...)
    ...
}
```

Move the two ticker blocks to appear **after** `ControlsView(...)`:

```swift
VStack(spacing: 15) {
    // title ZStack ...

    PermissionBannerView(permissionManager: permissionManager)

    HistoryView(
        history: engine.history,
        statusText: engine.statusText,
        liveTranscript: engine.liveTranscript,
        inputLevel: engine.inputLevel,
        isListening: engine.state == .listening || engine.state == .transcribing,
        expanded: $expandedHistory,
        onDetach: onDetachHistory,
        silenceCountdown: engine.silenceCountdown
    )

    ControlsView(
        engine: engine,
        adaptiveBenchmarkController: adaptiveBenchmarkController
    )

    if settings.showFlavorTicker {
        FlavorTickerView(
            text: profileManager.currentFlavorLine?.text ?? "",
            animateWhenNeeded: settings.animateFlavorTicker
        )
    }

    if settings.showDictationStats {
        StatsTickerView(
            history: engine.history,
            animateWhenNeeded: settings.animateFlavorTicker
        )
    }

    QuickSettingsView(...)
    ...
}
```

- [ ] **Step 2: Build and verify**

```bash
cd ~/Projects/DexDictate_MacOS && ./build.sh 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DexDictate/DexDictateApp.swift
git commit -m "fix: move flavor/stats tickers below controls in main popover"
```

---

## Task 4 — Raise Secondary Text Opacity 50% → 58%

**Files:**
- Modify: `Sources/DexDictate/HistoryView.swift`
- Modify: `Sources/DexDictate/QuickSettingsView.swift`
- Modify: `Sources/DexDictate/ControlsView.swift`
- Modify: `Sources/DexDictate/FooterView.swift`
- Modify: `Sources/DexDictate/DexDictateApp.swift`

Target: every `.white.opacity(0.5)` that applies to label/helper text becomes `.white.opacity(0.58)`. The version string in FooterView at `.white.opacity(0.3)` also raises to `.white.opacity(0.38)` (same +8 delta). Do NOT change opacity values that are used on backgrounds, borders, or icons — only text foreground.

- [ ] **Step 1: Update HistoryView.swift**

Instances in `HistoryView`:
- `statusText` placeholder (`.white.opacity(0.5)`)
- timestamp text (`.white.opacity(0.45)`) → `.white.opacity(0.52)`  
- live transcript label (`.white.opacity(0.7)`) — leave, already above threshold

```swift
// placeholder text (line ~103):
// BEFORE: .foregroundStyle(.white.opacity(0.5))
// AFTER:  .foregroundStyle(.white.opacity(0.58))

// timestamp (line ~116):
// BEFORE: .foregroundStyle(.white.opacity(0.45))
// AFTER:  .foregroundStyle(.white.opacity(0.52))
```

- [ ] **Step 2: Update ControlsView.swift**

```swift
// "TRIGGER" label (line ~141):
// BEFORE: .foregroundStyle(.white.opacity(0.55))
// AFTER:  .foregroundStyle(.white.opacity(0.62))
```

- [ ] **Step 3: Update FooterView.swift**

```swift
// "Restore Defaults" text:
// BEFORE: .foregroundStyle(.white.opacity(0.5))
// AFTER:  .foregroundStyle(.white.opacity(0.58))

// "Quit App" text (just added):
// Already at 0.45 — leave as is (it's intentionally dimmer to de-emphasize)

// Version string:
// BEFORE: .foregroundStyle(.white.opacity(0.3))
// AFTER:  .foregroundStyle(.white.opacity(0.38))
```

- [ ] **Step 4: Update QuickSettingsView.swift**

`QuickSettingsView` has many `.white.opacity(0.5)` on section labels and helper text. Use replace_all for the label pattern, being careful not to touch background opacity values.

Target only lines where 0.5 is applied as `.foregroundStyle(` text color. Key instances:
- `Text("Trigger Mode")` label
- `Text("Input")`, `Text("Model")` compact card labels
- `Text("Pinned Controls")` — `.white.opacity(0.72)` — leave (above threshold)
- All `.foregroundStyle(.white.opacity(0.5))` on `Text(...)` nodes → change to `0.58`

- [ ] **Step 5: Build and verify**

```bash
cd ~/Projects/DexDictate_MacOS && ./build.sh 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DexDictate/HistoryView.swift Sources/DexDictate/QuickSettingsView.swift Sources/DexDictate/ControlsView.swift Sources/DexDictate/FooterView.swift Sources/DexDictate/DexDictateApp.swift
git commit -m "fix: raise secondary text opacity 50→58% for WCAG AA compliance"
```

---

## Task 5 — Grow ChromeIconButton Tap Targets 28×28 → 32×32

**Files:**
- Modify: `Sources/DexDictate/ChromeButton.swift`

- [ ] **Step 1: Update frame and corner radius**

```swift
// BEFORE:
.frame(width: 28, height: 28)
...
RoundedRectangle(cornerRadius: 7)
    .stroke(...)
...
.clipShape(RoundedRectangle(cornerRadius: 7))

// AFTER:
.frame(width: 32, height: 32)
...
RoundedRectangle(cornerRadius: 8)
    .stroke(...)
...
.clipShape(RoundedRectangle(cornerRadius: 8))
```

- [ ] **Step 2: Build and verify**

```bash
cd ~/Projects/DexDictate_MacOS && ./build.sh 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DexDictate/ChromeButton.swift
git commit -m "fix: grow ChromeIconButton tap targets 28→32pt per Apple HIG"
```

---

## Task 6 — Push and Write Ledger Entry

- [ ] **Step 1: Push all commits**

```bash
git push
```

- [ ] **Step 2: Write Ledger Entry B-0053 in docs/DEXDICTATE_BIBLE.md**

Append `### 19.04 Ledger Entry B-0053` with: all files changed, what succeeded, build result, regressions checked.
