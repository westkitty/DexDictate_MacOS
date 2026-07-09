# Packet 14 — Manual Validation Gaps + Judgment Calls

## Same LSUIElement/accessibility blocker as every prior packet

No screenshots, no manual click-through of: the "Live Preview (experimental)" toggle in
Settings → Dictation, the PREVIEW caption actually appearing in the popover hero or
Floating HUD while speaking, the "Finalizing…" handoff moment, or an extended ≥10-dictation
manual session with preview on. All of this requires either live speech input or clicking
through the running app — both blocked by the same automation gap documented in every
packet this entire session.

## Kill switch is a documented proxy, not a literal provider-error hook

The goal text asks for "kill switch: any preview-provider error disables preview for the
session." I looked hard for a way to observe an ACTIVE streaming provider's error mid-
utterance from outside `TranscriptionEngine.swift` (forbidden) and concluded there isn't
one:
- `provider.onError`/`onPartialResult` are single-slot closures. `TranscriptionEngine.swift`
  already assigns them (inside `startLiveProviderSessionIfNeeded()`) to relay into its own
  `liveTranscript`. If `LivePreviewController` assigned them too, it would silently
  overwrite the engine's own assignment — the engine's `liveTranscript` relay would stop
  working, a real regression, not a hypothetical one.
- `TranscriptionProviderRegistry.healthReport` is a pre-flight check, refreshed on demand —
  not a live "did the active session just crash" signal.

Given this, `LivePreviewController` polls `registry.refreshHealthReport()` every 2 seconds
while listening and treats the resolved provider becoming unavailable as a kill signal. This
is safe (calls only already-public, cheap, non-forbidden methods) and reasonably correlated
with real degradation (permission revoked, provider unloaded), but it is NOT a precise
"caught the crash the instant it happened" mechanism — a provider that crashes and recovers
within the same 2-second window, or crashes silently without flipping its own health-check
booleans, would not trigger this kill switch. If you want a precise mechanism, the actual
hook needed is a new `@Published var lastStreamingProviderError: Error?` (or similar) added
to `TranscriptionEngine.swift` itself — which I did not add, since that file is forbidden
for this packet ("INCLUDING in this packet," per its own header).

## Live simulated-failure test not performed

Per the above, a live "simulate a provider crash mid-utterance, confirm dictation completes
normally and preview disables for the session" test was not run end-to-end — forcing a real
provider (Nemotron/Apple Speech) into a deterministic unavailable state without adding new
test seams to the provider classes (beyond this packet's scope) wasn't practical in the time
available. The kill-switch code path was verified by reading, and the happy path (no
failure) is covered by `LivePreviewInvariantTests`.

## File location deviation: `LivePreviewController.swift` lives in `DexDictateKit`

The packet's goal text says `Sources/DexDictate/LivePreview/LivePreviewController.swift`.
I put the controller in `Sources/DexDictateKit/LivePreview/` instead, because the test
target (`Tests/DexDictateTests`) only depends on `DexDictateKit`/`DexDictateObjCSupport` in
`Package.swift` — not the `DexDictate` executable target. Adding that dependency to enable
`@testable import DexDictate` for the invariant test would have required a `Package.swift`
change to a target with a SwiftUI `@main` entry point, which I assessed as carrying real,
hard-to-predict build risk for uncertain benefit. Moving the controller (Combine/Foundation
only, no SwiftUI needed) into `DexDictateKit` — where several other `ObservableObject`
classes already live (`TranscriptionHistory`, `AppSettings`, `TranscriptionProviderRegistry`)
— sidesteps this with zero `Package.swift` changes. The SwiftUI caption view stays in
`Sources/DexDictate/` as intended. Flagging this explicitly since it's a real deviation from
the literal instruction, made for a documented safety reason.

## Nano HUD does not show the preview caption

Only the standard `FloatingHUDView` and the popover hero (`PopoverHeroView`) render the
caption, per the goal's "and/or" wording. `DexNanoHUDView.swift` (the already-adopted Nano
HUD, Packet 12A/12B) was left untouched to avoid risking that component. If you want the
caption there too, that's a small, low-risk follow-up.

No new orphaned controls, no new forbidden-file strings, no storage-key changes beyond the
one new additive `livePreviewEnabled` key (default `false`).
