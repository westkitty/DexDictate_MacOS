# DexDictate Operational State

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "dexdictate-macos",
  "project_name": "DexDictate macOS",
  "project_root": ".",
  "artifact_path": "",
  "state_revision": 1,
  "last_updated": "2026-08-27T10:41:00Z",
  "current_baseline": {
    "identity": "GitHub main commit 7cb739208ea11af6e20beccd9907affbe4500444",
    "state": "current-baseline",
    "last_verified": null
  },
  "scope_boundaries": [
    "DexDictate macOS audio capture, route recovery, live transcription, and directly impacted regression paths",
    "No unrelated cleanup, dependency upgrades, or output-pipeline redesign"
  ],
  "linked_parent_state": null
}
-->

## 1. Project Identity and Scope

DexDictate is a native macOS SwiftPM menu-bar dictation application. This state file governs the bounded audio-hardening campaign: current microphone capture, route recovery, live provisional captions, and the regression surface directly affected by those changes. `docs/DEXDICTATE_BIBLE.md` remains the durable project history and design reference; this file is the current evidence/control plane and must not silently supersede explicit Bible rules.

## 2. Current Baseline

<!-- operational-state:entry
{
  "id": "BASE-001",
  "title": "Current GitHub baseline",
  "state": "current-baseline",
  "artifact_revision": "7cb739208ea11af6e20beccd9907affbe4500444",
  "evidence": "GitHub main observed 2026-08-27; only main branch existed before this work branch and no open PRs were present.",
  "verification_method": "Repository metadata only; Mac build/runtime proof still required.",
  "freshness": "current repository observation",
  "recheck_trigger": "Any movement of origin/main or local Mac checkout before implementation"
}
-->
### BASE-001 — Current GitHub baseline

- **State:** `current-baseline`
- **Artifact revision:** `7cb739208ea11af6e20beccd9907affbe4500444`
- **Evidence:** GitHub `main` observed on 2026-08-27. Before this campaign branch was created, `main` was the only branch and there were no open PRs.
- **Verification method:** Repository metadata only. Mac build/runtime proof is still required.
- **Recheck trigger:** Any movement of `origin/main` or the local Mac checkout before implementation.
<!-- /operational-state:entry -->

## 3. Artifact Contract

The target result is a DexDictate build that preserves the user's selected microphone through hostile macOS route changes, cannot crash or wedge on audio route/tap lifecycle changes, displays recognizable provisional transcription while the user is still speaking when a healthy streaming provider is available, and continues to use the trusted final transcription/output pipeline for committed text.

## 4. Active Invariants

