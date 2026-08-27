# DexDictate Operational State

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "dexdictate-macos",
  "project_name": "DexDictate macOS",
  "project_root": ".",
  "artifact_path": "",
  "state_revision": 3,
  "last_updated": "2026-08-27T11:44:24Z",
  "current_baseline": {
    "identity": "work branch cba14314e443f9ddc33c601a988f3a78233c0c7a / application source equivalent to origin/main 7cb739208ea11af6e20beccd9907affbe4500444",
    "state": "partially-verified",
    "last_verified": "2026-08-27T11:16:47Z"
  },
  "scope_boundaries": [
    "DexDictate macOS audio capture, route recovery, live transcription, verification policy, and directly impacted regression paths",
    "No unrelated cleanup, dependency upgrades, or output-pipeline redesign"
  ],
  "linked_parent_state": null
}
-->

## 1. Project Identity and Scope

DexDictate is a native macOS SwiftPM menu-bar dictation application. This state file governs the bounded audio-hardening campaign: source baseline integrity, current microphone capture, route recovery, live provisional captions, verification policy, and directly affected regressions. `docs/DEXDICTATE_BIBLE.md` remains the durable project history/design reference; this file is the current evidence/control plane.

## 2. Current Baseline

<!-- operational-state:entry
{
  "id": "BASE-001",
  "title": "Phase 0 Mac source baseline",
  "state": "partially-verified",
  "artifact_revision": "cba14314e443f9ddc33c601a988f3a78233c0c7a; application source equivalent to origin/main 7cb739208ea11af6e20beccd9907affbe4500444",
  "evidence": "Phase 0 report dated 2026-08-27T11:16:47Z from MacBook-Air.local, macOS 26.6.2 arm64, Swift 6.2.4. swift build passed; swift test executed 707 with 0 failures and 11 skips; all listed focused audio/live regressions passed; dependencies matched pins. VerificationRunner ran 62 checks and failed only the blanket networking-source assertion.",
  "verification_method": "Read-only Mac build/test baseline; installed app, microphone, Bluetooth/Zoom churn, TCC, and user preferences were not changed or tested.",
  "freshness": "current Phase 0 evidence",
  "recheck_trigger": "Any application-source, dependency, Swift/macOS toolchain, or baseline branch change"
}
-->
### BASE-001 — Phase 0 Mac source baseline
- **State:** `partially-verified`
- **Revision:** `cba14314e443f9ddc33c601a988f3a78233c0c7a` with application source equivalent to `origin/main` `7cb739208ea11af6e20beccd9907affbe4500444`.
- **Verified:** build PASS; 707 tests passed, 11 skipped, 0 failed; focused audio/live regressions PASS; dependency pins match.
- **Not verified:** installed-app, microphone, Bluetooth/Zoom churn, TCC, and live-caption user path.
<!-- /operational-state:entry -->

## 3. Artifact Contract

The target result is a DexDictate build that preserves the selected microphone through hostile macOS route changes, cannot crash or wedge on audio route/tap lifecycle changes, displays recognizable provisional transcription while the user is still speaking when a healthy streaming provider is available, and continues to use the trusted final transcription/output pipeline for committed text.

## 4. Active Invariants

