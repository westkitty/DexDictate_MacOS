# DexDictate Audio Hardening — Phase 1 Verification Policy Repair

## Executor

Codex on the same Mac/check-out used for Phase 0.

## Objective

Restore a truthful green verification baseline by repairing the **obsolete `VerificationRunner` whole-`Sources` zero-network-token assertion**, without changing DexDictate application behavior.

Phase 0 established:

- `swift build`: PASS
- full XCTest suite: 707 passed, 11 skipped, 0 failed
- focused audio/live regressions: PASS
- `VerificationRunner`: 62 checks, 1 failure
- only failing check: `FAIL [black] no online networking APIs detected in Sources`

The current project intentionally contains bounded direct networking in explicit/opt-in surfaces. The verifier must detect **networking escaping those approved surfaces**, not pretend no direct networking exists anywhere in `Sources`.

Read `OPERATIONAL_STATE.md` first after synchronizing the branch.

## Expected repository state

- Repository: `westkitty/DexDictate_MacOS`
- Branch: `work/dexdictate-audio-hardening`
- `origin/main`: `7cb739208ea11af6e20beccd9907affbe4500444`
- Phase 0 local report may still be the only untracked file:
  `docs/audio_hardening/phase_0_baseline_report.md`

Do not work on `main`.

## Step 0 — Environment and branch synchronization

Run:

```bash
pwd
git rev-parse --show-toplevel
git remote get-url origin
git branch --show-current
git status --porcelain=v1
git rev-parse HEAD
git fetch origin main work/dexdictate-audio-hardening
git rev-parse origin/main
git rev-parse origin/work/dexdictate-audio-hardening
```

Hard gates:

1. repo must be the intended DexDictate checkout;
2. current branch must be `work/dexdictate-audio-hardening`;
3. `origin/main` must still equal `7cb739208ea11af6e20beccd9907affbe4500444`;
4. before synchronization, the working tree must be clean **or** contain exactly the untracked Phase 0 report above and nothing else.

If an unexpected dirty path exists, STOP. Do not stash/reset/discard it.

Bring the work branch to the remote head with a fast-forward only:

```bash
git pull --ff-only origin work/dexdictate-audio-hardening
```

The untracked Phase 0 report is expected to remain intact because the remote does not contain that path yet. If Git refuses because of a conflict, STOP; do not force or relocate user work.

Read:

```text
OPERATIONAL_STATE.md
docs/audio_hardening/phase_0_baseline_report.md
Sources/VerificationRunner/main.swift
Sources/DexDictateKit/SmartCleanup/SmartCleanupClient.swift
Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift
Sources/DexDictateKit/Transcription/MoonshineTranscriptionProvider.swift
```

## Step 1 — Confirm the stale assertion and current approved direct-network surface

Run this read-only inventory:

```bash
rg -n 'URLSession|NSURLConnection|NWConnection|Alamofire' Sources --glob '*.swift'
```

Ignore occurrences inside `Sources/VerificationRunner/main.swift` itself because it contains the verification token list.

At the Phase 0 baseline, direct networking tokens in project-owned production source are expected only in these exact files:

```text
Sources/DexDictateKit/SmartCleanup/SmartCleanupClient.swift
Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift
Sources/DexDictateKit/Transcription/MoonshineTranscriptionProvider.swift
```

Their approved purposes are bounded:

- `SmartCleanupClient.swift`: explicit configured Smart Cleanup/test-connection/post-processing requests; not the microphone capture or core transcription engine.
- `WhisperModelCatalog.swift`: explicit user-triggered Whisper model download.
- `MoonshineTranscriptionProvider.swift`: explicit user-triggered Moonshine model download; model inference remains local after installation.

If `rg` finds a direct networking token in any other production source file, **STOP and report it**. Do not expand the allowlist merely to make VerificationRunner green.

## Step 2 — Repair only the VerificationRunner network assertion

Primary allowed implementation file:

```text
Sources/VerificationRunner/main.swift
```

Replace the current black-path rule that effectively means:

```text
no banned networking token anywhere under Sources
```

with a narrow, explicit source-boundary assertion:

> Direct networking API tokens in project-owned `Sources` must be confined to the exact approved source files listed above; any occurrence in any other production source file fails verification.

Requirements:

1. Keep the existing banned-token set at least as strong as:
   - `URLSession`
   - `NSURLConnection`
   - `NWConnection`
   - `Alamofire`
2. Continue enumerating project-owned Swift files under `Sources`.
3. Continue excluding `Sources/VerificationRunner` from the production-source scan.
4. Use **repository-relative paths**, not filename-only matching, so a second file with the same basename cannot inherit permission accidentally.
5. Maintain one explicit exact-path allowlist containing only the three approved files above.
6. Fail if any banned token appears outside that allowlist.
7. Also fail if an allowlisted path no longer exists or no longer contains any banned token. This prevents a stale permission from silently authorizing future networking in a file whose original network purpose disappeared.
8. Emit a truthful PASS message such as:
   `direct networking APIs are confined to approved opt-in/download source surfaces`
   rather than claiming DexDictate contains no networking APIs.
9. Do not weaken or remove any other VerificationRunner check.
10. Do not change Smart Cleanup, model download, transcription, capture, provider, UI, settings, output, or application behavior in this phase.

If the change cannot be expressed safely inside `Sources/VerificationRunner/main.swift`, STOP and report why before touching additional implementation files.

## Step 3 — Static scope check

Before testing:

```bash
git diff --check
git diff --name-only
```

At this point the only tracked implementation path changed by Phase 1 should be:

```text
Sources/VerificationRunner/main.swift
```

`OPERATIONAL_STATE.md` may already differ from the Phase 0 local HEAD because it was advanced remotely between phases. Do not edit it yet during implementation.

## Step 4 — Validate the repaired verifier with isolated preferences

Use a new isolated Foundation home:

```bash
PHASE1_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dexdictate-phase1.XXXXXX")"
printf 'PHASE1_HOME=%s\n' "$PHASE1_HOME"
```

Run:

```bash
env CFFIXED_USER_HOME="$PHASE1_HOME" swift run VerificationRunner
```

Required result:

- `Failures: 0`
- `Result: PASS`
- the network-boundary check reports the new truthful approved-surface wording

If VerificationRunner still fails, perform at most **one bounded repair pass** limited to the exact failure in the new verifier logic. Do not change application behavior to satisfy the verifier.

## Step 5 — Prove the assertion still catches accidental spread

Do not permanently edit another source file.

Temporarily validate the scanner in one of these safe ways, preferring the first:

### Preferred: pure/helper-level check if the implementation naturally exposes one

Call the scanner logic against a synthetic path/content fixture representing an unapproved source containing `URLSession` and prove it is rejected.

### Fallback: temporary working-tree mutation with guaranteed restoration

If no pure seam exists, choose a harmless production Swift file that Phase 1 otherwise does not modify, record its blob/hash, append a temporary comment containing `URLSession`, run VerificationRunner expecting the network-boundary check to FAIL, then restore the file byte-for-byte from the recorded original before proceeding.

Hard rules for the fallback:

- do not use a file containing user data/configuration;
- do not commit the temporary mutation;
- verify `git diff` shows the temporary file fully restored afterward;
- if restoration is not exact, STOP and do not commit anything.

The purpose is to prove the new check is a guard, not an allow-all rewrite.

## Step 6 — Full regression baseline

With the same isolated Foundation home:

```bash
env CFFIXED_USER_HOME="$PHASE1_HOME" swift test
```

Acceptance:

- 0 failures
- skips are allowed but must be reported
- do not assume the Phase 0 executed count must remain exactly 707 if the verifier-only source change alters no tests; report the actual count

Then run:

```bash
git diff --check
```

## Step 7 — Record Phase 1 result

Create exactly:

```text
docs/audio_hardening/phase_1_verifier_repair_report.md
```

Include:

