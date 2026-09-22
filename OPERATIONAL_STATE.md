# Operational State: DexDictate macOS

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "dexdictate-macos",
  "project_name": "DexDictate macOS",
  "project_root": ".",
  "artifact_path": null,
  "state_revision": 4,
  "last_updated": "2026-09-22",
  "current_baseline": {
    "identity": "fix/golden-gate-permission-flow / PR #7",
    "state": "audited-awaiting-ci-runtime-codex",
    "last_verified": null
  },
  "scope_boundaries": [
    "Golden Gate compatibility repair for macOS permission and global-trigger startup behavior"
  ],
  "linked_parent_state": null
}
-->

## 1. Project Identity and Scope
- **Project ID:** `dexdictate-macos`
- **Purpose:** Local-first Apple Silicon macOS dictation with global trigger capture and local transcription.
- **Project type:** Swift/SwiftUI macOS menu-bar application.
- **Primary root or artifact:** repository root.
- **Target environment:** macOS 14+ on Apple Silicon, including macOS 27 Golden Gate.
- **Canonical authority:** current source on `main` plus current tests; archived docs are evidentiary only.
- **Governed scope:** permission flow, global trigger event-tap authorization, onboarding/diagnostics copy, entitlements, and related tests.
- **Explicitly not governed:** transcription model behavior, audio-route recovery, output insertion semantics, undo, unrelated UI redesign, or release publication.

## 2. Current Baseline
- **Primary artifact:** current `main` source.
- **Baseline state:** current-baseline.
- **Release evidence:** README identifies v1.8.0 as latest packaged release.
- **Runtime on Golden Gate:** known-broken from user report: repeated reopen request during permission setup.
- **Local execution environment:** MacBook-Air.local remote endpoint is offline as of 2026-09-22, so runtime validation is unavailable.

## 3. Artifact Contract
Produce a bounded source repair that removes the unnecessary standalone Input Monitoring requirement for DexDictate's modifying `.defaultTap` event tap, preserves required Accessibility and Microphone flows, removes invalid entitlement declarations, and keeps existing dictation/trigger behavior intact.

## 4. Active Invariants
- **INV-001:** Global keyboard/mouse trigger capture must continue to use a modifying event tap so matched trigger events can be consumed.
- **INV-002:** Accessibility remains required for global trigger capture and Accessibility-based output insertion.
- **INV-003:** Microphone permission remains required for audio capture.
- **INV-004:** Local-only transcription and unrelated dictation behavior must not change.
- **INV-005:** Existing macOS 14+ support must remain intact.

## 5. Verified Working Behavior
- None promoted by this compatibility task yet.

## 6. Known Not Working
- **BRK-001:** On macOS 27 Golden Gate, the current v1.8 permission flow can enter a repeated reopen loop while configuring permissions.

## 7. Implemented but Unverified
- **UNV-001:** Golden Gate permission repair implemented on `fix/golden-gate-permission-flow`: standalone Input Monitoring request/gate removed; modifying event-tap behavior preserved under Accessibility; microphone flow preserved.
- **UNV-002:** Active onboarding, banners, diagnostics, state-first UI, help, entitlements, and regression tests were updated to the two-permission contract.
- **UNV-003:** Draft PR #7 contains the repair. Source review and two-pass bug sweep are complete; latest-head macOS CI is queued.
- **UNV-004:** Capability probing is throttled so the real active event-tap check does not run on every 2-second TCC poll.
- **UNV-005:** README now explicitly warns that packaged v1.8.0 predates the Golden Gate permission correction.

## 8. Unknown or Evidence-Stale State
- **UNK-001:** Exact Golden Gate runtime result after repair is unverified until a Golden Gate Mac can run the built app.
- **UNK-002:** Signing/notarization behavior of a future packaged hotfix is unverified until packaging is executed.
- **UNK-003:** Codex verification is unrun because the authorized MacBook endpoint hosting the Codex CLI is offline.
- **UNK-004:** Apple has an open Golden Gate/Sequoia/Tahoe report for system-wide input hangs when Accessibility is revoked while an active `.defaultTap` exists; applicability to DexDictate after this repair remains unverified.

## 9. Pending Work
- **PND-002:** Complete latest-head repository CI/build/tests through PR #7 (run #250 queued).
- **PND-003:** Run final packaged app on Golden Gate and verify first-launch permission journey.
- **PND-004:** Run the Mac-hosted Codex verification pass when the authorized MacBook endpoint is online.

