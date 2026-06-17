# Codex Implementation Prompt — DexDictate Audit Remediation

## Context

You are working in the DexDictate_MacOS repository at `/Users/andrew/Projects/DexDictate_MacOS`.

A forensic engineering audit was recently completed and produced four reference documents in the repository root:

- `AUDIT_DEXDICTATE.md` — Full architecture and bug sweep report
- `DEXDICTATE_FILE_MAP.md` — Structured file and directory inventory
- `DEXDICTATE_FEATURE_MATRIX.md` — Feature status matrix
- `DEXDICTATE_FIX_PLAN.md` — Prioritized remediation plan (10 issues)
- `DEXDICTATE_READINESS.md` — Readiness assessment

Your job is **not** to trust the audit blindly. Your job is to:

1. Read the audit documents.
2. For each issue in `DEXDICTATE_FIX_PLAN.md`, **independently verify** it by reading the actual source files cited.
3. For each issue, determine whether you **agree** or **disagree** with the finding, and state why.
4. Implement fixes **only for issues you independently confirm are real**.
5. If you disagree with a finding, document your reasoning and skip that fix.

Do not guess. Do not implement changes based on the audit alone without reading the cited files first.

---

## Phase 1 — Read the Audit Documents

Start by reading these four files in full:

```
DEXDICTATE_FIX_PLAN.md
AUDIT_DEXDICTATE.md
DEXDICTATE_FILE_MAP.md
DEXDICTATE_READINESS.md
```

Build a mental model of what the audit claims before doing any verification.

---

## Phase 2 — Independent Verification of Each Issue

For each of the 10 issues in `DEXDICTATE_FIX_PLAN.md`, perform the following verification protocol:

### Issue 1 — `Info.plist` Minimum OS Version Mismatch

**To verify:**
1. Read `Sources/DexDictate/Info.plist` and locate `LSMinimumSystemVersion`.
2. Read `Package.swift` and locate the `platforms` declaration.
3. Read `templates/Info.plist.template` if it exists and check the same field.

**Confirm or deny:** Does `Info.plist` declare a different minimum OS than `Package.swift` requires?

---

### Issue 2 — `restart_app.sh` References Removed App Name

**To verify:**
1. Read `restart_app.sh` in full.
2. Check whether the app name `DexDictate_V2` appears in any active build output, `build.sh`, or installed `.app` paths.
3. Run: `ls ~/Applications/ 2>/dev/null` and `ls /Applications/ 2>/dev/null` to see what app names are installed.

**Confirm or deny:** Does `restart_app.sh` reference an app name that does not exist in the current build system?

---

### Issue 3 — CI Does Not Fetch Model Before Running Tests

**To verify:**
1. Read `.github/workflows/ci.yml` in full.
2. Read `Tests/DexDictateTests/ResourceBundleTests.swift` in full.
3. Read `scripts/fetch_model.sh` to understand what it does.
4. Check whether `tiny.en.bin` is present at `Sources/DexDictateKit/Resources/tiny.en.bin`.
5. Determine: Would `ResourceBundleTests` pass on a clean GitHub Actions runner that does not have the model?

**Confirm or deny:** Does CI lack a model-download step that is required for the test suite to pass?

---

### Issue 4 — SwiftLint Not Run in CI

**To verify:**
1. Read `.github/workflows/ci.yml` in full (you may have already done this above).
2. Read `.swiftlint.yml` to confirm it is a real, non-empty configuration.
3. Check whether any CI step invokes `swiftlint`.

**Confirm or deny:** Is SwiftLint configured but absent from CI?

---

### Issue 5 — `DictationError` Is Internal, Not Public

**To verify:**
1. Read `Sources/DexDictateKit/Models/DictationError.swift` in full.
2. Check the access modifier on the `enum DictationError` declaration.
3. Search all test files for any reference to `DictationError` to understand whether tests currently need it to be public.
   - Run: `grep -r "DictationError" Tests/`
4. Search the `DexDictate` UI target for usages:
   - Run: `grep -r "DictationError" Sources/DexDictate/`

**Confirm or deny:** Is `DictationError` declared internal in a public library target, and would making it public be additive and non-breaking?

---

### Issue 6 — `nonisolated(unsafe)` in AudioRecorderService Needs Better Documentation

**To verify:**
1. Read `Sources/DexDictateKit/Services/AudioRecorderService.swift` in full.
2. Locate the `nonisolated(unsafe)` declarations.
3. Read the existing comments around them.
4. Assess: Is the thread-safety invariant clear enough for a new contributor, or is it under-documented?

**Confirm or deny:** Is additional documentation warranted at these declarations?

---

### Issue 7 — Untracked Generated Files Not in .gitignore