<!-- operational-state:entry
{
  "id": "INV-001",
  "title": "Preferred microphone fidelity",
  "state": "requested",
  "rule": "When an explicitly selected microphone remains available and usable, Bluetooth/output churn or system-default changes must not silently move DexDictate to another input.",
  "scope": "Audio capture and route recovery",
  "authority": "Current hardening contract",
  "evidence": "Explicit project requirement and existing route-recovery policy",
  "validation_method": "Installed-app route-churn run plus UID-level diagnostics",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any capture, device-selection, route-recovery, sleep/wake, or backend change"
}
-->
### INV-001 — Preferred microphone fidelity
- **State:** `requested`
- **Rule:** When an explicitly selected microphone remains available and usable, Bluetooth/output churn or system-default changes must not silently move DexDictate to another input.
- **Validation:** Installed-app route-churn run plus UID-level diagnostics.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-002",
  "title": "No system-default mutation",
  "state": "requested",
  "rule": "DexDictate may bind its own input route but must not change the user's macOS system-wide input or output defaults.",
  "scope": "Audio device selection",
  "authority": "Current hardening contract",
  "evidence": "Explicit project requirement",
  "validation_method": "Compare system defaults before/during/after device-selection and route-churn tests",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any device-selection or capture-backend change"
}
-->
### INV-002 — No system-default mutation
- **State:** `requested`
- **Rule:** DexDictate may bind its own input route but must not change the user's macOS system-wide input or output defaults.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-003",
  "title": "Route changes cannot crash or wedge capture",
  "state": "requested",
  "rule": "Audio route/tap lifecycle changes must not cause SIGABRT, uncaught Objective-C exceptions, a dead capture engine, or a permanently stuck recording/processing state.",
  "scope": "Audio capture lifecycle",
  "authority": "Current hardening contract plus prior InstallTapOnNode crash evidence",
  "evidence": "Existing Objective-C tap bridge and regression tests exist in the repository",
  "validation_method": "Targeted tap tests, route-recovery tests, installed-app Bluetooth/Zoom churn, and crash/log sweep",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any tap, engine, route recovery, backend, or lifecycle change"
}
-->
### INV-003 — Route changes cannot crash or wedge capture
- **State:** `requested`
- **Rule:** Audio route/tap lifecycle changes must not cause `SIGABRT`, uncaught Objective-C exceptions, a dead capture engine, or a permanently stuck recording/processing state.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-004",
  "title": "Captured speech survives recoverable route churn",
  "state": "requested",
  "rule": "Audio captured before a recoverable route event must remain available to the final utterance instead of being silently discarded during recovery.",
  "scope": "Audio accumulation and route recovery",
  "authority": "Current hardening contract",
  "evidence": "Existing recovery code has preserveBufferedAudio behavior; runtime proof is stale/unavailable",
  "validation_method": "Deterministic buffer-preservation test plus real mid-utterance route churn",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any capture-buffer, teardown, recovery, or backend change"
}
-->
### INV-004 — Captured speech survives recoverable route churn
- **State:** `requested`
- **Rule:** Audio captured before a recoverable route event must remain available to the final utterance instead of being silently discarded during recovery.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-005",
  "title": "Live captions are provisional only",
  "state": "requested",
  "rule": "Streaming partials may update display state while listening but must never independently paste, enter history, run commands, trigger cleanup, or become authoritative committed output.",
  "scope": "Live transcription and output pipeline",
  "authority": "Current hardening contract and existing provider architecture",
  "evidence": "Current source separates streaming preview from committed final transcription; runtime recheck required after changes",
  "validation_method": "Live-preview invariant tests plus installed-app dictation/output checks",
  "last_checked": "source-inspected 2026-08-27; runtime unverified",
  "status": "active",
  "recheck_trigger": "Any TranscriptionEngine, provider, preview, output, history, command, or cleanup change"
}
-->
### INV-005 — Live captions are provisional only
- **State:** `requested`
- **Rule:** Streaming partials may update display state while listening but must never independently paste, enter history, run commands, trigger cleanup, or become authoritative committed output.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-006",
  "title": "Recognizable live text must appear before release",
  "state": "requested",
  "rule": "With Live Transcription enabled and a healthy streaming provider, recognizable ASR text must become visible while the user is still speaking, before trigger release.",
  "scope": "Installed-app live transcription user path",
  "authority": "Explicit project goal",
  "evidence": "Current source and provider tests implement the path, but installed-app proof on current baseline is missing",
  "validation_method": "Real microphone installed-app run with session diagnostics and a distinctive spoken sentence",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any capture, provider, session, preview, UI, or state-management change"
}
-->
### INV-006 — Recognizable live text must appear before release
- **State:** `requested`
- **Rule:** With Live Transcription enabled and a healthy streaming provider, recognizable ASR text must become visible while the user is still speaking, before trigger release.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-007",
  "title": "Final transcription remains authoritative and resilient",
  "state": "requested",
  "rule": "Stopping live transcription must hand off to the existing final transcription/output path; late streaming callbacks cannot overwrite final state, and a live-provider failure cannot prevent final dictation from completing.",
  "scope": "Streaming/final handoff",
  "authority": "Current hardening contract",
  "evidence": "Current source has provider session-generation guards and final-only committed architecture; current installed path not yet proven",
  "validation_method": "Session-race tests, provider-failure tests, and installed-app finalization check",
  "last_checked": "source-inspected 2026-08-27; runtime unverified",
  "status": "active",
  "recheck_trigger": "Any provider lifecycle, TranscriptionEngine, finalization, or output change"
}
-->
### INV-007 — Final transcription remains authoritative and resilient
- **State:** `requested`
- **Rule:** Stopping live transcription must hand off to the existing final transcription/output path; late streaming callbacks cannot overwrite final state, and a live-provider failure cannot prevent final dictation from completing.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "INV-008",
  "title": "Existing non-audio dictation behavior is protected",
  "state": "requested",
  "rule": "Audio hardening must preserve hold/toggle triggering, permission behavior, vocabulary and commands, history, Auto-paste, selected-text replacement, clipboard restoration, Undo Last Dictation, secure/browser behavior, and Smart Cleanup behavior.",
  "scope": "Regression surface directly adjacent to dictation completion",
  "authority": "Current hardening contract and project history",
  "evidence": "Existing source/tests/documentation; current full-suite baseline still required",
  "validation_method": "Current full test suite before and after plus focused installed-app regression checks where runtime behavior is involved",
  "last_checked": "not yet on current baseline",
  "status": "active",
  "recheck_trigger": "Any TranscriptionEngine, output coordinator, insertion, undo, command, vocabulary, history, or trigger change"
}
-->
### INV-008 — Existing non-audio dictation behavior is protected
- **State:** `requested`
- **Rule:** Audio hardening must preserve hold/toggle triggering, permission behavior, vocabulary and commands, history, Auto-paste, selected-text replacement, clipboard restoration, Undo Last Dictation, secure/browser behavior, and Smart Cleanup behavior.
<!-- /operational-state:entry -->

