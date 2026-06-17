# DexDictate Fix Plan

**Audit date:** 2026-04-10
**Repository:** DexDictate_MacOS v1.5.2

Prioritized remediation plan derived from forensic audit. Issues are ordered by severity and prerequisite relationship.

Severity scale:
- **CRITICAL** — Functional breakage or silent data corruption
- **HIGH** — Likely to cause confusion, incorrect behavior, or CI failure
- **MEDIUM** — Risk of future contributor error or operational misdirection
- **LOW** — Style, hygiene, or defensive improvement
- **INFO** — Informational observation; no action required

---

## Issue 1 — `Info.plist` Minimum OS Version Mismatch

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **File** | `Sources/DexDictate/Info.plist` line 22 |
| **Evidence** | `LSMinimumSystemVersion = 13.0`; `Package.swift` declares `.macOS(.v14)` |
| **Impact** | macOS 13 users see a plist that advertises compatibility, launch the app, and encounter a crash instead of a graceful error. Misleading to end users, misleading to App Store review if ever submitted. |
| **Recommended fix** | Change `<string>13.0</string>` to `<string>14.0</string>` in `Info.plist`. Verify `templates/Info.plist.template` contains the same and update it. |
| **Blast radius** | 2 files (Info.plist + template). Zero runtime change. |
| **Prerequisites** | None |

---

## Issue 2 — `restart_app.sh` References Removed App Name

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **File** | `restart_app.sh` (22 lines) |
| **Evidence** | Script references `DexDictate_V2` — `pkill -f DexDictate_V2`, `open ~/Applications/DexDictate_V2.app` — but the app is now named `DexDictate`. The script is completely nonfunctional. |
| **Impact** | Any developer who runs `./restart_app.sh` during development will silently do nothing (pkill fails, open fails). Misleads new contributors about the app name and workflow. |
| **Recommended fix** | Option A: Delete the script (it provides minimal value over `./build.sh && open ~/Applications/DexDictate.app`). Option B: Update both references from `DexDictate_V2` to `DexDictate`. |
| **Blast radius** | 1 file. No runtime impact. |
| **Prerequisites** | None |

---

## Issue 3 — CI May Fail Silently on ResourceBundleTests (No Model on Runner)

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **File** | `.github/workflows/ci.yml`, `Tests/DexDictateTests/ResourceBundleTests.swift` |
| **Evidence** | CI workflow runs `swift test -v` without first calling `scripts/fetch_model.sh`. `ResourceBundleTests` validates presence of `tiny.en.bin` (74 MB). GitHub Actions runners do not have this file. |
| **Impact** | Either: (a) tests that depend on the model silently skip (if guarded), or (b) they fail with a resource-not-found error. In either case, CI does not accurately reflect the test suite state. |
| **Recommended fix** | Add a CI step before `swift test`: `bash scripts/fetch_model.sh` (or equivalent `curl` invocation). Alternatively, add a `#if SKIP_MODEL_TESTS` compile flag for CI environments and document the coverage gap. |
| **Blast radius** | CI workflow only. No source change. |
| **Prerequisites** | None |

---

## Issue 4 — SwiftLint Not Run in CI

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **File** | `.github/workflows/ci.yml`, `.swiftlint.yml` |
| **Evidence** | `.swiftlint.yml` is present and configured, but CI only runs `swift build` and `swift test`. No `swiftlint` step exists. |
| **Impact** | Style regressions accumulate silently. When new contributors submit code that violates lint rules, they discover violations only locally (if they even have SwiftLint installed), not via CI. |
| **Recommended fix** | Add a CI step: `swiftlint --strict` (or `swiftlint lint --reporter github-actions-logging`). May require Homebrew install of SwiftLint on the runner. Optionally add `brew install swiftlint` as a CI setup step. |
| **Blast radius** | CI workflow only. |
| **Prerequisites** | Issue 3 should be addressed first (CI model step) so that CI is end-to-end reliable before adding more steps. |

---

## Issue 5 — `DictationError` Is Internal, Not Public

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **File** | `Sources/DexDictateKit/Models/DictationError.swift` |
| **Evidence** | `enum DictationError` has no access modifier (Swift default: `internal`). It is not accessible from `DexDictateTests` target or external consumers of `DexDictateKit`. |
| **Impact** | Tests cannot pattern-match on `DictationError` cases. Any future extension code that needs to inspect audio pipeline errors must use string matching or a new public type. This will become a friction point if the error type grows. |
| **Recommended fix** | Mark `DictationError` and all its cases `public`. Verify existing internal usages still compile. |
| **Blast radius** | 1 file change. Additive API surface. No breaking change. |
| **Prerequisites** | None |

---

