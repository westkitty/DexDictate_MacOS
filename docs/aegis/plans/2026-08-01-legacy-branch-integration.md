# Legacy Branch Integration Plan

## Goal

Integrate all valuable work from every remaining non-`main` DexDictate branch without losing history, replacing newer implementations with stale code, or deleting recoverability before verification.

## Architecture

Current `origin/main` remains the canonical product tree. Each legacy branch is integrated by one of three explicit mechanisms:

1. normal merge when its implementation is current and conflict-free;
2. ancestry merge plus curated artifact extraction when only part of its tree belongs in the product repository; or
3. ancestry merge with the current tree retained when its functionality is already superseded.

Annotated archive tags provide an independent recovery path. The committed audit maps every branch tip and unique commit to its disposition.

## Tech Stack

- Swift Package Manager and Swift 5/6 concurrency diagnostics
- SwiftUI/AppKit macOS application
- XCTest
- Node.js/Remotion for the preserved marketing project
- Vite/React/pnpm for the preserved UX prototype
- GitHub Actions and pull requests for remote verification

## Baseline/Authority Refs

- `docs/DEXDICTATE_BIBLE.md`
- `docs/FEATURE_INVENTORY.md`
- `docs/refactor_baseline/final_remaining_campaign/FINAL_STATE_REPORT.md`
- `docs/aegis/baseline/2026-08-01-initial-baseline.md`
- live branch tips and diffs fetched from `origin` on 2026-08-01
- user authorization in the active task: integrate completed work and do not lose any branch value

## Compatibility Boundary

- Preserve current permission order, output safety, model selection, settings migrations, packaged-app behavior, and default feature values.
- Do not re-enable full leading-silence trimming: current `ExperimentFlags.enableSilenceTrim` documents that it can clip sentence onsets and requires a redesigned pre-trigger calibration path.
- Do not replace `TriggerShortcutConflictChecker`, accuracy retry, persistent history, audio import, per-app insertion, focused-context injection, warm-up, live captions, or current UI architecture with older implementations.
- Do not adopt checkout-generated `.resurrection` snapshots.
- Keep standalone JavaScript projects below explicit subdirectories rather than turning the Swift repository root into a Node project.

## TDD Route

- Mode: off
- Decision: skipped
- Strict authority: not applicable
- Test posture: post-change regression
- Reason: the task is history integration plus one bounded existing-capability port; the user did not request strict test-driven development.
- Verification: focused command-processor tests after the port, project-specific JavaScript builds, full `swift test`, `swift build`, packaged-app build, CI, and remote SHA parity.

## Aegis Visibility

The plan keeps ancestry preservation, compatibility, selective extraction, branch retirement, and verification tied to one reviewable checkpoint so that “merged” cannot be confused with “usefully integrated.”

## BaselineUsageDraft

- Required baseline refs: DexDictate Bible, feature inventory, final campaign report, live Git refs, initial baseline
- Delivered context refs: active user request and prior branch assessment
- Acknowledged before plan refs: all required refs
- Cited in plan refs: all required refs
- Missing refs: none
- Decision: continue

## Requirement Ready Check

- Requirement source refs: active user request
- Goals and scope refs: preserve and integrate all branch work; finish with `main` as the only branch
- User / scenario refs: maintainer consolidating historical feature and prototype work
- Requirement item refs: every remaining branch tip and every unique commit in the branch audit
- Acceptance / verification criteria refs: archive-tag parity, ancestry reachability, curated artifacts, focused/full tests, builds, CI, remote parity, final branch inventory
- Open blocker questions: none; risky legacy experiments may be preserved without reactivation when current safety doctrine explicitly rejects them
- Decision: ready

## Change Necessity

- User-visible need: retain capabilities and artifacts that are absent from current `main`
- No-change / non-code option: archive tags alone preserve history but do not make missing punctuation voice commands or standalone artifacts discoverable in the maintained tree
- Why code change is necessary: current `CommandProcessor` supports new-line commands and custom hot words but lacks the branch's built-in spoken punctuation replacement
- Minimum change boundary: `CommandProcessor.swift`, its focused test file, curated documentation/artifact paths, and merge ancestry
- Decision: code-change

