# DexDictate 1.5.2 Crash Handoff — macOS SwiftUI Main-Thread Segfault

## Purpose

This is a condensed handoff for another AI or engineer to continue diagnosis and remediation of a DexDictate crash report without re-reading the full macOS crash log.

## Executive Summary

DexDictate `1.5.2` is crashing on **macOS 26.4.1** on **Apple Silicon (ARM64)** with:

- `EXC_BAD_ACCESS (SIGSEGV)`
- `KERN_INVALID_ADDRESS`
- faulting address: `0x000003e1aa010408`

The crash occurs on the **main thread** during a **SwiftUI layout/update cycle**, not in a background worker. The stack strongly suggests a **bad object reference / use-after-free / invalid executor-related object access during SwiftUI view construction or layout**, likely involving a view tree that includes:

- `HStack`
- `ScrollView`
- `ZStack`
- frame / flex frame layout
- a platform/AppKit-backed control, specifically:
  - `SystemSegmentedControl._overrideSizeThatFits(_:in:nsView:)`

There is also deep repeated recursion in `LayoutEngineBox.sizeThatFits(_:)`, which suggests either:

1. a **pathological SwiftUI layout feedback loop / recursive size computation**, or
2. a **dangling/corrupted object being touched during repeated layout passes**, where recursion is a symptom and not the root cause.

The most suspicious non-system frame near the crash is inside **Apple `DesignLibrary`**, called during `HStack.init(...)`, but the app-owned source location visible in the trace is only the app entrypoint:

- `DexDictateApp.swift`

That means the useful next step is to inspect the **initial/root SwiftUI scene and any early-rendered controls**, especially any segmented control or custom view composition rendered immediately after launch.

---

## Environment

- **App:** DexDictate
- **Bundle ID:** `com.westkitty.dexdictate.macos`
- **Version:** `1.5.2`
- **Process role:** Background
- **Architecture:** `ARM-64 (Native)`
- **Hardware model:** `MacBookAir10,1`
- **OS:** `macOS 26.4.1 (25E253)`
- **SIP:** enabled
- **Launch time:** `2026-04-23 06:32:56 -0400`
- **Crash time:** `2026-04-23 06:41:17 -0400`

Time from launch to crash: about **8 minutes 21 seconds**.

This matters because it does **not** look like an immediate startup failure in dyld, codesigning, entitlement loading, or audio session initialization. The app survived long enough to reach a UI state that later triggered a fatal layout/update.

---

## Crash Signature

- **Exception type:** `EXC_BAD_ACCESS (SIGSEGV)`
- **Subtype:** `KERN_INVALID_ADDRESS`
- **Fault address:** `0x000003e1aa010408`
- **Termination:** `Namespace SIGNAL, Code 11`

Interpretation:

The process attempted to read memory at an address that is not mapped. That usually means one of:

- use-after-free
- dangling pointer / stale object reference
- unsafe bridging between Swift / Objective-C / AppKit / C API
- actor/executor-related invalid object state
- memory corruption surfacing during UI layout

This does **not** look like a normal Swift trap, assertion, or explicit fatalError. It is a raw invalid memory access.

---

## Faulting Thread

**Thread 0 — main thread**

Top of stack:

1. `swift_getObjectType`
2. `swift_task_isMainExecutorImpl`
3. `swift::SerialExecutorRef::isMainExecutor() const`
4. `swift_task_isCurrentExecutorWithFlagsImpl(...)`
5. `DesignLibrary`
6. `SwiftUICore closure #1 in HStack.init(alignment:spacing:content:)`
7. `_VariadicView.Tree.init`
8. `HStack.init(alignment:spacing:content:)`

### Why this matters

The crash happens while Swift tries to determine object type / executor state, which implies some object pointer passed into concurrency or UI code is invalid by the time it is read.

That makes these hypotheses most plausible:

- a view model / observable object / state object got deallocated while still referenced by UI
- a closure captured a stale reference used during layout
- main-actor isolation is violated somewhere and UI state is mutated from the wrong context, later exploding during render/layout
- an AppKit-backed SwiftUI wrapper view is feeding invalid state into size calculation
- a custom segmented control configuration or binding is invalidating the view hierarchy

---

## Strongest Indicators from the Stack

### 1. Main-thread SwiftUI layout crash

Relevant frames include:

- `ViewBodyAccessor.updateBody`
- `DynamicBody.updateValue`
- `ViewGraph.sizeThatFits`
- `ViewGraphRootValueUpdater.render`
- `NSHostingView.layout`

This is a classic SwiftUI render/layout path.

### 2. Repeated recursive layout

The trace shows:

- `LayoutEngineBox.sizeThatFits(_:)`
- recursion levels up to **15**
- repeated `LayoutProxy.size(in:)`
- repeated stack layout / frame layout placement calls

This suggests:

- some view depends on its own measured size indirectly
- a control is causing cyclical layout negotiation
- a representable/AppKit bridge is returning unstable sizes
- or the repeated layout simply amplifies an already-invalid reference until the crash occurs

### 3. Platform-backed control involvement

This frame stands out:

- `SwiftUI specialized SystemSegmentedControl._overrideSizeThatFits(_:in:nsView:)`

That is a real clue, not background noise.

It points to a view tree containing a **segmented control** or something rendered as one. If DexDictate’s UI includes a mode switcher, toolbar segment, tab-like selector, or any segmented picker near the time of crash, inspect that first.

### 4. DesignLibrary involvement

Two nearby frames are from:

- `com.apple.DesignLibrary`

This suggests the crash may be triggered while building a system-styled control or design-system component, not necessarily inside app business logic. Still, Apple frameworks usually become the crash site when the app hands them invalid state.

---

## What the Crash Does *Not* Point To

These areas appear in the process but are not the most likely root cause:

- Core Audio threads
- media/image queue threads
- caulk worker threads
- NSEvent secondary thread
- launchd
- codesigning / SIP
- Rosetta / translation issues (`translated: false`)
- low-memory kill
- external process tampering

Audio threads exist, but the fatal thread is the main UI thread. Audio may still contribute indirectly if it triggers UI updates, but the direct crash is in view/layout/concurrency territory.

---

## Likely Root Cause Categories

Ranked from most to least likely.

### A. Invalid SwiftUI state object or stale reference during layout
Examples:

- `@ObservedObject` used where `@StateObject` is required
- object lifetime tied to a transient parent view
- deallocated model still referenced by bindings or closures
- weak/unowned capture later used by the UI

Why it fits:
- raw bad access
- `swift_getObjectType`
- render/layout path
- delayed crash after launch

### B. MainActor / concurrency isolation violation affecting UI state
Examples:

- mutating UI-observed state from a background task
- `Task.detached` updating model read by SwiftUI
- actor-hopping bug where state is assumed main-thread-safe but is not
- object accessed after async cancellation / teardown

Why it fits:
- executor-check functions are at the very top of the crashing stack

### C. Segmented control / AppKit representable layout bug
Examples:

- segmented picker with unstable selection binding
- segment labels/content changing during measurement
- custom `NSViewRepresentable` or wrapper returning inconsistent fitting size
- re-entrant size computation caused by `.frame`, `.fixedSize`, `GeometryReader`, or preference propagation around the control

Why it fits:
- explicit `SystemSegmentedControl._overrideSizeThatFits`
- deep layout recursion

### D. Recursive SwiftUI layout composition
Examples:

- nested `GeometryReader` + preference keys + size-dependent frames
- `ScrollView` inside stacks with self-referential size logic
- dynamic content in `ZStack/HStack` causing cyclic `sizeThatFits`

Why it fits:
- heavy recursive layout trace
- repeated frame/flex frame/layout engine calls

### E. Unsafe bridge / Objective-C / C pointer misuse
Examples:

- unmanaged pointer passed through Swift
- stale reference from CoreAudio callback to UI
- CFType/NSObject lifetime bug

Possible, but the stack leans more toward SwiftUI state/layout than raw C interop.

---

## Most Relevant Stack Frames to Keep

These are the frames another AI or engineer should anchor on:

- `swift_getObjectType`
- `swift_task_isMainExecutorImpl`
- `swift_task_isCurrentExecutorWithFlagsImpl`
- `HStack.init(alignment:spacing:content:)`
- `ViewBodyAccessor.updateBody`
- `DynamicBody.updateValue`
- `ViewGraph.sizeThatFits(_:)`
- `SystemSegmentedControl._overrideSizeThatFits(_:in:nsView:)`
- `PlatformViewRepresentableAdaptor.overrideSizeThatFits`
- `ViewLeafView.sizeThatFits`
- repeated `LayoutEngineBox.sizeThatFits(_:)`
- `ScrollViewUtilities.sizeThatFits`
- `_ZStackLayout.sizeThatFits`
- `NSHostingView.layout()`

---

## Practical Interpretation

This looks like:

> DexDictate reached a specific UI state, SwiftUI began laying out a view tree containing a segmented-control-backed element, layout recursed deeply, and during that process Swift attempted to inspect executor/object metadata for an invalid object pointer and segfaulted.

That means the next AI should **not** waste time on generic macOS crash boilerplate. The likely fix zone is the SwiftUI scene graph and state ownership.

---

## Recommended Investigation Order

### 1. Inspect the first user-visible/root SwiftUI views shown around the time of crash
Start from:

- `DexDictateApp.swift`
- root `Scene`
- root `WindowGroup` content
- any initial dashboard/panel/transcription controls
- any settings or mode switchers

Look specifically for:

- `Picker(...).pickerStyle(.segmented)`
- `SegmentedControl`
- `TabView`-like custom segmented header
- `NSViewRepresentable` wrapping AppKit controls
- toolbar/titlebar segmented controls

### 2. Audit state ownership in those views
Look for incorrect uses of:

- `@ObservedObject` where ownership belongs in `@StateObject`
- ephemeral view models created inline in `body`
- derived bindings that outlive their source
- `unowned self`
- weak references used without guard/rebind
- `@State` storing reference types unexpectedly

### 3. Audit all async UI mutations
Search for:

