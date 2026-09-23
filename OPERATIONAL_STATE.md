# Operational State: DexDictate macOS

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "dexdictate-macos",
  "project_name": "DexDictate macOS",
  "project_root": ".",
  "artifact_path": null,
  "state_revision": 5,
  "last_updated": "2026-09-22",
  "current_baseline": {
    "identity": "fix/golden-gate-permission-flow / PR #7",
    "state": "source-and-build-validated-awaiting-golden-gate-runtime-with-pre-existing-lint-debt",
    "last_verified": "2026-09-22"
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
- **Local execution environment:** MacBook Air on macOS 26.6.2 with Xcode 26.3. This is not a macOS 27 Golden Gate runtime, so Golden Gate validation is unavailable here.

## 3. Artifact Contract
Produce a bounded source repair that removes the unnecessary standalone Input Monitoring requirement for DexDictate's modifying `.defaultTap` event tap, preserves required Accessibility and Microphone flows, removes invalid entitlement declarations, and keeps existing dictation/trigger behavior intact.

## 4. Active Invariants
- **INV-001:** Global keyboard/mouse trigger capture must continue to use a modifying event tap so matched trigger events can be consumed.
- **INV-002:** Accessibility remains required for global trigger capture and Accessibility-based output insertion.
- **INV-003:** Microphone permission remains required for audio capture.
- **INV-004:** Local-only transcription and unrelated dictation behavior must not change.
- **INV-005:** Existing macOS 14+ support must remain intact.

## 5. Verified Working Behavior
- **VRF-001:** All changed Swift files parse with the installed Swift 6.2.4 toolchain.
- **VRF-002:** Focused permission, onboarding, metadata, linker, and experimental-UI suites pass: 32 tests, 0 failures.
- **VRF-003:** `swift build` and `swift build -c release` pass on macOS 26.6.2 / Xcode 26.3.
- **VRF-004:** Full `swift test` passes: 708 tests executed, 11 skipped, 0 failures.
- **VRF-005:** Codex CLI 0.147.0 found no actionable correctness defects in the complete branch diff and independently reproduced the full green test result.
- **VRF-006:** The legacy `inputMonitoringSettingsURL` compatibility API redirects to Accessibility, covered by a behavioral unit test.

## 6. Known Not Working
- **BRK-001:** On macOS 27 Golden Gate, the current v1.8 permission flow can enter a repeated reopen loop while configuring permissions.

## 7. Implemented but Unverified
- **UNV-001:** Golden Gate permission repair implemented on `fix/golden-gate-permission-flow`: standalone Input Monitoring request/gate removed; modifying event-tap behavior preserved under Accessibility; microphone flow preserved.
- **UNV-002:** Active onboarding, banners, diagnostics, state-first UI, help, entitlements, and regression tests were updated to the two-permission contract.
- **UNV-003:** Draft PR #7 contains the repair. Exact-head run 35801408725 passed the complete `build-and-test` job; its lint job remains failed on the pre-existing repository-wide baseline debt.
- **UNV-004:** Capability probing is throttled so the real active event-tap check does not run on every 2-second TCC poll.
- **UNV-005:** README now explicitly warns that packaged v1.8.0 predates the Golden Gate permission correction.

## 8. Unknown or Evidence-Stale State
- **UNK-001:** Exact Golden Gate runtime result after repair is unverified until a Golden Gate Mac can run the built app.
- **UNK-002:** Signing/notarization behavior of a future packaged hotfix is unverified until packaging is executed.
- **UNK-004:** Apple has an open Golden Gate/Sequoia/Tahoe report for system-wide input hangs when Accessibility is revoked while an active `.defaultTap` exists; applicability to DexDictate after this repair remains unverified.

## 9. Pending Work
- **PND-002:** Repair the repository-wide SwiftLint baseline separately on `main`; it is pre-existing debt and not part of this Golden Gate compatibility diff.
- **PND-003:** Run final packaged app on Golden Gate and verify first-launch permission journey.

## 10. Active Decisions, Defaults, and Prohibitions
- **DEC-001:** Do not require or proactively request standalone Input Monitoring for DexDictate's modifying event tap.
- **DEC-002:** Do not change the event tap to `.listenOnly`; DexDictate intentionally consumes matched trigger events.
- **DEC-003:** Do not publish a release or claim Golden Gate runtime success without runtime evidence.

## 11. Validation and Evidence Matrix
| ID | Claim or behavior | State | Evidence | Validation method | Artifact/revision | Last checked | Recheck trigger |
|---|---|---|---|---|---|---|---|
| BRK-001 | Golden Gate reopen loop exists | known-broken | user-observed runtime | reproduce on Golden Gate | v1.8.0 | 2026-09-22 | repaired build |
| INV-001 | modifying event tap remains | source-verified | `InputMonitor.swift` and trigger probe use `.defaultTap` | source + focused/full tests | `fe9fa069` | 2026-09-22 | event-tap change |
| UNK-001 | repaired app works on Golden Gate | NOT TESTED | no Golden Gate machine available | installed-app manual smoke test | `fix/golden-gate-permission-flow` | 2026-09-22 | Golden Gate machine available |
| UNV-001 | standalone Input Monitoring removed from required runtime path | source-verified | branch diff, entitlement audit, focused/full tests, Codex review | local validation + latest-head CI pending | `fe9fa069` | 2026-09-22 | permission code change |
| VRF-004 | full test suite | passed | 708 executed, 11 skipped, 0 failures | `swift test` | `fe9fa069` | 2026-09-22 | source change |
| CI-001 | PR #7 run 35801408725 build/test | passed | checkout, model cache/fetch, package resolution, debug build, release build, and full tests all passed | GitHub Actions | `f7fb4778` | 2026-09-22 | source change |
| CI-002 | strict SwiftLint | pre-existing base debt | Golden Gate: 166 violations; exact base `7cb7392`: 172; repository gate self-test passes | pinned SwiftLint 0.65.0 branch/base comparison | `fe9fa069` | 2026-09-22 | lint policy/baseline repair |
| VER-001 | VerificationRunner | pre-existing policy failure | 61/62 pass; unchanged runner reports stale online-networking policy; Golden Gate adds no networking source | isolated `swift run VerificationRunner` + diff audit | `fe9fa069` | 2026-09-22 | verifier policy repair lands on main |

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


### Revision 5 — 2026-09-22

- **Validated source head:** `fe9fa069125159d774e14c11fe3eb7bc0264b64d` on `fix/golden-gate-permission-flow`; the final operational-state commit follows this validated repair commit.
- **Confirmed branch defect fixed:** PR run 35796159043 exposed a stale test that expected the legacy Input Monitoring settings URL. The compatibility API intentionally redirects to Accessibility; the test now asserts that contract. A changed-line SwiftLint fingerprint was also normalized.
- **Build/test evidence:** changed-file parse passed; focused suites passed 32/32; debug and release builds passed; full suite passed 708 executed, 11 skipped, 0 failures.
- **CI classification:** the prior build/test failure was introduced by this branch and is fixed locally. Strict SwiftLint remains a pre-existing base failure: Golden Gate reports 166 violations versus 172 on exact base `7cb739208ea11af6e20beccd9907affbe4500444`; the repository's SwiftLint gate self-test passes.
- **VerificationRunner classification:** 61/62 checks pass. The unchanged runner's online-networking policy is stale on the exact base and outside Golden Gate scope; no Golden Gate source diff adds networking APIs.
- **Adversarial review:** Codex CLI 0.147.0 reported no actionable correctness defects in the changed permission flow and independently reran all 708 tests successfully.
- **README/release status:** README correctly states that v1.8.0 predates this correction. No packaged replacement was produced.
- **Golden Gate runtime:** **NOT TESTED**. The available machine runs macOS 26.6.2, not macOS 27 Golden Gate. No runtime compatibility claim is made.
- **Exact-head CI:** PR run 35801408725 passed `build-and-test` at `f7fb4778a48cd33ef04d8593bfaccb3c601797c1`; lint remained failed on the separately classified pre-existing baseline debt.