## Existence Check

- Proposed new surface: built-in punctuation replacement
- Existing owner / reuse candidate: `CommandProcessor`
- Why existing surface is insufficient: it handles command recognition but only replaces `new line`/`next line`
- Creation proof: legacy commit `672ec24e` contains the behavior and 51 lines of focused tests
- Entropy / retirement impact: add a private helper in the existing 97-line cohesive owner; no new service, setting, or fallback
- Decision: reuse-existing

## Architecture Integrity Lens

- Invariant: transcription output still passes through custom hot-word handling and established built-in command processing
- Canonical owner / contract: `CommandProcessor.process(_:customCommands:)`
- Responsibility overlap: none if punctuation remains a private normalization step in the same owner
- Higher-level simplification: preserve the current custom-command API and add only punctuation normalization before built-in matching
- Retirement / falsifier: remove the port if focused tests show custom commands or trailing-punctuation command matching regress
- Verdict: proceed with bounded edit

## Plan-Time Complexity Check

Complexity Budget:
- Artifact class: Source Complexity and Test Complexity
- Target files / artifacts: 97-line `CommandProcessor.swift`; 89-line `CommandProcessorTests.swift`
- Current pressure: low and cohesive
- Projected post-change pressure: roughly 35 source lines and focused cases
- Budget result: within-budget
- Planned governance: keep the helper private; do not touch the 1,552-line `TranscriptionEngine.swift`

Plan-Time Complexity Check:
- Target files: command processor and focused tests
- Existing size / shape signals: both below 100 lines before the port
- Owner fit: direct
- Add-in-place risk: bounded
- Better file boundary: none
- Recommendation: edit-in-place

## Execution Readiness View

- Intent Lock: preserve all original tips and integrate every non-superseded capability or artifact
- Scope Fence: merge ancestry, curated archives/prototypes, punctuation commands, verification, branch retirement
- Baseline Lock: `origin/main` at `bb2bf5a5`; 503-test warm-cache baseline green
- Approved Behavior: current main behavior plus reversible dictation undo and spoken punctuation; archived projects remain non-runtime
- Owner / Contract Constraints: current owners win; stale branch files never replace newer implementations wholesale
- Compatibility Boundary: permission, output, settings, provider, and default behavior remain stable
- Retirement Boundary: delete branches only after archive tags and main ancestry are both remotely verified
- Task Batches: governance; undo; speech docs; nifty history/punctuation; UX prototype; Remotion project; v1.5 history; verification/publish; cleanup
- Test Obligations: focused undo/command tests, JavaScript builds, full Swift tests/build, packaged app, CI
- Review Gates: inspect each merge diff; stop on unexpected source changes or failing focused tests
- Drift / Rewind Rules: abort a merge before commit when its tree exceeds the named paths; revert the slice commit if verification fails after commit
- Evidence Required Before Completion: local commands with exit codes, CI conclusion, remote SHA parity, archive tags, `main` ancestry checks, final local/remote branch list
- Advisory Boundary: method-pack execution guidance only; not completion authority

## Tasks

### Task 1: Commit governance and branch audit

Files:
- create `docs/aegis/**`
- create `docs/branch-integration/2026-08-01-legacy-branch-audit.md`

Why: make every source branch and disposition durable before integration commits begin.

Change Necessity: documentation is the minimum durable mapping from archived history to current product ownership.

Impact/Compatibility: documentation only.

Verification:
```bash
git diff --check
git status --short
```

Steps:
1. Record every remote archive tag and peeled target.
2. Record every unique commit and its planned disposition.
3. Commit only the named documentation paths with hooks bypassed for this command because the inspected Project Sentinel hook rewrites unrelated recovery files.

### Task 2: Integrate reversible dictation undo

Files:
- merge the complete final tree of `origin/claude/dexdictate-reversible-insertion-v7ceg8`

Why: this is a current, clean, tested implementation absent from `main`.

Change Necessity: a history-only merge would omit the user-facing undo capability.