<!-- operational-state:entry
{
  "id": "INV-001",
  "title": "Preferred microphone fidelity",
  "state": "requested",
  "rule": "When an explicitly selected microphone remains available and usable, Bluetooth/output churn or system-default changes must not silently move DexDictate to another input.",
  "scope": "Audio capture and route recovery",
  "authority": "Current hardening contract",
  "validation_method": "Installed-app route-churn run plus UID-level diagnostics",
  "last_checked": "not runtime-tested in Phase 0",
  "status": "active",
  "recheck_trigger": "Any capture, device-selection, route-recovery, sleep/wake, or backend change"
}
-->
### INV-001 — Preferred microphone fidelity
- **State:** `requested`
- **Rule:** A valid explicitly selected microphone remains authoritative through unrelated output/default-route churn.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-002",
  "title": "No system-default mutation",
  "state": "requested",
  "rule": "DexDictate may bind its own input route but must not change the user's macOS system-wide input or output defaults.",
  "scope": "Audio device selection",
  "authority": "Current hardening contract",
  "validation_method": "Compare system defaults before/during/after route tests",
  "last_checked": "not runtime-tested in Phase 0",
  "status": "active",
  "recheck_trigger": "Any device-selection or capture-backend change"
}
-->
### INV-002 — No system-default mutation
- **State:** `requested`
- **Rule:** DexDictate owns its route, not macOS's global route.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-003",
  "title": "Route changes cannot crash or wedge capture",
  "state": "partially-verified",
  "rule": "Audio route/tap lifecycle changes must not cause SIGABRT, uncaught Objective-C exceptions, a dead capture engine, or a permanently stuck recording/processing state.",
  "scope": "Audio capture lifecycle",
  "authority": "Current hardening contract plus prior InstallTapOnNode crash evidence",
  "evidence": "Phase 0: AudioTapInstallerTests, AudioRecorderTapStateTests, recovery planner/failure tests, device policy tests, and lifecycle tests all passed.",
  "validation_method": "Focused automated tests plus installed-app Bluetooth/Zoom route churn and crash/log sweep",
  "last_checked": "2026-08-27 automated tests only",
  "status": "active",
  "recheck_trigger": "Any tap, engine, route recovery, backend, or lifecycle change"
}
-->
### INV-003 — Route changes cannot crash or wedge capture
- **State:** `partially-verified`
- **Evidence:** All Phase 0 focused tap/recovery/lifecycle tests passed; hostile installed-app route churn remains untested.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-004",
  "title": "Captured speech survives recoverable route churn",
  "state": "requested",
  "rule": "Audio captured before a recoverable route event must remain available to the final utterance instead of being silently discarded during recovery.",
  "scope": "Audio accumulation and route recovery",
  "authority": "Current hardening contract",
  "validation_method": "Deterministic preservation test plus real mid-utterance route churn",
  "last_checked": "not user-path-tested in Phase 0",
  "status": "active",
  "recheck_trigger": "Any capture-buffer, teardown, recovery, or backend change"
}
-->
### INV-004 — Captured speech survives recoverable route churn
- **State:** `requested`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-005",
  "title": "Live captions are provisional only",
  "state": "partially-verified",
  "rule": "Streaming partials may update display state while listening but must never independently paste, enter history, run commands, trigger cleanup, or become authoritative committed output.",
  "scope": "Live transcription and output pipeline",
  "authority": "Current hardening contract and existing provider architecture",
  "evidence": "Phase 0 LivePreviewInvariantTests passed; installed output-path runtime proof remains pending.",
  "validation_method": "Live-preview invariant tests plus installed-app dictation/output checks",
  "last_checked": "2026-08-27 automated tests only",
  "status": "active",
  "recheck_trigger": "Any TranscriptionEngine, provider, preview, output, history, command, or cleanup change"
}
-->
### INV-005 — Live captions are provisional only
- **State:** `partially-verified`
- **Evidence:** `LivePreviewInvariantTests` passed in Phase 0; runtime path remains pending.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-006",
  "title": "Recognizable live text must appear before release",
  "state": "requested",
  "rule": "With Live Transcription enabled and a healthy streaming provider, recognizable ASR text must become visible while the user is still speaking, before trigger release.",
  "scope": "Installed-app live transcription user path",
  "authority": "Explicit project goal",
  "validation_method": "Real microphone installed-app run with session diagnostics and a distinctive spoken sentence",
  "last_checked": "not tested in Phase 0 by design",
  "status": "active",
  "recheck_trigger": "Any capture, provider, session, preview, UI, or state-management change"
}
-->
### INV-006 — Recognizable live text must appear before release
- **State:** `requested`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-007",
  "title": "Final transcription remains authoritative and resilient",
  "state": "partially-verified",
  "rule": "Stopping live transcription must hand off to the existing final transcription/output path; late streaming callbacks cannot overwrite final state, and a live-provider failure cannot prevent final dictation from completing.",
  "scope": "Streaming/final handoff",
  "authority": "Current hardening contract",
  "evidence": "Phase 0 live preview regression suite passed; installed microphone/finalization race remains unverified.",
  "validation_method": "Session-race/failure tests plus installed-app finalization check",
  "last_checked": "2026-08-27 automated tests only",
  "status": "active",
  "recheck_trigger": "Any provider lifecycle, TranscriptionEngine, finalization, or output change"
}
-->
### INV-007 — Final transcription remains authoritative and resilient
- **State:** `partially-verified`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-008",
  "title": "Existing non-audio dictation behavior is protected",
  "state": "partially-verified",
  "rule": "Audio hardening must preserve hold/toggle triggering, permission behavior, vocabulary and commands, history, Auto-paste, selected-text replacement, clipboard restoration, Undo Last Dictation, secure/browser behavior, and Smart Cleanup behavior.",
  "scope": "Regression surface directly adjacent to dictation completion",
  "authority": "Current hardening contract and project history",
  "evidence": "Phase 0 full suite passed 707 tests with 0 failures; runtime-only user paths remain outside Phase 0.",
  "validation_method": "Full suite after changes plus affected installed-app checks",
  "last_checked": "2026-08-27 automated suite",
  "status": "active",
  "recheck_trigger": "Any TranscriptionEngine, output coordinator, insertion, undo, command, vocabulary, history, trigger, or Smart Cleanup change"
}
-->
### INV-008 — Existing non-audio dictation behavior is protected
- **State:** `partially-verified`
- **Evidence:** Full Phase 0 suite: 707 passed, 11 skipped, 0 failed.
<!-- /operational-state:entry -->

