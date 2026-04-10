# DexDictate Readiness Assessment

**Audit date:** 2026-04-10
**Version:** 1.5.2
**Question:** Is this repository structurally safe to keep building on?

---

## Verdict

**Yes. DexDictate is structurally sound and safe to continue building on.**

This is not a generic endorsement. It is a conclusion grounded in direct source inspection of 95+ Swift files, 25 test files, 242-line build script, CI configuration, Package manifest, entitlements, resource bundle, and supporting documentation.

---

## Evidence Supporting Readiness

### Architecture

The codebase has a coherent hub-and-spoke architecture. `TranscriptionEngine` is the central coordinator. All pipeline subsystems (`AudioRecorderService`, `WhisperService`, `OutputCoordinator`, `CommandProcessor`, `VocabularyManager`) attach cleanly with narrow interfaces.

The library target (`DexDictateKit`) and the app target (`DexDictate`) are properly separated. The UI imports the library; the library does not import the UI. This seam is structurally sound and supports future extension without architectural debt.

### Code Quality

- Zero TODO/FIXME/HACK markers in active source
- Explicit engine lifecycle state machine with all transitions logged and validated
- Protocol-based injection for output coordination (testable without OS dependencies)
- Thread model is explicit: `@MainActor` for UI, dedicated `audioQueue` for audio, comments documenting invariants
- No commented-out code blocks, no debugging print statements left in source

### Testing

25 unit test files cover core logic paths:
- Engine lifecycle state machine (all transitions)
- Command processor (hotwords, scratch, caps, newline)
- Vocabulary layering (bundled + custom merge, priority, deduplication)
- Permissions (polling, state, recovery)
- Output coordinator (delivery mode selection, context detection)
- Settings migration (schema upgrades)
- Safe mode (snapshot/restore)
- History (cap at 50, undo/restore)

VerificationRunner provides an additional 8 verification paths including fuzz testing (200 random command combinations) and online/offline validation (Black Path confirms no URLSession/Alamofire present).

### Security

- No network calls in runtime path (confirmed by source inspection and VerificationRunner Black Path)
- No telemetry or analytics
- No hardcoded credentials or secrets
- Explicit OS permission model (mic, accessibility, input monitoring)
- Sensitive context detection (password fields) with automatic copy-only fallback
- Third-party security audit completed and documented in `SECURITY_AUDIT_REPORT.md`

### Build Reproducibility

- Swift Package Manager with pinned SwiftWhisper dependency (specific commit hash)
- `Package.resolved` lockfile for deterministic builds
- Canonical `build.sh` (242 lines) with architecture validation, bundle assembly, code signing, and optional release packaging
- `scripts/validate_release.sh` for post-build artifact verification

---

## Exact Blockers That Exist

There are **no blockers** to continued development. There are five hygiene items that should be addressed before significant new features ship, but none of them prevent work from starting.

---

## Minimum Viable Cleanup Required First

These five items should be completed before major new development begins. Combined estimated effort: half a workday.

### 1. Fix Info.plist OS minimum version (30 min)
- **File:** `Sources/DexDictate/Info.plist`, line 22
- **Change:** `13.0` → `14.0`
- Also update `templates/Info.plist.template` to match
- **Why:** Package.swift requires `.macOS(.v14)`. Info.plist advertising 13.0 is misleading and creates false compatibility expectations.

### 2. Fix or delete restart_app.sh (10 min)
- **File:** `restart_app.sh`
- **Change:** Delete the file, or replace `DexDictate_V2` with `DexDictate` in both references
- **Why:** Script is completely nonfunctional. References an app name that no longer exists. New contributors will be confused.

### 3. Fix CI to fetch model before testing (1 hour)
- **File:** `.github/workflows/ci.yml`
- **Change:** Add `run: bash scripts/fetch_model.sh` step before `swift test -v`
- **Why:** `ResourceBundleTests` validates presence of `tiny.en.bin`. CI runners don't have the model. Tests may silently fail or skip. CI is not trustworthy until this is resolved.

### 4. Add SwiftLint to CI (30 min)
- **File:** `.github/workflows/ci.yml`
- **Change:** Add `brew install swiftlint && swiftlint --strict` step
- **Why:** `.swiftlint.yml` exists and is configured. Without CI enforcement, lint violations accumulate silently.

### 5. Add .gitignore entries for untracked generated files (15 min)
- **File:** `.gitignore`
- **Change:** Add `output/`, `.tmp_onboarding_review/`, `.venv*/`
- **Why:** These untracked directories add noise to `git status` and risk accidental commit of 157MB of generated files.

---

## What Should Be Stabilized Before Adding Major New Features

**Current stable foundation (do not change without careful planning):**

| Subsystem | Why It's Load-Bearing |
|---|---|
| `TranscriptionEngine` state machine | All pipeline behavior routes through it; changing state definitions cascades everywhere |
| `AudioRecorderService` threading model | `nonisolated(unsafe)` + `audioQueue` invariant; breaking this causes data races |
| `PermissionManager` polling | Engine recovery depends on exact callback timing |
| `AppSettings` @AppStorage keys | Changing key names requires `SettingsMigration` entries or user data loss |
| `OutputCoordinator` protocol | Tests mock this interface; changing it breaks test isolation |

**Before adding a new major feature, verify:**
1. The new feature does not need to touch `TranscriptionEngine` state transitions (if it does, update `EngineLifecycle.swift` explicitly and add tests)
2. Any new audio operations go on `audioQueue` (not main thread or a new queue)
3. Any new settings use versioned `@AppStorage` keys and add a migration entry if renaming existing keys
4. Any new output mode goes through `OutputCoordinator` (not direct clipboard calls from the engine)

---

## What Is Safe to Build Right Now

All of the following can be started immediately without risk:

- New UI views or settings panels (add to `Sources/DexDictate/`, bind to existing `AppSettings`)
- New voice commands (add cases to `CommandProcessor.swift` + tests)
- New vocabulary packs (add to `BundledVocabularyPacks.swift`)
- New output delivery modes (implement `OutputCoordinating` protocol variants)
- New benchmarking modes (extend `ModelBenchmarking.swift` + `VerificationRunner`)
- New App Intents (add to `DictationIntents.swift`)
- New profile packs (add to `AppProfile.swift` + `ProfileManager.swift`)
- Documentation improvements
- Additional tests for any existing subsystem

---

## Final Answer

**DexDictate is production-quality, architecturally sound, and safe to build on.** The five cleanup items above are real issues but none of them are architectural defects. Fix them as soon as practical, then proceed with confidence.

The codebase is coherent, well-tested, has a clean module structure, and has explicit documentation of every known limitation. Another engineer can read the source and understand what is happening within a few hours. That is the correct standard for a buildable foundation.