Impact/Compatibility: retain the branch's verification-gated deletion strategies, tests, and existing output refactor; no conflict resolution is expected.

Verification:
```bash
swift test --filter DictationUndoManagerTests
swift test --filter OutputCoordinatorTests
swift test --filter TranscriptionFeedbackTests
git diff --check HEAD^1..HEAD
```

Steps:
1. Merge with `git -c core.hooksPath=/dev/null merge --no-ff origin/claude/dexdictate-reversible-insertion-v7ceg8`.
2. Inspect the merge tree for paths outside the reviewed pull-request file list.
3. Run the focused suites and stop on any failure.

### Task 3: Integrate and archive the Fable UI/UX recovery record

Files:
- `docs/archive/uiux-recovery-2026-07/`
- merge ancestry from `origin/speech-engine-exploration-benchmarks`

Why: preserve the plan, executor handoff, and screenshot evidence while clearly marking them as historical inputs to work already delivered on `main`.

Change Necessity: root-level stale executor instructions are misleading; an archive with status context is discoverable and honest.

Impact/Compatibility: no source changes; `.resurrection` remains at current `main`.

Verification:
```bash
git diff --check
git diff --name-status HEAD^1..HEAD
```

Steps:
1. Start a no-commit normal merge of the speech branch.
2. Restore `.resurrection` from the pre-merge current tree.
3. Move both Markdown documents and the screenshot ZIP under `docs/archive/uiux-recovery-2026-07/`.
4. Add a provenance README that names the original commits and states that Packet 16 later completed the implementation campaign.
5. Commit the curated merge.

### Task 4: Integrate nifty-wilson history and port spoken punctuation

Files:
- `Sources/DexDictateKit/CommandProcessor.swift`
- `Tests/DexDictateTests/CommandProcessorTests.swift`
- merge ancestry from `origin/claude/nifty-wilson`

Why: most branch behavior is superseded, but spoken punctuation remains absent.

Change Necessity: archive-only retention does not expose the missing capability.

Impact/Compatibility: preserve `process(_:customCommands:)`; custom hot words still resolve before built-ins; leading/full silence trim remains disabled.

Verification:
```bash
swift test --filter CommandProcessorTests
git diff --check
```

Steps:
1. Record the branch with an `ours` merge so all nineteen commits become reachable without replacing current owners.
2. Add a private punctuation-normalization helper covering parentheses, quotes, paragraph breaks, exclamation/question marks, period/full stop, comma, colon, semicolon, ellipsis, dash, and hyphen.
3. Apply normalization before built-in command matching while retaining current custom-command precedence and trailing-punctuation matching.
4. Port focused cases from legacy commit `672ec24e` and add compatibility cases for custom commands and ordinary text.
5. Commit the bounded port.

### Task 5: Integrate the historical UX prototype

Files:
- `prototypes/dexdictate-ux/`
- merge ancestry from `origin/feat/audio-import-custom-commands-per-app-insertion`

Why: the Swift features already exist on `main`, while the React prototype is the branch's unique maintained artifact.

Change Necessity: the prototype needs a discoverable non-runtime home.

Impact/Compatibility: no Swift source replacement; prototype remains isolated from the repository root.

Verification:
```bash
corepack pnpm --dir prototypes/dexdictate-ux install --frozen-lockfile
corepack pnpm --dir prototypes/dexdictate-ux build
```

Steps:
1. Record the branch with an `ours` merge.
2. Restore the branch's `dexdictate-ux` subtree and move it to `prototypes/dexdictate-ux`.
3. Add provenance noting that its Swift concepts were independently integrated on `main` in commit `7685ad4b` and later refactors.
4. Install from the committed lockfile and build.
5. Commit the prototype extraction without dependency/build output.

### Task 6: Integrate the Remotion marketing project

Files:
- `marketing/remotion/`
- merge ancestry from `origin/codex/remotion-runner-20260314-225455`

Why: retain the complete animation project without converting the Swift repository root into a Node project.

Change Necessity: relocation is required for repository-boundary compatibility.