**To verify:**
1. Run: `git status --short 2>/dev/null | grep '^??' | head -20`
2. Read `.gitignore` in full.
3. Confirm which of `output/`, `.tmp_onboarding_review/`, `.venv*/`, `assets/` are untracked and not gitignored.

**Confirm or deny:** Are there untracked generated directories that should be gitignored?

---

### Issue 8 — Silence Trim Redesign Has No Formal Tracking

**To verify:**
1. Read `Sources/DexDictateKit/ExperimentFlags.swift` in full.
2. Read `docs/DexDictate_Strict_Experiment_Matrix.md` if it exists.
3. Check whether the silence trim limitation is documented anywhere beyond the inline code comment.

**Confirm or deny:** Is the silence trim redesign requirement tracked only in a source code comment with no external reference?

---

### Issue 9 — Permission Polling Latency

**To verify:**
1. Read `Sources/DexDictateKit/Permissions/PermissionManager.swift` in full.
2. Locate the polling timer setup.
3. Assess whether adding an `NSApplicationDidBecomeActiveNotification` trigger would be safe and straightforward.

**Confirm or deny:** Is this a real UX latency issue, and is the proposed fix appropriate?

---

### Issue 10 — No UI Test Harness

**To verify:**
1. Run: `find Tests/ -name "*.swift" | xargs grep -l "XCUITest\|XCUIApplication\|ViewInspector" 2>/dev/null`
2. Confirm there are no UI tests.

**Confirm or deny:** Is there genuinely no UI test infrastructure?

---

## Phase 3 — Verification Report

Before implementing any fixes, write a verification report to a file called `CODEX_VERIFICATION_REPORT.md` in the repository root.

For each issue, write a section in this format:

```markdown
## Issue N — [Title]

**Audit claim:** [1-sentence summary of what the audit said]
**Files inspected:** [list every file you read to verify]
**Finding:** CONFIRMED | DISPUTED | PARTIAL
**Evidence:** [what you actually saw in the code]
**Action:** WILL FIX | WILL SKIP | NEEDS DISCUSSION
**Reason (if skipping or disputing):** [explain]
```

Do not implement any fixes until this file is written.

---

## Phase 4 — Implementation

Implement fixes for every issue marked `WILL FIX` in your verification report.

Follow these rules for each fix:

### Fix 1 — Info.plist OS minimum (if confirmed)

**Files to edit:**
- `Sources/DexDictate/Info.plist`
- `templates/Info.plist.template` (if it contains the same field)

**Change:** Update `LSMinimumSystemVersion` value from `13.0` to `14.0` in both files.

**Verify after:** `grep -n "LSMinimumSystemVersion" Sources/DexDictate/Info.plist templates/Info.plist.template`

---

### Fix 2 — restart_app.sh (if confirmed)

**Preferred action:** Delete the file.
- Run: `git rm restart_app.sh`

**If you prefer to update instead of delete:** Replace both occurrences of `DexDictate_V2` with `DexDictate`.

**Do not delete** if you find evidence that the script is referenced from any documentation, Makefile, or CI step. In that case, update only.

**Verify after:** `cat restart_app.sh 2>/dev/null || echo "deleted"`

---

### Fix 3 — CI model download (if confirmed)

**File to edit:** `.github/workflows/ci.yml`

**Change:** Add a step between the checkout step and the test step that downloads the model:

```yaml
      - name: Fetch Whisper model
        run: bash scripts/fetch_model.sh
```

Place it immediately before the `Run tests` step and after the `Build` step.

**Reason to place after build:** The build step confirms the Swift package compiles correctly; the model is only needed for test execution.

**Verify after:** Display the updated workflow file with `cat .github/workflows/ci.yml`.

---

### Fix 4 — SwiftLint in CI (if confirmed)

**File to edit:** `.github/workflows/ci.yml`

**Change:** Add a SwiftLint step. Insert it after the Build step and before the test step:

```yaml
      - name: Lint
        run: |
          if command -v swiftlint &>/dev/null; then
            swiftlint --strict
          else
            brew install swiftlint && swiftlint --strict
          fi
```

**Note:** If Issue 3 fix was also applied, the order should be: Build → Lint → Fetch model → Test.

**Verify after:** `cat .github/workflows/ci.yml`

---

### Fix 5 — Make DictationError public (if confirmed)

**File to edit:** `Sources/DexDictateKit/Models/DictationError.swift`

**Change:** Add `public` to the `enum DictationError` declaration and to each `case`. Example:

```swift
public enum DictationError: LocalizedError, Equatable {
    case microphoneAccessDenied
    case audioEngineSetupFailed(String)
    case inputDeviceError
    case unknown(String)
    ...
}
```

**Verify after:** `grep -n "public\|enum DictationError" Sources/DexDictateKit/Models/DictationError.swift`

**Then run:** `swift build 2>&1 | tail -20` to confirm nothing breaks.