## Issue 6 — `nonisolated(unsafe)` in AudioRecorderService Relies on Code Review, Not Compiler

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **File** | `Sources/DexDictateKit/Services/AudioRecorderService.swift` lines 18–20, 165 |
| **Evidence** | `nonisolated(unsafe) private let engine = AVAudioEngine()` and `nonisolated(unsafe) private var _accumulatedSamples: [Float] = []` — both marked with comments asserting `audioQueue`-exclusive access. The comment is correct based on inspection, but Swift's concurrency checker cannot verify this. |
| **Impact** | A future contributor who adds a method to `AudioRecorderService` without understanding the `audioQueue` contract could introduce a data race on `engine` or `_accumulatedSamples`. Under Swift concurrency this would be undefined behavior. |
| **Recommended fix** | Add a structured code comment block above the `nonisolated(unsafe)` declarations explaining: (1) why nonisolated(unsafe) is used, (2) the invariant that must be maintained (all access on `audioQueue`), and (3) the consequence of violating it. Consider converting to a custom actor (`actor AudioRecorderActor`) in a future refactor to get compiler enforcement — but do not do this now (it's a significant interface change). |
| **Blast radius** | Comment addition only. Zero runtime change. |
| **Prerequisites** | None |

---

## Issue 7 — Untracked Files Accumulating in Repo Root

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Files** | `output/` (~157MB), `.tmp_onboarding_review/`, `assets/`, `scripts/batch_circle_cutout.py`, `.venv311_imageproc/`, `.venv_imageproc/` |
| **Evidence** | `git status` shows all of these as untracked. None are gitignored. |
| **Impact** | New contributors cloning the repo see `git status` output filled with noise. Generated files may be accidentally staged and committed. The 157MB `output/` directory could make the repo appear much larger than it is. |
| **Recommended fix** | Add to `.gitignore`: `output/`, `.tmp_onboarding_review/`, `assets/` (if not intended to be tracked), `.venv*/`, `scripts/batch_circle_cutout.py`. Review each one to confirm intent before adding. |
| **Blast radius** | `.gitignore` only. No source change. |
| **Prerequisites** | None |

---

## Issue 8 — Silence Trim Redesign Has No Formal Tracking

| Field | Value |
|---|---|
| **Severity** | LOW |
| **File** | `Sources/DexDictateKit/ExperimentFlags.swift` |
| **Evidence** | `enableSilenceTrim = false` with comment: "Needs redesign with a pre-trigger calibration window before this can safely be re-enabled." The redesign requirement exists only as a code comment with no issue, ticket, or doc reference. |
| **Impact** | The context for why silence trim is disabled exists in the code comment today, but if the comment is ever modified without the underlying redesign happening, the history is lost. |
| **Recommended fix** | Add a brief entry in `docs/DexDictate_Strict_Experiment_Matrix.md` documenting the silence trim status, the problem (noise-floor estimation clips speech onset), and the prerequisite (pre-trigger calibration window). This creates a persistent record outside the source file. |
| **Blast radius** | Documentation only. |
| **Prerequisites** | None |

---

## Issue 9 — Permission Polling Latency (2s Timer, Not Notification-Based)

| Field | Value |
|---|---|
| **Severity** | LOW (informational) |
| **File** | `Sources/DexDictateKit/Permissions/PermissionManager.swift` |
| **Evidence** | 2-second repeating timer for TCC permission polling. Code comment notes this is deliberate ("more reliable for TCC permission state changes"). |
| **Impact** | User grants a permission in System Settings, returns to DexDictate, and waits up to 2 seconds before the permission banner clears. Not a bug but a UX roughness. |
| **Recommended fix** | Accept as-is for now (polling is documented and reliable). Optional future improvement: trigger an immediate `refreshPermissions()` call when app gains foreground (`NSApplicationDidBecomeActiveNotification`). This reduces felt latency without replacing polling. |
| **Blast radius** | If changed: `PermissionManager.swift` only. Low risk. |
| **Prerequisites** | None (if addressed) |

---

## Issue 10 — No UI Test Harness

| Field | Value |
|---|---|
| **Severity** | LOW (informational) |
| **Evidence** | 25 unit test files exist; 0 XCUITest or SwiftUI snapshot tests exist. |
| **Impact** | UI regressions (layout breaks, missing controls, flow breakage) are invisible to CI. Caught only by manual testing. |
| **Recommended fix** | Consider adding at minimum a smoke test: launch the app, verify the menu bar item appears, verify the popover opens. XCUITest can do this. SwiftUI `ViewInspector` could test individual views without a full app. Not urgent given current feature stability, but should be added before major UI rework. |
| **Blast radius** | New test target only. No source change. |
| **Prerequisites** | Issues 3 and 4 (reliable CI) should be resolved first. |

---

## Prerequisite Graph

```
Issue 1 (Info.plist version) — no prereqs, fix immediately
Issue 2 (restart_app.sh) — no prereqs, fix immediately
Issue 3 (CI model download) — no prereqs, fix next
Issue 4 (SwiftLint in CI) — after Issue 3
Issue 5 (DictationError public) — no prereqs, fix anytime
Issue 6 (nonisolated(unsafe) comment) — no prereqs, fix anytime
Issue 7 (.gitignore cleanup) — no prereqs, fix anytime
Issue 8 (silence trim tracking) — no prereqs, fix anytime
Issue 9 (permission polling UX) — optional, no prereqs
Issue 10 (UI tests) — after Issues 3+4
```

---

## Triage Summary

| Priority | Issues | Estimated Effort |
|---|---|---|
| Fix before next release | Issues 1, 2 | < 30 min |
| Fix before major expansion | Issues 3, 4, 5, 6, 7, 8 | ~3–4 hours |
| Optional / future | Issues 9, 10 | Days |
