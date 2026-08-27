# DexDictate Audio Hardening — Phase 0 Mac Baseline

## Executor

Codex running on the Mac that contains the intended `westkitty/DexDictate_MacOS` checkout.

## Objective

Establish the current Mac build/test baseline **without changing application source, replacing the installed app, changing permissions/audio routes, upgrading dependencies, or disturbing the user's DexDictate preferences**.

The governing current-state file is `OPERATIONAL_STATE.md`. Read it before doing anything beyond the identity checks below.

## Expected remote baseline

- Repository: `westkitty/DexDictate_MacOS`
- `origin/main`: `7cb739208ea11af6e20beccd9907affbe4500444`
- Work branch: `work/dexdictate-audio-hardening`
- Work branch contains the operational-state bootstrap commit descended from that `main` baseline.

If `origin/main` is no longer exactly the expected SHA, **STOP** after the read-only report. Do not rebase, merge, reset, or reinterpret the baseline.

## Protected constraints

Do not:

- edit application/test/build source during Phase 0;
- run `./build.sh --user`, `./build.sh --system`, or `./build.sh --release`;
- run `scripts/fetch_model.sh`;
- run `./scripts/verify_audio_route_recovery.sh` (it archives/truncates the user's real DexDictate debug log);
- run `swift package update` or alter `Package.swift` / `Package.resolved`;
- reset or change TCC permissions;
- launch/quit/kill DexDictate, Zoom, browser media, or other user apps;
- change system/default audio devices;
- stash, discard, overwrite, or reset pre-existing local work;
- use force push or write to `main`;
- claim live-microphone or installed-app behavior was verified in this phase.

Derived `.build` output from Swift build/test commands is allowed. Network access required by SwiftPM to obtain the **already declared and resolved** dependencies is allowed; dependency versions must not be changed.

## Step 1 — Environment fingerprint and stop gates

From the intended local checkout, run and record:

```bash
pwd
whoami
hostname
git rev-parse --show-toplevel
git remote get-url origin
git branch --show-current
git status --porcelain=v1
git rev-parse HEAD
git log -1 --oneline --decorate
uname -m
sw_vers
swift --version
```

Stop immediately if any of these are true:

1. repository root is not the intended DexDictate checkout;
2. `origin` is not the `westkitty/DexDictate_MacOS` repository;
3. `git status --porcelain=v1` is non-empty;
4. architecture is not native Apple Silicon (`arm64`).

Do not clean or stash a dirty checkout.

## Step 2 — Refresh remote identity only

If Step 1 passes:

```bash
git fetch origin main work/dexdictate-audio-hardening
git rev-parse origin/main
git rev-parse origin/work/dexdictate-audio-hardening
```

Hard gate:

```text
origin/main MUST equal 7cb739208ea11af6e20beccd9907affbe4500444
```

If it differs, stop and report the observed SHA. Do not switch branches.

## Step 3 — Enter the dedicated work branch

If a local `work/dexdictate-audio-hardening` branch already exists, switch to it only if it is clean and its relationship to the remote is non-divergent.

Otherwise create the local tracking branch from the fetched remote branch.

Equivalent safe commands are:

```bash
if git show-ref --verify --quiet refs/heads/work/dexdictate-audio-hardening; then
  git switch work/dexdictate-audio-hardening
else
  git switch --track -c work/dexdictate-audio-hardening origin/work/dexdictate-audio-hardening
fi

git status --porcelain=v1
git rev-parse HEAD
git merge-base --is-ancestor origin/work/dexdictate-audio-hardening HEAD
git merge-base --is-ancestor HEAD origin/work/dexdictate-audio-hardening
```

If the two ancestor checks indicate divergence rather than equality/fast-forward relationship, stop. Do not merge or rebase.

Read before testing:

```text
OPERATIONAL_STATE.md
docs/DEXDICTATE_BIBLE.md
Package.swift
Package.resolved
scripts/verify_audio_route_recovery.sh
```

Confirm the resolved dependency identities in the report:

- FluidAudio `0.15.4`, revision `b9d43724cbdb5a980e441fd54180964e94d470f7`
- Moonshine `0.0.65`, revision `5e2df68804cbcb4001984eeca200f3205ddaab3d`
- SwiftWhisper revision `deb1cb6a27256c7b01f5d3d2e7dc1dcc330b5d01`

If they differ, stop before testing and report the discrepancy.

## Step 4 — Build baseline

Run:

```bash
swift build
```

Record PASS/FAIL and the earliest meaningful error if it fails. Do not attempt a repair in Phase 0.

## Step 5 — Test baseline with isolated Foundation preferences

Create an isolated Foundation home so test/VerificationRunner use cannot rewrite the user's real DexDictate preferences:

```bash
PHASE0_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dexdictate-phase0.XXXXXX")"
printf 'PHASE0_HOME=%s\n' "$PHASE0_HOME"
```

Keep the directory for evidence until the phase ends; do not point it at the real home directory.

Run the complete test suite:

```bash
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test
```

Record:

- overall PASS/FAIL;
- total executed test count;
- failures;
- skips;
- earliest meaningful failure if nonzero.

Do not repair failures in this phase.

## Step 6 — Focused audio/live regression baseline

Run each independently using the same isolated Foundation home:

```bash
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioDeviceManagerTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioInputSelectionPolicyTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioRecorderRecoveryPlannerTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioRecorderRecoveryFailureTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter EngineLifecycleStateMachineTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioTapInstallerTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter AudioRecorderTapStateTests
env CFFIXED_USER_HOME="$PHASE0_HOME" swift test --filter LivePreviewInvariantTests
```

The last two audio-tap suites are intentional additions to the old route-recovery script's test list because they protect the later `InstallTapOnNode` crash repair.

For each command report PASS / FAIL / SKIP and the first meaningful failure line if any.

Do **not** run the real cached-Nemotron microphone/model path under the user's real home in Phase 0. That belongs to the live-transcription proof phase.

## Step 7 — VerificationRunner, isolated only

Plain `swift run VerificationRunner` is forbidden here because it calls `AppSettings.restoreDefaults()` and can mutate standard preferences. Run it only with the isolated Foundation home:

```bash
env CFFIXED_USER_HOME="$PHASE0_HOME" swift run VerificationRunner
```

Record its `Checks`, `Failures`, and `Result` lines. If it fails, record the first `FAIL [...]` line. Do not repair it.

## Step 8 — Prove Phase 0 did not touch tracked source

Run:

```bash
git status --porcelain=v1
git diff --check
git diff -- Package.swift Package.resolved Sources Tests scripts build.sh
```

Before creating the report, the last diff command must be empty. If tracked implementation files changed for any reason, stop and report; do not discard them automatically.

## Step 9 — Write one compact evidence report

Create exactly:

```text
docs/audio_hardening/phase_0_baseline_report.md
```

The report must contain:

```markdown
# Phase 0 Baseline Report

- Timestamp:
- Host:
- macOS:
- Architecture:
- Swift:
- Repository root:
- Work branch HEAD:
- origin/main:
- Working tree before tests: clean/dirty
- Dependency pins: match/mismatch

## Build
- swift build: PASS/FAIL

## Full suite
- swift test: PASS/FAIL
- Executed:
- Failures:
- Skips:

## Focused regressions
- AudioDeviceManagerTests:
- AudioInputSelectionPolicyTests:
- AudioRecorderRecoveryPlannerTests:
- AudioRecorderRecoveryFailureTests:
- EngineLifecycleStateMachineTests:
- AudioTapInstallerTests:
- AudioRecorderTapStateTests:
- LivePreviewInvariantTests:

## VerificationRunner
- Result:
- Checks:
- Failures:

## Evidence boundary
- Installed DexDictate app replaced: NO
- Real microphone tested: NO
- Bluetooth/Zoom route churn tested: NO
- TCC changed: NO
- User DexDictate preferences intentionally changed: NO
- Application source edited: NO

## Earliest unresolved failure
- None / exact command and concise first meaningful error

## Phase 0 verdict
- PASS / BLOCKED
```

Do not paste giant raw logs into the report. Include only evidence necessary to identify a failure.

## Step 10 — Publish baseline evidence only

If and only if:

- the checkout was clean at entry;
- remote baseline matched;
- tracked implementation files remain untouched;
- the only intended new tracked file is `docs/audio_hardening/phase_0_baseline_report.md`;

then commit and push **only that report** to the dedicated branch:

```bash
git add docs/audio_hardening/phase_0_baseline_report.md
git diff --cached --name-only
git diff --cached --check
git commit -m "docs(audio-hardening): record phase 0 Mac baseline"
git push origin work/dexdictate-audio-hardening
```

Immediately before `git commit`, `git diff --cached --name-only` must list exactly one path:

```text
docs/audio_hardening/phase_0_baseline_report.md
```

If not, unstage only the files Codex itself staged and stop. Never reset, discard, stash, or overwrite pre-existing work.

No force push. No PR. No merge. No `main` mutation.

## Completion rule

Phase 0 is complete only when the report exists on `work/dexdictate-audio-hardening` and contains current Mac evidence.

- A build/test failure does **not** authorize repair in this packet; it produces a `BLOCKED` Phase 0 report with the earliest failure.
- A skipped environment-dependent test is evidence, not permission to fabricate a pass.
- Do not begin live-transcription instrumentation, AUHAL, route-churn testing, UI changes, or refactoring in this packet.

## Final response

Return only:

1. Phase 0 verdict (`PASS` or `BLOCKED`)
2. branch HEAD after the evidence commit, if committed
3. build result
4. full-suite executed/failure/skip counts
5. focused-test summary
6. VerificationRunner result
7. earliest unresolved failure, if any
8. confirmation that no application source, installed app, TCC, audio route, or real user preferences were intentionally changed