## 5. Verified Working Behavior

<!-- operational-state:entry
{
  "id": "VER-001",
  "title": "Current source builds and automated suite is green",
  "state": "verified",
  "capability": "The Phase 0 source baseline compiles and passes the full XCTest suite on the intended Mac environment.",
  "scope": "Source build and automated test baseline",
  "verification_method": "swift build and swift test on MacBook-Air.local",
  "evidence": "Build PASS; 707 executed tests passed, 0 failed, 11 skipped at 2026-08-27T11:16:47Z.",
  "artifact_revision": "cba14314e443f9ddc33c601a988f3a78233c0c7a",
  "last_verified": "2026-08-27T11:16:47Z",
  "dependencies": "Package pins matched Phase 0 contract",
  "freshness": "current",
  "recheck_trigger": "Any source, dependency, Swift toolchain, or macOS baseline change"
}
-->
### VER-001 — Current source builds and automated suite is green
- **State:** `verified`
- **Evidence:** `swift build` PASS; `swift test` 707 passed, 11 skipped, 0 failed.
<!-- /operational-state:entry -->

## 6. Known Not Working

<!-- operational-state:entry
{
  "id": "BRK-001",
  "title": "VerificationRunner blanket network assertion is obsolete",
  "state": "verified/resolved",
  "observed_failure": "VerificationRunner fails its black-path check 'no online networking APIs detected in Sources'.",
  "artifact_revision": "Phase 1 verifier repair on work/dexdictate-audio-hardening",
  "evidence": "Phase 1 VerificationRunner: 62 checks, 0 failures. The verifier now confines direct networking tokens to the three approved opt-in/download source files and a negative-control probe rejected an unapproved URLSession token. Full XCTest suite remained 707 executed, 0 failures, 11 skips.",
  "severity": "resolved as a verification-policy defect; does not by itself demonstrate a dictation privacy failure",
  "affected_user_path": "Verification policy only",
  "workaround": "None required after the Phase 1 verifier repair.",
  "required_repair": "Replace the blanket zero-network-token assertion with a narrow check that direct networking APIs in project Sources are confined to explicitly approved opt-in/download surfaces and absent elsewhere.",
  "required_validation": "Completed: VerificationRunner PASS plus full suite PASS; no application behavior changes.",
  "status": "resolved"
}
-->
### BRK-001 — VerificationRunner blanket network assertion is obsolete
- **State:** `verified/resolved`
- **Observed:** Phase 1 VerificationRunner passed 62 checks with 0 failures using the approved source-boundary rule.
- **Interpretation:** The obsolete whole-`Sources` assertion was replaced by an exact repository-relative allowlist with a negative-control guard.
<!-- /operational-state:entry -->

