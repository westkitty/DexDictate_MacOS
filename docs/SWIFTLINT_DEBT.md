# SwiftLint debt baseline

## Baseline record

- Created: 2026-07-13
- SwiftLint version used: 0.65.0 (pinned in [`.swiftlint-version`](../.swiftlint-version))
- Original violation count: 169 (all `error` severity under `--strict`), across 62 files
- Baseline file: [`.swiftlint-baseline.json`](../.swiftlint-baseline.json)

### Violations by rule

| Rule | Count |
| --- | --- |
| `trailing_comma` | 28 |
| `function_body_length` | 22 |
| `file_length` | 20 |
| `comma` | 19 |
| `type_body_length` | 16 |
| `implicit_optional_initialization` | 13 |
| `multiple_closures_with_trailing_closure` | 9 |
| `cyclomatic_complexity` | 5 |
| `large_tuple` | 5 |
| `opening_brace` | 5 |
| `vertical_whitespace` | 5 |
| `nesting` | 3 |
| `redundant_discardable_let` | 3 |
| `for_where` | 2 |
| `function_parameter_count` | 2 |
| `static_over_final_class` | 2 |
| `unused_closure_parameter` | 2 |
| `void_function_in_ternary` | 2 |
| `colon` | 1 |
| `empty_count` | 1 |
| `non_optional_string_data_conversion` | 1 |
| `orphaned_doc_comment` | 1 |
| `statement_position` | 1 |
| `unneeded_synthesized_initializer` | 1 |

### Highest-debt files

| File | Violations |
| --- | --- |
| `TranscriptionEngine.swift` | 12 |
| `main.swift` | 8 |
| `ClipboardManager.swift` | 8 |
| `DexExperimentalUITests.swift` | 7 |
| `AudioRecorderService.swift` | 7 |
| `TranscriptionQualityMetricsTests.swift` | 6 |
| `SecureInputContext.swift` | 6 |
| `PermissionSettingsLinkerTests.swift` | 6 |
| `ModelBenchmarking.swift` | 6 |
| `TranscriptionQualityMetrics.swift` | 5 |

Run `make lint-debt` for the full, current rule-by-rule accounting.

## Commands

| Purpose | Command |
| --- | --- |
| Normal strict lint (suppressing baselined debt) | `make lint` |
| Deliberate gate-rejection proof | `make lint-gate-test` |
| Full baselined-debt inspection | `make lint-debt` |

## Known limitation: the baseline is keyed by absolute path

SwiftLint's `--baseline` mechanism matches violations by absolute file path
([realm/SwiftLint#5599](https://github.com/realm/SwiftLint/issues/5599), open
as of 0.65.0) — not by a content hash or repo-relative path. `.swiftlint-baseline.json`
was generated for GitHub Actions' fixed macOS checkout path,
`/Users/runner/work/DexDictate_MacOS/DexDictate_MacOS`, and only suppresses the
recorded debt when SwiftLint runs from that exact path — i.e. in CI's `lint` job.

Running `make lint` from an arbitrary local clone will therefore show the full
169-violation debt rather than just new violations; that's the tool's design,
not a bug in this setup. `make lint-gate-test` / `scripts/test_swiftlint_gate.sh`
proves the gate mechanism itself (suppression + new-violation detection) using a
throwaway baseline regenerated at whatever path it's run from, so it passes
anywhere `swiftlint` is installed. If SwiftLint gains a relative-path baseline
option in a future release, this limitation can be revisited.

## Policy

- **This baseline records debt — it does not approve it.** Every entry is a
  pre-existing violation that was allowed to land before this gate existed.
- **Feature work may not add new violations.** Strict lint against the
  baseline must stay green; a PR that introduces new violations should fix
  them, not grow the baseline.
- **Cleanup batches must reduce baseline entries.** When a batch of debt is
  paid down, regenerate the baseline (`swiftlint lint --strict --write-baseline
  .swiftlint-baseline.json` from the CI checkout path) so the entry count goes
  down, and note the new count in this document.
- **Do not regenerate the baseline casually.** Regenerating it silently
  re-approves whatever violations exist at that moment, including accidental
  new ones. Any baseline growth requires an explicit explanation in the PR
  description and review — it is not a routine operation.
