# Todo Checkpoint — 2026-08-01

## Current Todo

- [x] Inspect branches, worktrees, divergence, pull requests, and conflict surfaces.
- [x] Push and verify archive tags for every original non-main tip.
- [x] Create a clean isolated integration worktree from `origin/main`.
- [x] Reconcile the Swift baseline and obtain a clean 503-test run.
- [x] Commit governance and branch audit.
- [x] Integrate reversible dictation undo.
- [x] Curate and integrate speech/UI recovery artifacts.
- [x] Integrate nifty history and spoken punctuation.
- [ ] Integrate the UX prototype.
- [ ] Integrate the Remotion project.
- [ ] Integrate v1.5 ancestry.
- [ ] Run combined verification and publish integration.
- [ ] Merge to main, preserve dirty worktrees, and retire branches.

## Active Slice

Integrate the standalone UX prototype while keeping it outside the production Swift package.

## Completed Todos

Preservation tags, isolated worktree, baseline test reconciliation, governance/audit commit, reversible dictation undo merge, curated UI recovery archive, nifty ancestry, and spoken punctuation.

## Evidence Refs

- remote `archive/*-2026-08-01` peeled targets
- `swift test`: 503 tests, 3 skipped, 0 failures, exit 0
- focused cold-timeout rerun: 1 test, 0 failures, exit 0
- undo merge commit: `914e95c6`
- undo verification: 8 undo-manager, 29 output-coordinator, 2 feedback, and 12 Accessibility insertion tests; 0 failures
- UI recovery merge commit: `2618129`; only four archive paths differ from its first parent
- speech branch tip `69c6533c` is reachable; `.resurrection` is unchanged in the committed tree
- nifty ancestry merge: `42f82082`; original tip `977b625b` is reachable and the first-parent tree is unchanged
- spoken punctuation commit: `167d4b6`; 13 `CommandProcessorTests` passed with 0 failures

## Blockers

None.

## ResumeStateHint

Resume in `/Users/andrew/.config/aegis/worktrees/DexDictate_MacOS.nosync/integrate-legacy-work`, read the parent plan and this checkpoint, keep Project Sentinel's unstaged `.resurrection` churn excluded, then record the audio/import branch ancestry and extract `dexdictate-ux` beneath `prototypes/`.

## DriftCheckDraft

- Original intent served: yes
- Compatibility boundary held: yes
- New owner/fallback/adapter: no
- Retirement track explicit: yes
- Evidence sufficient for next slice: yes
- Decision: continue
