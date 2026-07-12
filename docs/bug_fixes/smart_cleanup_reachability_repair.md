# Smart Cleanup Reachability Repair

## User-visible symptom

Settings → Diagnostics & Recovery always showed the Smart Cleanup endpoint as
"unreachable," with no way to distinguish "you haven't configured this yet" from "your
server is actually down" from "your model name is wrong," and no button to re-check
without leaving the page.

## Confirmed root cause

Not a broken health-check algorithm — `SmartCleanupClient.testConnection`/`.cleanup`
already returned rich, typed `SmartCleanupClientError` cases (`.invalidURL`,
`.http(Int)`, `.decoding`, `.network(String)`). Two separate bugs collapsed that detail
away before it ever reached the UI:

1. **State collapse.** `SmartCleanupCoordinator.reachability` was a 4-case enum
   (`.disabled`, `.unknown`, `.reachable`, `.unreachable`) that mapped every failure —
   no address configured, DNS failure, wrong port, HTTP 401, HTTP 500, a missing model —
   onto the single word "unreachable." An empty `baseURLString` (the correct, intentional
   default — Smart Cleanup is bring-your-own-server, so it defaults off with nothing
   configured) and a genuinely down server were indistinguishable to the user.
2. **Staleness.** Nothing ever called `refreshReachability()` except the Settings page's
   own "Test Connection" button. Enabling the toggle, or simply opening Diagnostics,
   never re-checked — a stale `.unknown` (or a stale success/failure from hours earlier)
   could sit there indefinitely, and Diagnostics had no action button at all to force a
   fresh check.

## Fix

`Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift`:

- `SmartCleanupReachability` expanded from 4 to 7 cases: `.notEnabled` (renamed from
  `.disabled` to match the vocabulary used elsewhere), `.unknown`, `.ready` (renamed from
  `.reachable`), `.serviceUnavailable(reason:)`, `.modelNotInstalled(reason:)`,
  `.authenticationRequired`, `.lastRequestFailed(reason:)`. Added `statusLabel`/`detail`
  computed properties so every surface renders the same vocabulary from one source of
  truth instead of each call site re-deriving its own switch.
- Two private mapping helpers translate `SmartCleanupClientError` into the richer enum:
  HTTP 401/403 always becomes `.authenticationRequired` (regardless of which call
  surfaced it); an empty/invalid URL becomes `.serviceUnavailable(reason: "No server
  address configured.")`; every other error keeps its own `localizedDescription` as the
  detail. A connection-test failure maps to `.serviceUnavailable`; a real cleanup-attempt
  failure (post-delivery, not a user-initiated check) maps to `.lastRequestFailed` — kept
  distinct so "you haven't configured this" reads differently from "it broke just now."
- `refreshReachability()` now also cross-checks the configured model name against
  `SmartCleanupModelsResult.modelIDs` from the server's own `/models` response, producing
  `.modelNotInstalled(reason:)` when the server is reachable but doesn't have the
  configured model — a state that was previously indistinguishable from full
  unreachability.
- New `handleEnabledSettingChanged()` — called whenever `SmartCleanupSettings.enabled`
  flips — immediately sets `.unknown` and kicks off a background `refreshReachability()`,
  instead of leaving reachability stale until the next dictation or a manual Test
  Connection click. `start(history:)` also now fires an initial background refresh when
  Smart Cleanup starts already enabled (e.g. across an app relaunch).

`Sources/DexDictate/SettingsWindow/SmartCleanupPage.swift`:

- Added a status row (label + detail + "Check Again" button) directly on the page.
- `.onAppear` now triggers `refreshReachability()` — opening the page always re-checks.
- `.onChange(of: settings.enabled)` calls the new `handleEnabledSettingChanged()`.

`Sources/DexDictate/SettingsWindow/DiagnosticsPage.swift`:

- `smartCleanupStatusLabel` now delegates to `reachability.statusLabel` instead of its
  own 4-case switch (which would no longer compile against the expanded enum).
- Added the detail line (when present) and an explicit "Check Again" button — Phase 3's
  requirement that this page not just display a passive status but let the user force a
  fresh check without leaving Diagnostics.

## Files changed

- `Sources/DexDictateKit/SmartCleanup/SmartCleanupCoordinator.swift`
- `Sources/DexDictate/SettingsWindow/SmartCleanupPage.swift`
- `Sources/DexDictate/SettingsWindow/DiagnosticsPage.swift`
- `Tests/DexDictateTests/SmartCleanupTests.swift`

## What did not change

- `SmartCleanupSettings.enabled` still defaults to `false` and `baseURLString` still
  defaults to `""` — Smart Cleanup remains fully opt-in, bring-your-own-server. Nothing
  in this fix turns it on or configures a default endpoint.
- `SmartCleanupClient`'s request-building and network calls are untouched — this was a
  state-model and UI-surfacing fix, not a client-layer fix.
- The "at most one cleanup attempt per item, raw text stands on failure" behavior is
  unchanged; `attemptCleanup` still never retries.

## Tests added

`Tests/DexDictateTests/SmartCleanupTests.swift`:

- `SmartCleanupCoordinatorTests` (existing suite, extended): `.disabled` references
  renamed to `.notEnabled`; added `testEnablingAfterStartTransitionsThroughUnknownAndTriggersRefresh`,
  `testDisablingAfterEnabledResetsToNotEnabled`,
  `testRefreshReachabilityWithNoBaseURLReportsServiceUnavailable`,
  `testRefreshReachabilityWhileDisabledStaysNotEnabled`.
- `SmartCleanupReachabilityLabelTests` (new) — pins `statusLabel`/`detail` for every case.
- `SmartCleanupCoordinatorMockedBackendTests` (new) — a `URLProtocol`-based mock
  intercepts `URLSession.shared` requests (the only testable seam, since the coordinator
  always calls `SmartCleanupClient` with the default `.shared` session) to exercise real
  request/response mapping without a live server:
  - `testRefreshReachabilityReportsReadyWhenConfiguredModelIsPresent`
  - `testRefreshReachabilityReportsModelNotInstalledWhenConfiguredModelIsMissing`
  - `testRefreshReachabilityReportsAuthenticationRequiredOn401`
  - `testSuccessfulCleanupAttachesCleanedTextAndReportsReady`
  - `testFailedCleanupReportsLastRequestFailedAndLeavesRawTextStanding`

## Validation results

- `swift build` — success.
- `swift test` — 461/461 passing (3 environment-dependent skips unrelated to this fix).
- `./build.sh` — success; release built, codesigned, installed to
  `/Applications/DexDictate.app`.
- `git diff --check` — no whitespace errors.
- Manual GUI validation: **not performed.** This environment has no Accessibility
  permission for AppleScript/System Events UI scripting (`UI elements enabled` reports
  `false` under `osascript`), so clicking through the Settings page or capturing real
  screenshots isn't possible here. See the final response's "Andrew validation steps"
  for the exact manual checks needed.

## Remaining limitations

- The richer states (`.modelNotInstalled`, `.authenticationRequired`) only populate once
  a connection test actually runs against a real (or mocked, in tests) server — there is
  no way to know a model is missing without asking the server.
- No retry/backoff was added to `refreshReachability()` — a single check per trigger
  (enable, page open, or explicit "Check Again"), matching the existing "single attempt,
  no retry storm" philosophy already established for `attemptCleanup`.