## 7. Implemented but Unverified

<!-- operational-state:entry
{
  "id": "UNV-001",
  "title": "Streaming live-caption pipeline exists in source",
  "state": "implemented-unverified",
  "capability": "TranscriptionEngine resolves Nemotron or Apple Speech for live streaming, forwards recorder buffers, and publishes partial text to liveTranscript while keeping committed output separate.",
  "evidence": "Current source plus passing LivePreviewInvariantTests",
  "missing_evidence": "Installed current-baseline microphone-to-visible-caption proof",
  "recheck_trigger": "Phase 2 live-path run"
}
-->
### UNV-001 — Streaming live-caption pipeline exists in source
- **State:** `implemented-unverified`
- **Missing evidence:** Installed microphone → visible live-caption proof.
<!-- /operational-state:entry -->

## 8. Unknown or Evidence-Stale State

<!-- operational-state:entry
{
  "id": "UNK-002",
  "title": "Current installed-app live-caption behavior",
  "state": "unknown",
  "unknown": "It is not yet proven whether the current installed build receives real microphone buffers through the selected streaming provider and visibly updates recognizable live text before release.",
  "decisive_check": "Phase 2 installed-app microphone run with provider/capture/UI boundary diagnostics.",
  "status": "blocks live-transcription completion"
}
-->
### UNK-002 — Current installed-app live-caption behavior
- **State:** `unknown`
<!-- /operational-state:entry -->

## 9. Pending Work

<!-- operational-state:entry
{
  "id": "PND-001",
  "title": "Repair VerificationRunner local-network boundary check",
  "state": "completed",
  "task": "Replace the obsolete whole-Sources zero-network-token assertion with an explicit allowlist/boundary check that still fails if a direct networking API appears in an unapproved source file.",
  "reason_pending": "Completed in Phase 1; the verifier now reports a clean baseline.",
  "dependency": "None",
  "priority": "highest",
  "validation_needed": "VerificationRunner PASS and full XCTest suite remains green",
  "blocks_completion": false,
  "completed_evidence": "Phase 1 report: VerificationRunner 62/0 and full XCTest suite 707/0/11."
}
-->
### PND-001 — Repair VerificationRunner local-network boundary check
- **State:** `pending`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "PND-002",
  "title": "Prove and repair live transcription on existing AVAudioEngine path",
  "state": "pending",
  "task": "Instrument and prove the real microphone-to-provider-to-liveTranscript-to-UI path before any AUHAL backend work.",
  "reason_pending": "Phase 1 verifier baseline is clean; installed live-transcription proof remains outstanding.",
  "dependency": "PND-001",
  "priority": "high",
  "validation_needed": "Recognizable live text visible before trigger release in an installed build",
  "blocks_completion": true
}
-->
### PND-002 — Prove and repair live transcription on existing AVAudioEngine path
- **State:** `pending`
<!-- /operational-state:entry -->

## 10. Active Decisions, Defaults, and Prohibitions