---

### Fix 6 — Document nonisolated(unsafe) invariant (if confirmed)

**File to edit:** `Sources/DexDictateKit/Services/AudioRecorderService.swift`

**Change:** Above the `nonisolated(unsafe)` declarations, add or expand the existing comment block to explicitly state:

- Why `nonisolated(unsafe)` is required here
- The invariant that must be maintained: all access to these properties MUST occur on `audioQueue`
- The consequence of violating the invariant: data race, undefined behavior
- A note for future contributors: if adding methods that access `engine` or `_accumulatedSamples`, they must dispatch to `audioQueue` first

Do **not** change any functional code. Comments only.

**Verify after:** Read the modified section of the file.

---

### Fix 7 — .gitignore cleanup (if confirmed)

**File to edit:** `.gitignore`

**Change:** Read `.gitignore` first. Then append only the entries that are missing. Do not duplicate existing entries.

Candidates to add (only add if confirmed untracked and not already gitignored):
```
output/
.tmp_onboarding_review/
.venv*/
```

Do **not** add `assets/` without confirming it is not intentionally tracked. Check `git ls-files assets/` first.

**Verify after:** `git status --short | grep "^??" | head -20`

---

### Fix 8 — Document silence trim in experiment matrix (if confirmed)

**File to edit:** `docs/DexDictate_Strict_Experiment_Matrix.md`

**Change:** Add a row or section documenting the silence trim status. Include:
- Feature name: Leading Silence Trim
- Current state: Disabled (`ExperimentFlags.enableSilenceTrim = false`)
- Reason disabled: Noise-floor estimator samples first ~500ms of audio (which is speech in hold-to-talk mode), inflating the threshold and clipping sentence onsets
- Prerequisite to re-enable: Redesign with a pre-trigger calibration window
- Where it lives: `ExperimentFlags.swift`, `AudioResampler.trimSilenceFast()`

Do not modify the format of the existing document — match whatever structure is already present.

**Verify after:** Read the updated file.

---

### Fix 9 — Permission polling improvement (if confirmed and you judge it safe)

**File to edit:** `Sources/DexDictateKit/Permissions/PermissionManager.swift`

**Change:** Add a call to `refreshPermissions()` in response to `NSApplicationDidBecomeActiveNotification`.

This is an additive change. The 2-second timer stays. The notification just triggers an immediate re-check when the user switches back to the app (the most common moment after granting a permission in System Settings).

**Only make this change if:**
1. You confirm `refreshPermissions()` is safe to call from the main thread
2. You confirm the existing 2-second timer is still running alongside the notification handler
3. The change is fewer than 10 lines

If any of those conditions are unclear, skip this fix and mark it `NEEDS DISCUSSION` in your report.

---

### Fix 10 — UI tests (if confirmed)

**Action:** Do **not** implement a full UI test harness as part of this task. The effort is non-trivial and requires design decisions beyond scope.

Instead: Add a single comment in `.github/workflows/ci.yml` noting the gap:

```yaml
      # UI tests: not yet implemented. See DEXDICTATE_FIX_PLAN.md Issue 10.
```

Place it after the test step.

Mark this issue `WILL SKIP (documented)` in your verification report.

---

## Phase 5 — Post-Fix Validation

After all fixes are applied, run:

```bash
swift build 2>&1
```

If the build fails, diagnose and fix the failure before proceeding.

Then run:

```bash
swift test 2>&1
```

Record the result. If tests fail:
- If the failure is in `ResourceBundleTests` and is clearly a missing-model issue (not a code issue), note it in your report and do not treat it as a regression from your changes.
- If the failure is in any other test, investigate and fix it before finishing.

---

## Phase 6 — Final Summary

After all fixes and validation, write a brief final section to `CODEX_VERIFICATION_REPORT.md`:

```markdown
## Implementation Summary

- Issues confirmed: N
- Issues disputed: N  
- Issues skipped: N
- Fixes applied: [list each file changed]
- Build result: PASS | FAIL (with reason)
- Test result: PASS | FAIL (with reason)
- Rollback command: git reset --hard HEAD~N  (N = number of commits made)
```

---

## Constraints

- Do not refactor any code beyond what is explicitly listed above.
- Do not add features, restructure files, or rename symbols beyond what is in scope.
- Do not modify any test file unless you are fixing a compilation error caused by your own changes (e.g., `DictationError` now being public may require updating a test import — that is in scope).
- Do not commit anything. Leave changes staged or unstaged — the user will review and commit.
- If you encounter a situation where a fix would require understanding beyond what the cited files provide, stop and note it in the verification report rather than guessing.

---

## Starting Point

Begin with Phase 1. Read the audit documents. Then proceed in order through verification, report writing, implementation, and validation.

Do not skip phases. Do not implement before verifying.