- `Task.detached`
- `DispatchQueue.global().async`
- callbacks from audio/transcription services that mutate published properties
- `await` chains that resume off main actor
- missing `@MainActor` on UI-facing models

Any model that SwiftUI reads during layout should be main-actor-safe.

### 4. Inspect segmented-control adjacent layout modifiers
Look for patterns like:

- `.frame(maxWidth: .infinity)` inside segmented control containers
- `GeometryReader` around segmented picker
- `ScrollView` containing controls whose size depends on parent geometry
- conditional branches changing segment content during layout
- preference keys used to resize a segmented header

### 5. Reproduce with layout simplification
Temporarily remove or stub, in order:

1. segmented controls / segmented pickers
2. custom AppKit representables
3. geometry/preference measurement logic
4. dynamic toolbar/header controls
5. animated layout changes

If crash disappears after removing the segmented control or header composition, that area is the fault zone.

---

## Concrete Suspicion Patterns

Another AI should actively test these patterns in the codebase.

### Pattern 1: View model created in body
Bad:

```swift
var body: some View {
    let vm = SomeViewModel()
    ChildView(vm: vm)
}
```

or:

```swift
ChildView(vm: SomeViewModel())
```

This can produce lifetime churn and stale references.

### Pattern 2: Observed object owned by transient parent
Bad:

```swift
struct Parent: View {
    @ObservedObject var vm = SomeViewModel()
}
```

Should often be `@StateObject` if the view owns it.

### Pattern 3: Background mutation of published UI state
Bad:

```swift
Task.detached {
    self.status = ...
}
```

or callback-driven mutation not marshaled to main actor.

### Pattern 4: Segmented picker inside unstable size-feedback loop
Bad shape:

```swift
GeometryReader { geo in
    VStack {
        Picker(...).pickerStyle(.segmented)
            .frame(width: geo.size.width)
        ...
    }
}
```

combined with child views whose size also affects parent or scroll content.

### Pattern 5: NSViewRepresentable returning unstable fitting size
If any representable implements custom sizing or updates AppKit control properties during `updateNSView`, it can create re-entrant measurement churn.

---

## Triage Questions for the Next AI

Use these as the next-pass checklist:

1. What exact SwiftUI view hierarchy is active ~8 minutes after launch?
2. Does the app show or update a segmented control around that time?
3. Are any view models recreated during body recomputation?
4. Are audio/transcription callbacks mutating `@Published` properties off the main actor?
5. Is any `NSViewRepresentable` involved in the crashing screen?
6. Is there any size measurement feedback loop involving `GeometryReader`, preference keys, `ScrollView`, or `.frame(...)` modifiers?
7. Can the crash be suppressed by replacing segmented controls with plain buttons temporarily?
8. Do all UI-facing observable models have explicit `@MainActor` or equivalent main-thread guarantees?

---

## Highest-Value Code Search Terms

Search the project for:

- `pickerStyle(.segmented)`
- `SegmentedPickerStyle`
- `NSViewRepresentable`
- `sizeThatFits`
- `GeometryReader`
- `PreferenceKey`
- `onAppear`
- `task`
- `Task.detached`
- `DispatchQueue.main`
- `DispatchQueue.global`
- `@ObservedObject`
- `@StateObject`
- `@MainActor`
- `Published`
- `Toolbar`
- `NSSegmentedControl`

---

## Most Likely Fix Directions

### Fix direction 1: Correct object ownership
Convert app-owned observable objects from `@ObservedObject` to `@StateObject` at the ownership boundary.

### Fix direction 2: Enforce main-actor UI model updates
Mark UI models `@MainActor`, or route callback mutations through main actor explicitly.

### Fix direction 3: Remove self-referential layout
Simplify segmented/header layout and eliminate geometry-driven sizing loops.

### Fix direction 4: Stabilize AppKit wrapper sizing
If a representable is involved, ensure:
- `updateNSView` is idempotent
- sizing is stable
- no mutation during measurement
- no hidden retain/lifetime bugs

---

## Non-Root-Cause Data Worth Keeping

- Audio threads are active, so DexDictate is likely using audio input/output at runtime.
- Crash occurs in process role `Background`, so the app may be menu bar / agent style, but still hosts SwiftUI/AppKit UI.
- Memory pressure is not obvious from the report.
- No evidence of external injection or tampering.
- Native Apple Silicon build; not a translation artifact.

---

## Minimal Handoff Conclusion

The crash is most likely a **SwiftUI main-thread state/lifetime/concurrency bug expressed during recursive layout**, with a **segmented control or AppKit-backed view** as the most suspicious UI element. The next AI should focus on the **root view hierarchy, state ownership (`@StateObject` vs `@ObservedObject`), main-actor correctness, and segmented-control/layout interactions**, not on audio worker threads or generic OS crash mechanics.

---

## Suggested Next Action for the Next AI

Ask for or inspect:

1. `DexDictateApp.swift`
2. the root content view
3. any view containing a segmented picker, toolbar segment, or `NSViewRepresentable`
4. any observable object mutated by audio/transcription callbacks

Then produce:

- a narrowed root-cause hypothesis tied to actual code
- one or two likely offending views/models
- a concrete patch plan

