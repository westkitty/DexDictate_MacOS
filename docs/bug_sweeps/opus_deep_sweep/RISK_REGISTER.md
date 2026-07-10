# Opus Deep Sweep — Risk Register

Suspected risks are NOT bugs and were NOT fixed (packet rule). Each entry has an exact
confirmation step so Andrew (or a future live-capable session) can convert it to a bug or
dismiss it. RISK-001..003 are carried forward from the post-campaign sweep and re-examined
against current source; RISK-004 is newly noted this sweep.

### RISK-001: "Learn Correction" sheet may not present from the slim popover
- Status: monitored
- Severity if real: low (one optional convenience control fails to open; raw dictation and
  all core output unaffected)
- Evidence: `PopoverResultView.swift:90` presents `VocabularyCorrectionSheet` via
  `.sheet(isPresented:)` from inside a `MenuBarExtra(.window)` popover. BUG-001 established
  that a SwiftUI *anchored* presentation (`.confirmationDialog`) silently fails to appear in
  exactly this container because the popover loses key status. Circumstantially, the codebase
  elsewhere deliberately avoids SwiftUI modals from the popover — Per-App Rules and file
  import open a native `NSWindow`/`NSOpenPanel`, not a `.sheet` — which is consistent with
  `.sheet` being known-unreliable there.
- Why not confirmed: `.sheet` and `.confirmationDialog` are different presentation
  mechanisms; SwiftUI can present a sheet by re-parenting to a host window, and some macOS
  versions handle popover sheets correctly. Confirming requires clicking the live control,
  which is impossible headlessly (LSUIElement / no accessibility click-through, the same
  blocker documented in every prior packet).
- What would confirm it: In the running app, dictate once, click **Learn Correction** in the
  popover result card. If the correction sheet does NOT appear, this is a real instance of
  the BUG-001 class and should be fixed by presenting `VocabularyCorrectionSheet` in a
  dedicated `NSWindow` (same pattern as `openPerAppInsertionWindow()`), not `.sheet`.
- Recommendation: Andrew verifies with one click. Do not preemptively rewrite a working
  control on suspicion — if it opens, close this risk.

### RISK-002: Smart Cleanup may re-attempt a previously-failed item after delete+undo
- Status: dismissed (reasonable behavior)
- Severity if real: very low
- Evidence: `SmartCleanupCoordinator.handleItemsChanged` re-attempts cleanup when the newest
  item's id differs from `lastSeenItemID` and its `cleanedText == nil`. A delete+undo can
  make a previously-failed item "newest" again, triggering one more attempt.
- Why not confirmed / dismissed: This is a single additional attempt gated on real user
  interaction (delete then undo) — not a retry storm, not a loop, and it only re-runs for an
  item that never got a cleaned variant. A retry after explicit user action is defensible.
- What would confirm it as a defect: evidence of repeated/looping network calls for one item
  without user interaction — not observed in code (`cleanedText == nil` short-circuits any
  already-cleaned item).
- Recommendation: No action. Default-off feature; behavior is benign.

### RISK-003: Smart Cleanup API key writes to Keychain on every keystroke
- Status: monitored (inefficiency, not incorrectness)
- Severity if real: very low (extra `SecItemDelete`+`SecItemAdd` per character typed in the
  API Key field)
- Evidence: `SmartCleanupPage.swift:104` — `.onChange(of: apiKeyDraft) { settings.apiKey = $0 }`
  and `SmartCleanupSettings.apiKey`'s setter calls `SmartCleanupKeychain.save`, which deletes
  and re-adds the item each call.
- Why not confirmed as a bug: correctness is unaffected — the final value is always correct,
  and the field is rarely edited. Purely a micro-efficiency point.
- What would confirm it worth fixing: profiling showing Keychain churn or a user complaint of
  keystroke lag in that specific field (neither observed).
- Recommendation: Optional future polish — persist API key on field commit / focus loss
  rather than per keystroke. Not in scope for a stabilization sweep.

### RISK-004: Nano HUD toggle taking effect while the HUD window is hidden
- Status: dismissed (documented experimental caveat)
- Severity if real: very low (experimental, default-off feature)
- Evidence: `FloatingHUD.show()` sets `ignoresMouseEvents` and the root view only when
  `window == nil`; `refresh()` only recreates the window when it is currently visible. So
  toggling `useExperimentalNanoHUD` while the HUD is hidden but its window object still exists
  can leave the old variant until the window is next recreated.
- Why not confirmed / dismissed: `useExperimentalNanoHUD` defaults off; the Advanced/legacy
  captions already tell the user to "toggle while HUD is hidden for cleanest switch," and the
  standard→nano switch resolves the next time the window is recreated. No effect on dictation,
  audio, output, or the default HUD.
- What would confirm it worth addressing: a user report that switching HUD styles appears to
  do nothing. If so, `refresh()` could unconditionally drop `window` so the next `show()`
  rebuilds with current flags.
- Recommendation: No action this sweep; note for any future Nano HUD polish pass.

## Dead code observed (not a risk, recorded for transparency)
- `useExperimentalStateFirstUI` (`AppSettings.swift:135`) is read only by a toggle at
  `QuickSettingsView.swift:695`, which lives inside `if showLegacyExperimentalUICard` where
  `showLegacyExperimentalUICard = false` (compile-time constant), inside `AntiGravityMainView`
  which only renders when `useSlimPopover == false` (default `true`). The control is therefore
  doubly unreachable dead code with zero user-facing effect — consistent with the
  post-campaign sweep's note. Left untouched (removing it would churn working, dormant code
  outside this sweep's mandate and risks nothing by remaining).