## 5. Verified Working Behavior

No current-baseline user-path behavior is promoted to `verified` yet. Historical tests and source presence remain evidence, not current runtime proof.

## 6. Known Not Working

No current-baseline failure is marked proven until the Mac baseline is run. Prior live-caption and AVAudioEngine tap failures remain relevant historical evidence in the project Bible and bug-fix docs.

## 7. Implemented but Unverified

<!-- operational-state:entry
{
  "id": "UNV-001",
  "title": "Streaming live-caption pipeline exists in source",
  "state": "implemented-unverified",
  "capability": "TranscriptionEngine resolves Nemotron or Apple Speech for live streaming, forwards recorder buffers, and publishes partial text to liveTranscript while keeping committed output separate.",
  "evidence": "Current source inspection at commit 7cb739208ea11af6e20beccd9907affbe4500444",
  "missing_evidence": "Installed current-baseline microphone-to-visible-caption proof",
  "recheck_trigger": "Phase 0 Mac baseline and Phase 2 live-path run"
}
-->
### UNV-001 — Streaming live-caption pipeline exists in source
- **State:** `implemented-unverified`
- **Capability:** The current source resolves Nemotron or Apple Speech for live streaming, forwards recorder buffers, and publishes partial text to `liveTranscript` while keeping committed output separate.
- **Missing evidence:** Installed current-baseline microphone-to-visible-caption proof.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "UNV-002",
  "title": "AVAudioEngine crash guards exist in source",
  "state": "implemented-unverified",
  "capability": "The recorder serializes engine work, guards overlapping recovery/start operations, tracks tap state, and routes tap install/remove through an Objective-C exception bridge.",
  "evidence": "Current AudioRecorderService source plus AudioTapInstallerTests and AudioRecorderTapStateTests present at baseline commit",
  "missing_evidence": "Current test execution and hostile installed-app route-churn proof",
  "recheck_trigger": "Phase 0 Mac tests and later route-churn run"
}
-->
### UNV-002 — AVAudioEngine crash guards exist in source
- **State:** `implemented-unverified`
- **Capability:** The recorder serializes engine work, guards overlapping recovery/start operations, tracks tap state, and routes tap install/remove through an Objective-C exception bridge.
- **Missing evidence:** Current test execution and hostile installed-app route-churn proof.
<!-- /operational-state:entry -->

## 8. Unknown or Evidence-Stale State

<!-- operational-state:entry
{
  "id": "UNK-001",
  "title": "Current build and test baseline",
  "state": "unknown",
  "unknown": "The current HEAD has no GitHub CI run and this ChatGPT environment is not the user's Mac; the actual current build result, test count, skips, and failures are therefore unknown.",
  "decisive_check": "Run the bounded Phase 0 Mac baseline without editing source or replacing the installed app.",
  "status": "blocking implementation"
}
-->
### UNK-001 — Current build and test baseline
- **State:** `unknown`
- **Unknown:** Current build result, test count, skips, and failures.
- **Decisive check:** Run the bounded Phase 0 Mac baseline without editing source or replacing the installed app.
<!-- /operational-state:entry -->

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
- **Unknown:** Current installed-app microphone-to-visible-caption behavior.
- **Decisive check:** Phase 2 installed-app microphone run with provider/capture/UI boundary diagnostics.
<!-- /operational-state:entry -->

## 9. Pending Work