## 10. Active Decisions, Defaults, and Prohibitions
- **DEC-001:** Do not require or proactively request standalone Input Monitoring for DexDictate's modifying event tap.
- **DEC-002:** Do not change the event tap to `.listenOnly`; DexDictate intentionally consumes matched trigger events.
- **DEC-003:** Do not publish a release or claim Golden Gate runtime success without runtime evidence.

## 11. Validation and Evidence Matrix
| ID | Claim or behavior | State | Evidence | Validation method | Artifact/revision | Last checked | Recheck trigger |
|---|---|---|---|---|---|---|---|
| BRK-001 | Golden Gate reopen loop exists | known-broken | user-observed runtime | reproduce on Golden Gate | v1.8.0 | 2026-09-22 | repaired build |
| INV-001 | modifying event tap remains | current-baseline | `InputMonitor.swift` uses `.defaultTap` | source + tests | main | 2026-09-22 | event-tap change |
| UNK-001 | repaired app works on Golden Gate | unknown | no online Golden Gate runner | manual runtime smoke test | fix/golden-gate-permission-flow | 2026-09-22 | repaired build available |
| UNV-001 | standalone Input Monitoring removed from required runtime path | implemented-unverified | branch diff / PR #7 | source review + CI pending | fix/golden-gate-permission-flow | 2026-09-22 | permission code change |

## 12. Current Change Scope and Impact Radius
- **Allowed to change:** permission manager/checker, onboarding validation/UI, permission banners/diagnostics, entitlement declaration, tests, current docs/state.
- **Must remain unchanged:** transcription, audio routing, output insertion, undo, history, model selection, unrelated UI.
- **Potentially affected behavior:** first launch, permission recovery, global trigger readiness diagnostics, app signing entitlements.
- **Mandatory checks:** Swift build, relevant unit tests, full test suite, entitlement source audit, CI.
- **Repair class:** bounded compatibility repair.

## 13. Compact Revision Log
### Revision 1 — 2026-09-22
- Initialized operational state for Golden Gate compatibility work.
- Recorded Golden Gate reopen loop as known-broken.
- Recorded MacBook remote endpoint as offline; runtime verification remains pending.


### Revision 2 — 2026-09-22

- **Artifact/source identity:** `fix/golden-gate-permission-flow`, draft PR #7.
- **State deltas:** Removed standalone Input Monitoring from required permission flow and entitlement; retained Accessibility-owned modifying event tap; updated active UI/docs/tests.
- **New evidence:** PR #7 source diff reviewed; forbidden standalone Input Monitoring calls/entitlement removed from the active permission path.
- **Validation not performed:** Latest-head Swift build/test and Golden Gate runtime test remain pending; the connected Mac endpoint is offline.


### Revision 3 — 2026-09-22

- **Artifact/source identity:** `fix/golden-gate-permission-flow`, draft PR #7.
- **State deltas:** Propagated the two-permission contract through current project guidance, developer instructions, help assets, experimental UI references, and marketing education content.
- **New evidence:** Added regression coverage forbidding standalone Input Monitoring request/entitlement; active source surfaces no longer present Input Monitoring as a required grant.
- **Validation pending:** Latest-head macOS CI and Golden Gate runtime smoke test.


### Revision 4 — 2026-09-22

- **Artifact/source identity:** `fix/golden-gate-permission-flow`, draft PR #7.
- **Bug sweep:** Two passes completed over the permission/runtime diff and scope. Confirmed issues fixed: repeated active event-tap probing on the 2-second timer; append-only `BIBLE.md` history violation; README's missing v1.8.0 Golden Gate caveat; collateral Fable/Remotion copy edits outside the bounded repair.
- **Scope verification:** No dependency manifests, lockfiles, model assets, transcription, audio-route, output insertion, undo, history, or unrelated runtime implementation remains changed.
- **Static validation:** Swift 6.2 parser accepted the two highest-risk changed Swift units (`PermissionManager.swift`, `PermissionCapabilityChecker.swift`). This is syntax evidence only, not a macOS typecheck.
- **External verification:** Apple DTS guidance confirms Accessibility already provides listen/post capability and that the alleged input-monitoring entitlement does not exist.
- **Automated validation:** GitHub Actions `DexDictate CI` run #250 is queued on the current PR head.
- **Blocked validation:** Golden Gate installed-app test and Codex CLI verification remain blocked by the offline MacBook endpoint.
