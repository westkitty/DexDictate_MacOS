# Post-Campaign Bug Sweep — Bug Ledger

## Confirmed bugs

### BUG-001: Quit confirmation dialog silently never appears in the slim popover
- Status: fixed
- Severity: critical (core action — Quit — appeared to do nothing; user-reported)
- Location / affected area: `Sources/DexDictate/PopoverRootView.swift` (header power button
  + footer overflow menu's "Quit App" item)
- Evidence: User report ("quitting doesnt quit"), reproduced by clicking the power icon —
  no confirmation appeared, app kept running. `osascript -e 'tell application "DexDictate"
  to quit'` (the standard Apple Event quit path) worked fine, isolating the problem to the
  in-app SwiftUI confirmation flow specifically, not `NSApplication.terminate` itself.
- Root cause / likely cause: SwiftUI's `.confirmationDialog` presented from a view hosted
  inside a `MenuBarExtra(.window)` popover can lose key window status and dismiss the
  instant it tries to present — the dialog silently never renders, so the user's tap on
  "Quit" (which they never saw) never fires.
- Exact fix required: Replace `.confirmationDialog` with a native `NSAlert.runModal()`,
  which runs its own independent modal session and does not depend on the popover's window
  key status. This exact pattern was already proven working elsewhere in this codebase
  (`DiagnosticsPage`'s "Reset Core Audio?" confirmation).
- Validation method: Rebuilt, relaunched, Andrew clicked the power icon, confirmed the
  "Quit DexDictate?" alert appeared and clicking Quit closed the app (no crash report in
  `~/Library/Logs/DiagnosticReports/`).
- Fix result: Fixed and confirmed working by Andrew. Committed as `860b17d7` **before**
  this formal sweep began (it was an ad hoc live-bug fix requested directly). Carried
  forward into this ledger for completeness/traceability, not re-applied.

### BUG-002: Live Preview's "Finalizing…" badge sticks forever after the first dictation
- Status: fixed
- Severity: high (Live Preview is a shipped, user-facing feature; once triggered, this
  makes the popover hero / Floating HUD show a permanent, incorrect "Finalizing…" spinner
  during ordinary idle state — a visible, confusing, self-inflicted regression in new
  campaign code, though gated behind a default-off toggle)
- Location / affected area: `Sources/DexDictateKit/LivePreview/LivePreviewController.swift`,
  `handleStateChanged(_:)`
- Evidence: Traced the engine's own state machine
  (`Sources/DexDictateKit/EngineLifecycle.swift:63`: `case (.transcribing,
  .transcriptionCompleted): return .ready`) against `LivePreviewController`'s handling:
  ```swift
  switch state {
  case .listening: beginSession()
  case .transcribing:
      isFinalizing = true
      stopThrottledSubscriptions()
  default:
      endSession(clearImmediately: false)   // <-- does NOT reset isFinalizing
  }
  ```
  `endSession(clearImmediately:)` only resets `caption`/`micLevel`/`isFinalizing` when
  `clearImmediately == true`. The `default:` branch (which is exactly what fires when the
  engine returns to `.ready` after `.transcribing` completes) passes `false`, so
  `isFinalizing` stays `true` indefinitely. `LivePreviewCaptionView`'s body
  (`if controller.isFinalizing { finalizingBadge } else if !controller.caption.isEmpty {
  captionRow }`) then shows the "Finalizing…" spinner permanently, in both the popover hero
  and the standard Floating HUD, until the next time the user starts a new listening
  session (the only other place `isFinalizing` gets reset, inside `beginSession()`).
- Root cause / likely cause: An oversight when introducing the `clearImmediately`
  parameter — it was meant to distinguish "hard reset" (disabled/killed) from "soft
  transition away from an active session," but the soft-transition case still needs to
  clear the finalizing badge, since there is nothing left to finalize once the engine is
  back at `.ready`/`.stopped`/`.error`/`.initializing`.
- Exact fix required: Change the `default:` case's call from
  `endSession(clearImmediately: false)` to `endSession(clearImmediately: true)`. Once
  outside `.listening`/`.transcribing`, there is no scenario where preserving a stale
  caption or a stuck "Finalizing…" badge is correct — full reset is the right behavior in
  every remaining state.
- Validation method: Added `testFinalizingBadgeClearsAfterTranscriptionCompletes` to
  `LivePreviewInvariantTests.swift`, driving a real `TranscriptionEngine` through
  `.listening → .transcribing → .ready` and asserting `isFinalizing == false` and
  `caption == ""` afterward. **The new test itself initially failed** at the
  `.transcribing` assertion — this surfaced a second, related defect: `engine.$state` and
  `engine.$inputLevel` were subscribed with a redundant `.receive(on: DispatchQueue.main)`,
  even though `TranscriptionEngine` is already `@MainActor` (so these properties are
  guaranteed to publish on the main actor already). The extra redispatch delayed
  `handleStateChanged` by one run-loop tick, racing the test's synchronous assertions (and,
  in the real app, adding an imperceptible-but-real one-tick delay to the "Finalizing…"
  handoff). Fixed by removing both redundant `.receive(on:)` calls — `TranscriptionEngine`'s
  actor isolation already guarantees main-thread delivery without them. Full `swift test`
  run after both fixes: 410 tests, 1 failure (the documented pre-existing
  `MainActorActionTests` flaky test, unrelated, clean on rerun).
- Fix result: Fixed in this sweep (Pass 2). See `VALIDATION_LOG.md` for the test run
  confirming the fix and `RESWEEP_LOG.md` for the adjacent-code recheck.

### BUG-003: `SmartCleanupCoordinator`'s default init argument triggers a Swift 6 actor-isolation warning
- Status: fixed
- Severity: medium (not a runtime bug today — current build succeeds and behaves
  correctly — but a confirmed, evidence-backed forward-compatibility defect: the compiler
  itself states "this is an error in the Swift 6 language mode," meaning this line would
  fail to compile if the package ever adopts Swift 6 language mode)
- Location / affected area: `Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift:33`
- Evidence: Compiler warning surfaced during this sweep's validation build (not present in
  earlier per-packet build checks, which only grepped for `error:`, not `warning:`):
  ```
  warning: main actor-isolated static property 'shared' can not be referenced from a
  nonisolated context; this is an error in the Swift 6 language mode
  ```
  on `init(settings: SmartCleanupSettings = .shared)`.