Impact/Compatibility: the Remotion project is standalone and does not affect Swift build inputs.

Verification:
```bash
npm --prefix marketing/remotion ci
npm --prefix marketing/remotion run remotion:compositions
```

Steps:
1. Record the branch with an `ours` merge.
2. Restore `package.json`, `package-lock.json`, `tsconfig.json`, `animation_spec.md`, `public/`, `src/`, and the original Remotion best-practices reference into `marketing/remotion/`.
3. Exclude the legacy `.claude` and `.codex` symlinks from the maintained tree.
4. Add provenance and run the composition enumerator.
5. Commit the relocated project without `node_modules` or rendered output.

### Task 7: Integrate obsolete v1.5 release ancestry

Files:
- merge ancestry from `origin/codex/v1-5-release-prep`
- branch audit disposition only

Why: retain the branch history while preserving current version 1.8.0 and later fixes.

Change Necessity: no source change is necessary; two commits are patch-equivalent to `main` and the release metadata is obsolete.

Impact/Compatibility: current tree retained exactly.

Verification:
```bash
test "$(cat VERSION)" = "1.8.0"
git diff --quiet HEAD^1 HEAD
```

Steps:
1. Merge with the `ours` strategy and a message documenting supersession.
2. Verify the tree is unchanged and version remains 1.8.0.

### Task 8: Verify and publish integration

Files:
- combined integration tree

Why: prove the combined result, not merely each isolated slice.

Change Necessity: no additional implementation expected.

Impact/Compatibility: validation only unless a reproducible integration defect is found and separately checkpointed.

Verification:
```bash
swift test
swift build
INSTALL_DIR="$PWD/.build/local-install" ./build.sh
git diff --check origin/main...HEAD
```

Steps:
1. Run full Swift tests and build.
2. Build the packaged application into the worktree-local install directory.
3. Verify artifact subprojects again from clean dependency installs.
4. Inspect the complete diff, file sizes, secrets, private paths, and generated output.
5. Push `codex/integrate-legacy-work` with a scoped hook bypass.
6. Create a pull request, wait for CI, and merge only if checks pass.
7. Verify remote `main` contains the integration tip.

### Task 9: Retire branches and normalize the primary checkout

Files:
- Git refs and existing worktree metadata only

Why: achieve the requested final state of `main` as the only branch while keeping all original work recoverable through archive tags and main ancestry.

Change Necessity: branch deletion is necessary only after integration acceptance.

Impact/Compatibility: preserve dirty `.resurrection` work in labeled stashes before removing branch-owning worktrees.

Verification:
```bash
git branch --format='%(refname:short)'
git ls-remote --heads origin
git ls-remote --tags origin 'refs/tags/archive/*'
git merge-base --is-ancestor <each-archived-tip> origin/main
```

Steps:
1. Create labeled stashes in each dirty worktree.
2. Remove the obsolete branch-owning worktrees after they are clean.
3. Switch the primary checkout to `main` and fast-forward it to verified `origin/main`.
4. Delete all remaining local and remote non-`main` branches.
5. Prune stale worktree metadata without removing live detached worktrees.
6. Verify `main` is the only local and remote branch and all archive tags still resolve.

## Risks

- Undo changes operate on user text; automated tests cannot replace multi-application manual behavior proof.
- JavaScript dependencies may contain advisories or incompatible future package changes; lockfiles and clean installs bound the evidence.
- A merge strategy can preserve ancestry while hiding a missed capability; the branch audit and current-owner mapping are the countercheck.
- Project Sentinel hooks can rewrite `.resurrection`; all scoped bypasses are recorded and hook files remain unchanged.
- Full tests can cold-compile Core ML models past a 60-second expectation; warm-cache rerun evidence must be distinguished from a code regression.

## Retirement

Legacy branches remain until their archive tags, main ancestry, artifact placement, and integration verification are all proven remotely. After retirement, recovery remains possible from both `archive/*-2026-08-01` tags and the merge ancestry on `main`. Labeled stashes preserve uncommitted recovery snapshots outside branch refs.