<!-- operational-state:entry
{
  "id": "DEC-001",
  "title": "Streaming remains provisional",
  "state": "requested",
  "rule": "Nemotron and Apple Speech provide provisional live captions only during this campaign; the trusted final transcription/output path remains authoritative for committed text.",
  "authority": "Current project plan",
  "status": "active"
}
-->
### DEC-001 — Streaming remains provisional
- **State:** `requested`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "DEC-002",
  "title": "Freeze dependencies during diagnosis",
  "state": "requested",
  "rule": "Do not upgrade SwiftWhisper, FluidAudio, Moonshine, or unrelated dependencies during the audio/live hardening campaign unless a pinned dependency is proven to block the work.",
  "authority": "Change-isolation requirement",
  "status": "active"
}
-->
### DEC-002 — Freeze dependencies during diagnosis
- **State:** `requested`
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "DEC-003",
  "title": "Direct network APIs require an explicit approved source boundary",
  "state": "requested",
  "rule": "Project-source direct networking APIs may exist only in explicit opt-in/post-processing or user-triggered model-download surfaces. Verification must fail if a direct networking API appears elsewhere; the normal microphone/transcription/final-output path must not gain an implicit network dependency.",
  "authority": "Local-dictation privacy boundary plus current intentional feature architecture",
  "status": "active"
}
-->
### DEC-003 — Direct network APIs require an explicit approved source boundary
- **State:** `requested`
- **Rule:** Networking is not globally forbidden, but it is forbidden from silently spreading into the normal dictation path.
<!-- /operational-state:entry -->

## 11. Validation and Evidence Matrix

| ID | Claim | Current state | Evidence / required proof | Recheck trigger |
|---|---|---|---|---|
| BASE-001 | Current source baseline | partially-verified | Mac build + 707/0/11 suite; runtime paths excluded | Source/toolchain change |
| INV-001 | Preferred mic survives route churn | requested | Installed-app UID-level route-churn proof | Capture/device/recovery changes |
| INV-003 | Route/tap lifecycle is safe | partially-verified | Focused tests pass; hostile runtime churn pending | Tap/engine/backend changes |
| INV-005 | Live partials remain display-only | partially-verified | LivePreviewInvariantTests pass; runtime output check pending | Provider/engine/output changes |
| INV-006 | Recognizable live text appears before release | requested | Installed microphone user-path proof | Capture/provider/UI changes |
| INV-007 | Final path survives live failure/stale callback | partially-verified | Automated regressions pass; installed finalization pending | Provider/finalization changes |
| INV-008 | Existing dictation behavior remains intact | partially-verified | Full suite 707/0/11; runtime-only behaviors pending | Broad engine/output changes |
| BRK-001 | VerificationRunner networking check | verified/resolved | Phase 1 verifier repair: 62/0 plus negative control | Verification-policy change |
| UNK-002 | Installed live-caption behavior | unknown | Phase 2 installed-app run | Any live-path change |

## 12. Current Change Scope and Impact Radius

Current scope is **Phase 1 verifier repair only**. Allowed implementation change: `Sources/VerificationRunner/main.swift` and narrowly necessary test/support code only if the existing runner cannot express the boundary safely. Application behavior, audio capture, providers, UI, dependencies, installed app, TCC, preferences, and audio routes remain untouched. After a clean verification baseline, Phase 2 owns live-transcription instrumentation and installed microphone proof on the existing AVAudioEngine path. AUHAL remains deferred.

## 13. Compact Revision Log

- **Revision 1 — 2026-08-27:** Initialized audio-hardening control state from GitHub baseline evidence.
- **Revision 2 — 2026-08-27:** Recorded Phase 0 Mac evidence: build PASS; full suite 707 passed / 11 skipped / 0 failed; focused regressions PASS. Classified the sole VerificationRunner failure as a stale blanket network-source assertion because intentional bounded network features now exist. Installed-app/live-microphone/route-churn state remains unverified.
- **Revision 3 — 2026-08-27:** Phase 1 repaired the verifier's exact approved networking boundary; VerificationRunner passed 62/0, the negative control rejected an unapproved token, and the full suite passed 707/0/11. BRK-001 resolved, PND-001 completed, and Phase 2 installed live-transcription proof remains the next active task.
