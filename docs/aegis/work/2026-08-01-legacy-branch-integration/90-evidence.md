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

## UX Prototype

- Audio/import ancestry merge: `7b8fc06c`
- Original branch tip `7701b6ff` is an ancestor of the integration branch
- Prototype extraction commit: `045d8fdb`
- Recovered project is isolated under `prototypes/dexdictate-ux`; production Swift files were not overlaid
- `pnpm install --frozen-lockfile`: passed, with four transitive install scripts explicitly approved in project-local policy
- `pnpm build`: passed
- `pnpm lint`: passed

## Remotion Explainer

- Ancestry merge: `c9754082`
- Original branch tip `1bfd3336` is an ancestor of the integration branch
- Isolated project commit: `8994bcc2`
- Recovered project is under `marketing/remotion`; root package files and agent-skill symlinks were not overlaid
- Recovered Remotion reference material is non-discoverable project documentation under `reference/`
- Lockfile refreshed within declared version ranges: Remotion 4.0.503, 0 audit vulnerabilities
- Clean `npm ci`: passed with project-local `esbuild@0.28.1` install-script approval
- `npm run remotion:compositions`: `MainComposition`, 30 fps, 1920x1080, 1574 frames (52.47 seconds)

## Superseded v1.5 Release

- Ancestry merge: `f9d03751`
- Original branch tip `233ca17a` is an ancestor of the integration branch
- First-parent tree is unchanged
- Current `VERSION` remains 1.8.0

## Pending Evidence

Each merge diff, focused tests, artifact builds, combined Swift verification, packaged app, CI, remote parity, ancestry checks, and final branch inventory.
