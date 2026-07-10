# BUG-005 — Settings Sidebar Selection Does Not Change Detail Page

## Confirmed symptom

Clicking a different page in the Settings sidebar (e.g. "Audio & Microphone",
"Advanced") visibly changes the sidebar's row highlight, but the detail pane
on the right stays rendered on the General page. Andrew confirmed via video
that this is a *navigation* bug, not a clickability bug — controls on the
General page do respond to clicks; the sidebar's own selection highlighting
does update on click. The detail content simply never follows it.

## Root cause

`SettingsRootView`'s `selection` was a `@Binding` sourced from a bare
`Binding(get:set:)` pair constructed inside `SettingsWindowController.show()`:

```swift
// SettingsWindowController (before fix)
@Published var selection: SettingsPage = .general
...
SettingsRootView(
    selection: Binding(
        get: { [weak self] in self?.selection ?? .general },
        set: { [weak self] in self?.selection = $0 }
    ),
    ...
)
```

That custom `Binding` is a value-passing interface only — it is not itself a
tracked SwiftUI dependency. Nothing in `SettingsRootView`'s or
`SettingsSidebar`'s view hierarchy held `SettingsWindowController` via
`@ObservedObject`/`@StateObject`, so no view was actually subscribed to
`objectWillChange` on the object whose `@Published var selection` was the
real source of truth.

`SettingsSidebar`'s `List(selection: $selection)` is backed by a native
AppKit `NSTableView` under the hood. Row-highlight changes there are
intrinsic `NSTableView` behavior and happen immediately and independently of
whether SwiftUI decides anything needs to re-render. So clicking a row:

1. Correctly invoked the binding's `set` closure, which wrote the new value
   into `SettingsWindowController.selection`.
2. Correctly updated the row highlight (AppKit's own doing, not SwiftUI's).
3. **Never told SwiftUI to re-evaluate `SettingsRootView.body`**, because no
   view held a tracked dependency on the object that changed. `detailView`'s
   `switch selection` kept rendering whatever page was last actually
   re-rendered — `.general`, from the initial load.

## Why BUG-004 was not the full explanation

BUG-004's fix (`Sources/DexDictate/FloatingHUD.swift` — setting
`window?.ignoresMouseEvents` conditionally on the Floating HUD) addressed a
real, separate defect: an overlapping, click-eating HUD window sitting above
Settings at `.floating` level. That fix is being kept — it's a legitimate
bug and the standard HUD has no click-driven content to lose from it. But it
could never have explained *this* symptom: if all clicks were truly being
swallowed by an overlapping window, the sidebar's own row highlight would
never have changed either. The video evidence (highlight moves, content
doesn't) points specifically at a SwiftUI reactivity gap downstream of a
click that *did* land — a different failure class entirely from an
overlapping window eating the click before it ever reached Settings.

## Why this was missed by prior sweeps

The post-campaign bug sweep and BUG-004's investigation were both
code-reading and static-analysis-driven (plus, for BUG-004, read-only Quartz
window inspection) — neither exercised actual multi-page sidebar navigation
against a live-rendered detail pane. `swift build` and `swift test` cannot
catch this class of defect: the code compiles cleanly (a `Binding(get:set:)`
closure pair is a completely valid, non-error SwiftUI construction), and
there is no automated test target with access to `SettingsRootView`'s live
view hierarchy to catch a missing reactive dependency (see Testing section
below). This is a rendering/reactivity defect that is only observable by
actually driving the UI and watching what re-renders — which is exactly
what Andrew's video did and static tooling couldn't.

## Fix

Made `selection` `SettingsRootView`'s own `@State`, eliminating the
disconnected custom `Binding` entirely:

- **`Sources/DexDictate/SettingsWindow/SettingsRootView.swift`**: changed
  `@Binding var selection: SettingsPage` to
  `@State private var selection: SettingsPage = .general`, with a doc
  comment recording the root cause for future readers.
- **`Sources/DexDictate/SettingsWindow/SettingsWindowController.swift`**:
  removed `@Published var selection` and the custom `Binding(get:set:)`
  construction entirely; the `SettingsRootView(...)` call site no longer
  passes a `selection:` argument at all.

`SettingsSidebar` and `SettingsPage` were inspected and required no changes
— `SettingsSidebar` already correctly receives `$selection` from whatever
view constructs it; the defect was entirely in what `SettingsRootView` used
as its `selection` storage.

A plain local `@State` is a real, SwiftUI-tracked dependency: writes to it
from `SettingsSidebar`'s `List(selection:)` now correctly invalidate
`SettingsRootView.body`, so `detailView`'s switch re-evaluates against the
new value on every click.

"Last-viewed page persists across close/reopen" (the one behavior the old
`@Published` controller-level storage nominally provided) still holds under
the fix: `SettingsWindowController.window`/`hosting` — and therefore this
`SettingsRootView` instance's `@State` storage — are constructed exactly
once and reused via `makeKeyAndOrderFront` on every subsequent `show()`
call; the view is only hidden/shown, never torn down and recreated.

## Testing

No automated regression test was added. `SettingsRootView` and
`SettingsWindowController` both live in `Sources/DexDictate/` (the app
executable target). Per `Package.swift`, `Tests/DexDictateTests` depends
only on `["DexDictateKit", "DexDictateObjCSupport"]`, not the `DexDictate`
executable target — the same constraint documented in Packet 14 (which is
why `LivePreviewController` was relocated to `DexDictateKit` to become
testable) and reaffirmed in BUG-004's `VALIDATION.md`. Restructuring
`Package.swift` or moving `SettingsRootView`/`SettingsWindowController` into
`DexDictateKit` just to test this one SwiftUI view-state wire-up is out of
scope per this packet's explicit boundary ("do not destabilize
`Package.swift` just to test app-target SwiftUI views") and would be a much
larger, riskier change than the one-line reactivity fix itself. The full
`swift test` suite (410 tests) was run to confirm no regression elsewhere.

## Manual validation

See `VALIDATION.md` for the full checklist — marked `NEEDS_ANDREW`, since
this fix cannot be exercised by clicking through the running app from this
environment.