```markdown
# Phase 1 Verification Policy Repair Report

- Timestamp:
- Starting branch HEAD:
- origin/main:
- Phase 0 report preserved: YES/NO

## Network surface inventory
- Approved direct-network files observed:
- Unexpected direct-network files: none / list

## Implementation
- VerificationRunner file changed: YES/NO
- Application behavior files changed: NO
- New rule summary:

## Validation
- VerificationRunner: PASS/FAIL
- VerificationRunner checks:
- VerificationRunner failures:
- Negative-control guard test: PASS/FAIL
- Full suite: PASS/FAIL
- Executed:
- Failures:
- Skips:
- git diff --check: PASS/FAIL

## Evidence boundary
- Installed app replaced: NO
- Real microphone tested: NO
- Bluetooth/Zoom route churn tested: NO
- TCC changed: NO
- User DexDictate preferences intentionally changed: NO
- Dependencies changed: NO

## Phase 1 verdict
- PASS/BLOCKED
```

## Step 8 — Update operational state only after validation

If and only if VerificationRunner and the full suite pass:

Update `OPERATIONAL_STATE.md` narrowly:

- promote `BRK-001` from `known-broken` to verified/resolved evidence;
- mark `PND-001` complete or superseded;
- keep installed live-caption state `UNK-002` unknown;
- make Phase 2 live transcription proof the next active task;
- preserve every audio/live invariant and prohibition;
- increment the operational-state revision once.

Do not rewrite unrelated state entries.

If Phase 1 is blocked, record the exact failure without promoting anything.

## Step 9 — Commit and push the Phase 0 evidence, then the Phase 1 work

The local Phase 0 report is legitimate evidence and must not remain stranded as an untracked file.

First commit it by itself if it is still untracked:

```bash
git add docs/audio_hardening/phase_0_baseline_report.md
git diff --cached --name-only
git diff --cached --check
git commit -m "docs(audio-hardening): record phase 0 Mac baseline"
```

Before that commit, the staged file list must contain exactly the Phase 0 report.

Then stage Phase 1 only:

Expected Phase 1 paths are:

```text
Sources/VerificationRunner/main.swift
OPERATIONAL_STATE.md
docs/audio_hardening/phase_1_verifier_repair_report.md
```

Run:

```bash
git add Sources/VerificationRunner/main.swift OPERATIONAL_STATE.md docs/audio_hardening/phase_1_verifier_repair_report.md
git diff --cached --name-only
git diff --cached --check
git status --short
```

The staged file list must contain exactly those three paths. If another path appears, unstage only files Codex itself staged and STOP. Do not reset/discard/stash pre-existing work.

Commit:

```bash
git commit -m "test(audio-hardening): repair local network verification boundary"
git push origin work/dexdictate-audio-hardening
```

No force push. No PR. No merge. Do not touch `main`.

## Completion rule

Phase 1 is PASS only when all are true:

1. current intentional direct-network source surface is explicitly inventoried;
2. no unexpected production-source direct networking is found;
3. VerificationRunner reports zero failures;
4. a negative control proves the repaired rule still catches a banned token outside the allowlist;
5. full XCTest suite remains at zero failures;
6. no application behavior source, installed app, TCC, audio route, dependency, or real user preference was changed;
7. Phase 0 evidence and Phase 1 evidence are pushed to `work/dexdictate-audio-hardening`;
8. operational state identifies installed live transcription as the next unresolved proof.

Do **not** begin live-transcription instrumentation, microphone testing, AUHAL work, UI changes, or route-churn testing in this packet.

## Final response

Return only:

1. Phase 1 verdict (`PASS` or `BLOCKED`)
2. final branch HEAD
3. observed approved network-source files and whether any unexpected hit existed
4. VerificationRunner result/check/failure count
5. negative-control result
6. full-suite executed/failure/skip counts
7. changed files in the Phase 1 implementation commit
8. confirmation Phase 0 report was committed/pushed
9. earliest unresolved failure, if any
10. confirmation no application behavior, installed app, TCC, audio routes, dependencies, or real user preferences were intentionally changed