<!-- operational-state:entry
{
  "id": "PND-001",
  "title": "Run Phase 0 Mac baseline",
  "state": "pending",
  "task": "Verify exact local repository identity, current remote/local commit relationship, dependency resolution, toolchain, current full test suite, focused audio/live regression tests, and VerificationRunner on the Mac without source edits or installed-app replacement.",
  "reason_pending": "Requires the user's macOS runtime and audio-capable project checkout.",
  "dependency": "Clean intended DexDictate checkout",
  "priority": "highest",
  "validation_needed": "Evidence report committed back to this branch",
  "blocks_completion": true
}
-->
### PND-001 — Run Phase 0 Mac baseline
- **State:** `pending`
- **Task:** Verify the exact local checkout, dependency resolution, toolchain, current full suite, focused audio/live regressions, and `VerificationRunner` without source edits or installed-app replacement.
- **Blocks implementation:** Yes.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "PND-002",
  "title": "Prove and repair live transcription on existing AVAudioEngine path",
  "state": "pending",
  "task": "Instrument and prove the real microphone-to-provider-to-liveTranscript-to-UI path before any AUHAL backend work.",
  "reason_pending": "Phase 0 baseline must establish current failures first.",
  "dependency": "PND-001",
  "priority": "high",
  "validation_needed": "Recognizable live text visible before trigger release in an installed build",
  "blocks_completion": true
}
-->
### PND-002 — Prove and repair live transcription on existing AVAudioEngine path
- **State:** `pending`
- **Task:** Instrument and prove the real microphone → provider → `liveTranscript` → UI path before any AUHAL work.
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
- **Rule:** Nemotron and Apple Speech remain provisional live-caption providers during this campaign; they do not become authoritative committed-output engines.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "DEC-002",
  "title": "Freeze transcription dependencies during diagnosis",
  "state": "requested",
  "rule": "Do not upgrade SwiftWhisper, FluidAudio, Moonshine, or unrelated dependencies during the live/audio hardening experiment unless existing pinned dependencies are proven to block the work.",
  "authority": "Change-isolation requirement",
  "status": "active"
}
-->
### DEC-002 — Freeze transcription dependencies during diagnosis
- **State:** `requested`
- **Rule:** Do not upgrade SwiftWhisper, FluidAudio, Moonshine, or unrelated dependencies during this diagnosis/hardening campaign unless the pinned dependency is proven to block the work.
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "DEC-003",
  "title": "Do not replace installed app during Phase 0",
  "state": "requested",
  "rule": "Phase 0 may build/test derived artifacts but must not run build.sh --user/--system, overwrite an installed DexDictate.app, reset TCC, kill unrelated apps, change audio routes, or edit tracked source files.",
  "authority": "Baseline integrity requirement",
  "evidence": "build.sh explicitly stops/replaces the target installed app and runs model bootstrap",
  "status": "active"
}
-->
### DEC-003 — Do not replace installed app during Phase 0
- **State:** `requested`
- **Rule:** Phase 0 may build/test derived artifacts but must not run `build.sh --user`/`--system`, overwrite an installed app, reset TCC, kill unrelated apps, change audio routes, or edit tracked source files.
<!-- /operational-state:entry -->

## 11. Validation and Evidence Matrix

| ID | Claim | Current state | Required evidence | Recheck trigger |
|---|---|---|---|---|
| BASE-001 | Current GitHub baseline is `7cb7392` | current-baseline | Compare local HEAD and `origin/main` on Mac | Any remote/local movement |
| INV-001 | Preferred mic survives route churn | requested | Installed-app UID-level route-churn proof | Capture/device/recovery changes |
| INV-003 | Route/tap changes do not crash or wedge | requested | Focused tests + hostile runtime churn | Tap/engine/backend changes |
| INV-005 | Live partials never become committed output | requested | Invariant tests + output-path runtime check | Provider/engine/output changes |
| INV-006 | Recognizable live text appears before release | requested | Installed microphone user-path proof | Capture/provider/UI changes |
| INV-007 | Final path survives live-provider failure/stale callback | requested | Race/failure tests + runtime check | Provider/finalization changes |
| INV-008 | Existing dictation behavior remains intact | requested | Full current suite + affected runtime checks | Broad engine/output changes |
| UNK-001 | Current build/test state | unknown | Phase 0 Mac report | Any commit/toolchain change |
| UNK-002 | Current installed live-caption state | unknown | Phase 2 installed-app run | Any live-path change |

## 12. Current Change Scope and Impact Radius

Current scope is **Phase 0/1 only**: baseline capture, evidence classification, invariant lock, and preparing the first Mac execution packet. No application source change or installed-app replacement is authorized until the current Mac baseline is captured. The first implementation impact radius will be live transcription session/capture bridging and diagnostics; AUHAL remains deferred until live transcription is proven or repaired on the existing AVAudioEngine path.

## 13. Compact Revision Log

- **Revision 1 — 2026-08-27:** Initialized the audio-hardening operational state from current GitHub evidence and the accepted implementation plan. GitHub baseline is recorded as current but runtime-unverified; live captions and current test/build state remain explicitly unverified/unknown pending the Mac baseline.
