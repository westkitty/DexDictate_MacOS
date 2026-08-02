# Initial Baseline — 2026-08-01

- Repository: `/Users/andrew/DexDictate_MacOS.nosync`
- Isolated worktree: `/Users/andrew/.config/aegis/worktrees/DexDictate_MacOS.nosync/integrate-legacy-work`
- Integration branch: `codex/integrate-legacy-work`
- Baseline ref: `origin/main`
- Baseline commit: `bb2bf5a5e257aa31517b5ec5f04d8a301707933c`
- Working tree at creation: clean

## Verification

The first `swift test` run executed 503 tests with three environment-dependent skips and one timeout while Nemotron and Parakeet Core ML models were compiled for the first time. The exact failed test then passed in 1.628 seconds. A fresh full rerun completed successfully:

```text
Executed 503 tests, with 3 tests skipped and 0 failures
exit 0
```

Existing compiler warnings include Swift 6 sendability warnings and a FluidAudio unhandled `benchmark.md` warning. They predate this integration and are not widened by the approved scope.

## Preservation Baseline

Seven annotated `archive/*-2026-08-01` tags were pushed and their peeled remote targets verified before integration began. Exact targets are recorded in `docs/branch-integration/2026-08-01-legacy-branch-audit.md`.
