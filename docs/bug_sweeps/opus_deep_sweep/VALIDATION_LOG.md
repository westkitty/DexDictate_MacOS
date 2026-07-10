# Opus Deep Sweep — Validation Log

No source files were modified this sweep (no confirmed bugs). Validation therefore
re-confirms the baseline is clean and that the built/installed app is current.

## Build & test

| Check | Command | Result |
|---|---|---|
| Compile | `swift build` | PASS — clean (only pre-existing `fluidaudio` unhandled-resource warning) |
| Full test suite | `swift test` | PASS — **417 tests, 0 failures** (4.9s) |
| Release build + codesign + install | `./build.sh` | PASS — exit 0, `Build complete!`, signed with `DexDictate Development`, installed to `/Applications/DexDictate.app` |
| App present | `ls ~/Applications/DexDictate.app` | PASS — bundle present |

Targeted filters were not re-run in isolation because the full suite (which includes all of
them) passed with 0 failures and no source changed. For reference the relevant suites all
passed inside the full run: `WhisperModelCatalogTests` (8/8), `ModelSelectionActionsTests`,
`SmartCleanupTests`, `LivePreviewInvariantTests`, `SecureInputContextTests`,
`ClipboardManagerTests`, `OutputCoordinatorTests`, `AudioRecorderRecovery*`,
`AudioTapInstallerTests`, `ProfileContentTests`, `TranscriptionHistoryTests`,
`MainActorActionTests`.

## Static checks

| Check | Result |
|---|---|
| `git diff --stat` (source) | Empty — no source/test/package changes this sweep |
| `@AppStorage`/`UserDefaults` key changes | None |
| `smartCleanupEnabled` default | `false` (`SmartCleanupSettings.swift:13`) |
| `livePreviewEnabled` default | `false` (`AppSettings.swift:179`) |
| `useExperimentalStateFirstUI` reappearance | None — dead key behind `showLegacyExperimentalUICard = false`, unreachable UI |
| `Base (Multilingual)` / `Small (Multilingual)` labels | Present (`WhisperModelCatalog.swift:163`) — BUG-007 intact |
| TODO/FIXME/HACK/XXX in Sources | None |
| Dead buttons / empty actions | None found |
| `fatalError`/`try!`/`preconditionFailure` in Sources | None |
| Stray `print(` in release paths | Only `#if DEBUG`-guarded (`PermissionManager.swift`) and the `VerificationRunner` CLI tool — not release UI paths |

## Known flaky allowance
`MainActorActionTests.testRunAsyncExecutesOnMainActor` is documented flaky under CPU load. It
passed in the baseline full run this sweep; no rerun was needed.

## Not performable in this environment (unchanged blocker)
Live speech, microphone capture, menu-bar popover click-through, and HUD interaction cannot
be exercised headlessly (LSUIElement + accessibility, the same blocker documented in every
prior packet). These are enumerated in `FINAL_DONE_GATE.md` for Andrew.
