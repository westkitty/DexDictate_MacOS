# Legacy Branch Audit — 2026-08-01

This audit maps every branch tip and unique commit reviewed for the consolidation into current `main`. Archive tags preserve original trees independently of the final integration strategy.

## Preservation Tags

| Archive tag | Peeled commit |
|---|---|
| `archive/speech-engine-exploration-benchmarks-2026-08-01` | `69c6533c4e5dd97ff146781c3d050ac79d8f17c0` |
| `archive/dexdictate-reversible-insertion-2026-08-01` | `0c47bbb9a49712742977a6e39724a3567f3b5f0a` |
| `archive/nifty-wilson-2026-08-01` | `977b625b40a498c08e50ecdff964336ddc6898d2` |
| `archive/remotion-runner-2026-08-01` | `1bfd3336a5f91493a9ee348b14e4954e0ec018ea` |
| `archive/v1-5-release-prep-2026-08-01` | `233ca17a3fe0c4a350ae1b7eb8e79d7e8d0e5a57` |
| `archive/audio-import-custom-commands-2026-08-01` | `7701b6ff10ee8d6f1784d72aa007667ca6b56c52` |
| `archive/unwanted-popup-hud-2026-08-01` | `bb2bf5a5e257aa31517b5ec5f04d8a301707933c` |

## Reversible Insertion

Disposition: normal merge. The branch is based on current `main`, merges cleanly, and its GitHub lint/build/test checks passed.

- `393e1c41` — reversible dictation with verification-gated undo
- `8184b532` — split output support types and keep lint debt bounded
- `e77bf8e6` — temporary baseline-generation instrumentation
- `0c47bbb9` — corrected final SwiftLint baseline; temporary instrumentation removed

## Speech Engine / UI Recovery

Disposition: normal ancestry merge with `.resurrection` restored from current `main`; archive the two planning documents and screenshot evidence under `docs/archive/`.

- `55e65de8` — Fable UI/UX recovery plan, Sonnet handoff, screenshot packet
- `8bef929a` — generated recovery inventory refresh
- `69c6533c` — generated recovery inventory rescan

The UI/UX execution campaign later completed through Packet 16 on `main`; archived documents are provenance, not current executor instructions.

## Nifty Wilson

Disposition: ancestry-only merge plus selective port of spoken punctuation. Current implementations win.

| Commit | Capability | Current disposition |
|---|---|---|
| `ad39dda4` | trailing silence trim | superseded by current calibrated trailing trim |
| `2180672b` | trailing trim settings cleanup | superseded by current settings/default coverage |
| `f48bba0e` | opt-in onset trim | preserved in history; not re-enabled because current safety doctrine documents clipping risk |
| `16c36cef` | onset calibration correction | preserved in history with the disabled experiment |
| `1af3aeda` | Whisper warm-up | superseded by current warm-up implementation |
| `672ec24e` | spoken punctuation commands | port into current `CommandProcessor` |
| `e084fe87` | focused-field context prompt | superseded by `DictationAssist`/current context injection |
| `80fa492c` | Accessibility insertion | superseded by current hardened output path |
| `f6e83ea6` | suspect-result retry affordance | superseded by current accuracy retry and automatic suspicious-result retry |
| `b3959ab9` | persistent history | superseded by `HistoryPersistenceManager` |
| `c2ae6cd4` | shortcut conflict detection | superseded by `TriggerShortcutConflictChecker` and eight focused tests |
| `873d9ef7` | waveform/partial transcript HUD | superseded by current live caption and preview surfaces |
| `39839d6c` | waveform trigger/fade repair | superseded with the prior HUD implementation |
| `10c70de7` | seven-issue bug sweep | retained in ancestry; current main has later comprehensive sweeps |
| `dfd445d7` | clickable onboarding permission rows | retained in ancestry; current onboarding/permission owners win |
| `460b115a` | tutorial/action/trigger/onboarding UI | retained in ancestry; current Settings/popover campaign wins |
| `5cdc5415` | event-tap callback and benchmark styling | retained in ancestry; current InputMonitor and benchmark owners win |
| `e0b8cd7f` | one-issue bug sweep | retained in ancestry; current main wins |
| `977b625b` | benchmark corpus and GUI flavor | retained in ancestry; current benchmark corpus/UI wins |

## Audio Import / Custom Commands / Per-App Insertion

Disposition: ancestry-only merge for Swift changes; extract the unique React prototype under `prototypes/dexdictate-ux/`.

- `c0e28d5a` — audio import, commands, per-app insertion, silence trim
- `2c277964` — UI/UX overhaul
- `b5c7dcc8` — restore missing features after overhaul
- `32fb66db` — trigger mode and popover cleanup
- `7701b6ff` — UX prototype and install-path hardening

Current `main` contains the production Swift features and files, initially consolidated in `7685ad4b` and later hardened. The prototype is the unique artifact.

## Remotion Runner

Disposition: ancestry-only merge; relocate the complete Node project and its reference material under `marketing/remotion/`.

- `1bfd3336` — Remotion animation pipeline

The branch's `.claude` and `.codex` symlinks are not maintained runtime artifacts and will not be installed into the project root.

## v1.5 Release Preparation

Disposition: ancestry-only merge with current tree retained.

- `bf3db389` — v1.5 release preparation; obsolete after v1.8.0
- `65183a62` — patch-equivalent behavior already present on `main`
- `233ca17a` — patch-equivalent launch-intro repair already present on `main`

## Unwanted Popup HUD

The local branch tip is exactly current `origin/main` (`bb2bf5a5`). Its implementation is already the canonical main tree; only its dirty worktree recovery state needs preservation before final branch cleanup.
