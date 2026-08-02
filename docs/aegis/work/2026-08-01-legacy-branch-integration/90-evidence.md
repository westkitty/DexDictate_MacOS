# Evidence Bundle Draft

## Preservation

Seven annotated archive tags were pushed. Their peeled targets match the original branch tips recorded in the branch audit.

## Baseline

- Initial full test: 503 tests, 3 skipped, 1 cold model-load timeout.
- Exact focused rerun: passed in 1.628 seconds.
- Fresh warm-cache full test: 503 tests, 3 skipped, 0 failures, exit 0.

## Workspace

- Integration worktree created cleanly from `origin/main` at `bb2bf5a5`.
- Existing user worktrees and dirty `.resurrection` files were not modified.

## Reversible Dictation Undo

- Merge commit: `914e95c6`
- Merge path inspection: exactly the 15 reviewed pull-request paths
- `DictationUndoManagerTests`: 8 passed
- `OutputCoordinatorTests`: 29 passed
- `TranscriptionFeedbackTests`: 2 passed
- `AccessibilityInsertionTests`: 12 passed
- `git diff --check HEAD^1..HEAD`: clean
- Residual manual proof: exercise exact restore, verified trim, refusal, and best-effort Backspace fallback in representative target applications

## UI Recovery Archive

- Merge commit: `2618129`
- Original speech branch tip `69c6533c` is an ancestor of the integration branch
- First-parent diff contains only the archive README, two historical Markdown documents, and the screenshot packet ZIP
- The committed `.resurrection` tree is identical to the merge commit's first parent
- Project Sentinel's concurrent unstaged `.resurrection` rewrites remain excluded

## Nifty History and Spoken Punctuation

- Ancestry merge commit: `42f82082`
- Original nifty tip `977b625b` is an ancestor of the integration branch
- The ancestry merge's first-parent tree is unchanged
- Spoken punctuation commit: `167d4b6`
- Current custom-command precedence and trailing-punctuation command matching are retained
- `DexDictateTests.CommandProcessorTests`: 13 passed, 0 failures
- Full/onset silence trimming remains disabled because the current experiment flag documents clipping risk; the older implementation remains available through history and its archive tag

## Pending Evidence

Each merge diff, focused tests, artifact builds, combined Swift verification, packaged app, CI, remote parity, ancestry checks, and final branch inventory.