- Root cause / likely cause: Swift evaluates default-argument expressions in a nonisolated
  context regardless of the enclosing type's actor isolation. `SmartCleanupSettings` is
  `@MainActor`-isolated, so `.shared` as a default-argument value is a genuine isolation
  mismatch. (`LivePreviewController`'s analogous `init(settings: AppSettings = .shared)`
  does NOT share this issue, because `AppSettings` itself is not `@MainActor`-annotated —
  confirmed by re-checking its class declaration.)
- Exact fix required: Changed the parameter to `SmartCleanupSettings? = nil` and resolved
  the actual default (`?? .shared`) inside the initializer body, which correctly inherits
  the class's `@MainActor` isolation (only default-argument *expressions* have the
  nonisolated-evaluation quirk — body code does not).
- Validation method: Rebuilt; confirmed the warning no longer appears anywhere in the
  build log. Ran the two existing call sites that pass `settings:` explicitly
  (`SmartCleanupTests.swift`) to confirm the signature change (`SmartCleanupSettings?`
  instead of `SmartCleanupSettings`) didn't break them (it doesn't — passing a non-optional
  value to an optional parameter is source-compatible).
- Fix result: Fixed in this sweep (Pass 2).

## Suspected risks (not confirmed bugs)

### SUSPECTED-001: `.sheet` for "Learn Correction" may share the same MenuBarExtra popover-dismissal risk as BUG-001
- Status: suspected
- Severity: medium (if real, breaks a real feature — learning a vocabulary correction from
  the popover's last result — the same way BUG-001 broke Quit)
- Location / affected area: `Sources/DexDictate/PopoverResultView.swift:90`,
  `.sheet(isPresented: $isCorrectionSheetPresented) { VocabularyCorrectionSheet(...) }`
- Evidence: Same hosting context as the just-fixed quit dialog (a view inside the
  `MenuBarExtra(.window)` slim popover) using a SwiftUI presentation modifier
  (`.sheet`, not `.confirmationDialog`, but a related family of "attached to a
  potentially-non-key window" APIs). This is a pre-existing pattern (predates this
  campaign — the "Learn Correction" flow existed before Packet 09), so it is not a
  regression this campaign introduced, but it was never explicitly re-validated after the
  slim popover became the default (Packet 09B).
- Root cause / likely cause: Unconfirmed — `.sheet` behaves differently from
  `.confirmationDialog` (it attaches as a child sheet of the presenting window rather than
  a free-floating dialog), so it may not share the exact failure mode. Requires live
  manual testing to confirm either way.
- Exact fix required: Not determined — do not speculatively rewrite until reproduced.
  If confirmed, the same `NSAlert`-or-native-window fix pattern likely applies (or
  presenting `VocabularyCorrectionSheet` in its own small `NSWindow` instead of a SwiftUI
  `.sheet`).
- Validation method: Requires a live manual test — dictate something, click "Learn
  Correction" on the result, confirm the sheet actually appears and is usable. Not
  performed in this sweep (same LSUIElement/accessibility blocker as everything else).
- Fix result: Not fixed — flagged for Andrew's manual verification. See the final report's
  manual validation checklist.

### SUSPECTED-002: Smart Cleanup may re-attempt cleanup on an item after a delete+undo brings it back to "newest"
- Status: suspected
- Severity: low (narrow edge case, arguably reasonable behavior rather than a bug, does not
  violate the "no retry storm" acceptance criterion since it requires a deliberate
  delete+undo user action, not automatic retry)
- Location / affected area: `Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift`,
  `handleItemsChanged(_:)`
- Evidence: The coordinator only tracks `lastSeenItemID` (the most recent item it has
  already reacted to) — it has no per-item "already attempted and failed" marker beyond
  `cleanedText == nil`. If item A's cleanup fails (leaving `cleanedText` nil) and item B is
  later added (making item A no longer "newest"), then the user deletes item B and
  immediately undoes the deletion — depending on the exact sequence, item A could become
  "newest" again with `cleanedText` still nil, causing a second cleanup attempt.
- Root cause / likely cause: By design — the coordinator has no failure-tracking field
  separate from "never attempted." This was a deliberate minimal design (per the packet's
  own "no retry storm" requirement, interpreted as "no automatic background retry," which
  this doesn't violate — it only re-attempts on a user-driven history mutation).
- Exact fix required: Not determined — would require adding a `cleanupAttempted: Bool`
  (or similar) field to `HistoryItem`, which is additional scope beyond a narrow bug fix
  and arguably not needed (single manual retry after a delete+undo is reasonable, not
  harmful — it's still bounded to one attempt per "became newest" event, not unbounded).
- Validation method: Not performed — would require simulating delete+undo interleaved with
  a failing cleanup call, non-trivial to set up deterministically without network mocking.
- Fix result: Not fixed — deferred. Documenting rather than fixing speculatively, per this
  sweep's own rule against inflating a narrow edge case into an urgent fix.

### SUSPECTED-003: Smart Cleanup's API key field writes to Keychain on every keystroke
- Status: suspected
- Severity: low (inefficiency, not a correctness bug)
- Location / affected area: `Sources/DexDictate/SettingsWindow/SmartCleanupPage.swift`,
  `.onChange(of: apiKeyDraft) { _, newValue in settings.apiKey = newValue }`
- Evidence: `SmartCleanupSettings.apiKey`'s setter calls `SmartCleanupKeychain.save(_:)`,
  which does a `SecItemDelete` + `SecItemAdd` pair. `.onChange` fires on every keystroke
  while typing into the SecureField, meaning a 20-character API key triggers ~20
  delete+add cycles against the Keychain.
- Root cause / likely cause: Straightforward binding wiring — no debounce was added since
  this wasn't flagged as a requirement during Packet 13.
- Exact fix required: Not applied — would require adding a debounce (e.g., only save on
  field blur / a short delay after the last keystroke), which is a small behavior change
  beyond a narrow bug fix. Not user-visible (Keychain writes are fast and silent) and not
  a correctness issue.
- Validation method: Not performed — no observable symptom to validate against.
- Fix result: Not fixed — documented as a minor efficiency note for a future pass, not
  actioned in this sweep (out of scope: "avoid speculative refactors").

## Pre-existing, already-documented items (carried forward, not new findings)

These were already known and documented in prior packet `NEEDS_ANDREW.md` files; restated
here only for the ledger's completeness, not re-litigated:

- Live Preview's kill switch is a health-poll proxy, not a literal provider-error hook
  (Packet 14 `NEEDS_ANDREW.md`).
- No live Ollama tunnel available to validate Smart Cleanup's true success path (Packet 13
  `NEEDS_ANDREW.md`).
- 22 stale "Quick Settings →" Help references remain out of scope (Packet 10/10B).
- Forbidden-file string `TranscriptionEngine.swift:1262` ("Retrying in accuracy mode...")
  cannot be renamed without explicit permission (Packet 10).
- `MainActorActionTests.testRunAsyncExecutesOnMainActor` /
  `MainActorDispatchTests.testAsyncRunsOnMainThreadAsynchronously` are a known-flaky,
  pass-clean-on-rerun test family (pre-existing, not introduced by this campaign).
