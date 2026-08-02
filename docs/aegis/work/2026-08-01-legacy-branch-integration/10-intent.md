# Task Intent — Legacy Branch Integration

## Requested Outcome

Integrate all useful work from every remaining DexDictate branch and finish with `main` as the only branch without losing history or uncommitted recovery state.

## Scope

- archive tags and commit ancestry
- reversible dictation undo
- historical UI/UX plan and evidence
- spoken punctuation commands
- React UX prototype
- Remotion marketing project
- superseded release and feature histories
- verification, publication, and branch cleanup

## Non-Goals

- no permission-flow redesign
- no transcription-engine rewrite
- no reactivation of unsafe full leading-silence trimming
- no replacement of newer current-main features with stale implementations
- no deletion of user `.resurrection` changes

## Risk Hints

Text undo is destructive if verification fails; old branches touch current hotspots; standalone Node projects can pollute the Swift root; hooks rewrite recovery metadata; cold Core ML compilation can exceed test timeouts.

## BaselineReadSetHint

Read the DexDictate Bible, feature inventory, final campaign report, initial integration baseline, branch audit, and live Git refs before resuming.

## BaselineUsageDraft

- Required refs: all Baseline/Authority Refs in the parent plan
- Acknowledged refs: all required refs
- Cited refs: parent plan and branch audit
- Missing refs: none
- Decision: continue

## ImpactStatementDraft

The maintained Swift tree gains only reviewed undo behavior and a bounded command-normalization capability. Historical branches become main ancestry; standalone artifacts move under explicit non-runtime directories; obsolete implementations remain recoverable but inactive.

## Execution Readiness View

Use the complete view in `docs/aegis/plans/2026-08-01-legacy-branch-integration.md`. Its intent, compatibility, retirement, test, and review locks are active for every slice.
