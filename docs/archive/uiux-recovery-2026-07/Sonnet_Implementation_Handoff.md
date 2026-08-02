# DexDictate Claude Sonnet Implementation Handoff Pack

**Author:** Fable 5 (handoff pass — no implementation performed, no tests run in this pass)
**Date:** 2026-07-09
**Plan of record:** `DexDictate_Fable5_UIUX_Recovery_Plan.md` (repo root). This pack converts that plan into paste-ready executor prompts. It does not redesign the strategy.
**Executor:** Claude Sonnet (Claude Code), one packet per session, no memory assumed between packets.

---

## 1. Executive Summary for Sonnet

**What is being fixed.** DexDictate has a strong, tested dictation engine buried under a failing UI: a menu-bar popover that hosts an entire preferences app as folding cards, power features hidden in wrong groups (Vocabulary under Input; Accuracy Retry under Benchmark → Optimization), settings listed below "Quit App", a giant red destructive button as the most prominent idle element, expert benchmark machinery inside the daily popover, and a duplicate experimental UI path. The fix is **relocation, not redesign**: build a real 11-page macOS Settings window, move existing controls into it one domain at a time, then slim the popover to a daily-use surface, then consolidate terminology, then polish.

**What must be preserved.** Every existing capability (see the Feature Preservation Map in the plan of record, Section 15), the entire audio/transcription/output engine untouched, and the Dexter identity layer intact: launch animation, onboarding wizard, RSS-style ticker, randomized watermarks, regional profiles, quote packs, bundled MP4/PNG assets. Local batch Whisper remains the committed-output authority forever; Parakeet is not solved live transcription; remote Ollama is post-processing cleanup, never live ASR.

**First safe packet:** Packet 01 — Baseline Freeze (zero source edits).

**Gated until later, each behind explicit approval from Andrew:**
- Packet 12B (Experimental UI retirement) — gated on the Packet 12A adoption inventory sign-off.
- Packet 13 (Smart Cleanup / Ollama) — gated on Settings shell + migration packets (02–08) merged and taxonomy approved.
- Packet 14 (Live Preview prototype) — gated on separate explicit approval; engine-adjacent; runs alone; recommended last of all.

**Why packetized.** The known failure mode is "one big refactor branch": UI moves entangled with engine risk, features silently lost, Dexter quietly flattened. Small packets keep every change reviewable, testable against the feature-loss checklist, and one `git revert` from safety. Sonnet must never combine packets, never improvise scope, and must stop-and-report rather than push through ambiguity.

---

## 2. Current Branch and Repo Rules

- **Repo path:** `/Users/andrew/DexDictate_MacOS.nosync`
- **Branch:** `speech-engine-exploration-benchmarks` (all packets run on this branch; do not create side branches unless Andrew asks)
- **Build:** `swift build` (SPM); app build/install: `./build.sh` (builds release, codesigns, installs to `~/Applications/DexDictate.app`)
- **Tests:** `swift test` (baseline: 382 passing, 0 failures; `MainActorActionTests.testRunAsyncExecutesOnMainActor` is known-flaky under CPU load — rerun once before judging a solo failure there)

**Required initial git checks (every packet, before any edit):**

```bash
cd /Users/andrew/DexDictate_MacOS.nosync
git rev-parse --abbrev-ref HEAD        # must print: speech-engine-exploration-benchmarks
git status --porcelain                  # inspect; see allowed-dirty list below
git log --oneline -3                    # record starting commit in the final report
```

**Preservation commit expectations:** baseline safety tag `pre-fable-audit-20260709-0222` and commit `9eea598f` exist. Packet 01 adds tag `pre-uiux-refactor`. Never rewrite history; never force-push.

**If the working tree is dirty:** the following are *expected* dirt and must be ignored (never staged, never reverted): modified `.resurrection/*` (background scanner metadata), untracked `pre_fable/`, untracked or modified `DexDictate_Fable5_UIUX_Recovery_Plan.md` / `DexDictate_Sonnet_Implementation_Handoff.md` until Andrew commits them, untracked `docs/refactor_baseline/` from earlier packets. **Any other uncommitted change to `Sources/`, `Tests/`, `Package.swift`, `Package.resolved`, scripts, or bundled assets that this packet did not make → STOP and report; do not proceed, do not stash, do not clean.**

**Files that must never be staged:** `.resurrection/`, `pre_fable/`, `.build/`, `SNAPSHOT/`, `baseline.csv`, `benchmark_baseline.json`, any `*.log` outside `docs/refactor_baseline/`. **Never run `git add -A` or `git add .` — stage only explicit paths you changed.**

---

## 3. Global Implementation Rules

These apply to every packet and are restated inside each packet prompt.

**Hard boundaries:**
1. Do not delete existing features. 2. Do not rewrite the app from scratch. 3. Do not change the audio engine unless the packet is explicitly engine-adjacent-approved. 4. Do not change transcription commit behavior unless explicitly approved. 5. Do not touch fragile files unless the packet explicitly allows it. 6. Do not remove Dexter identity features. 7. Do not remove or alter bundled Dexter images/videos, quote packs, regional profile assets, ticker behavior, launch animation, onboarding wizard, randomized watermarks, or profile systems. 8. Do not hard-code BigMac / westcat / port 11435 as universal behavior (examples in help text only). 9. Do not introduce an agent framework. 10. Do not make cloud inference mandatory. 11. Do not treat Parakeet as solved live transcription. 12. Do not conflate live ASR with remote Ollama smart cleanup. 13. Do not combine packets. 14. Do not continue if git state is unsafe. 15. Do not push if tests fail, unless the failure is documented as pre-existing and Andrew explicitly approves.

**Global fragile / forbidden files** (read-only inspection allowed; modification forbidden unless the packet explicitly allows the named file):

```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```

Also globally forbidden: deleting or altering bundled MP4/PNG Dexter assets; changing any `@AppStorage`/UserDefaults **storage key** (display strings may change in Packet 10; keys never change without a `SettingsMigration.swift` packet that does not exist in this pack).

**Global stop conditions — Sonnet must stop and report instead of proceeding if:**
- The repo is not on `speech-engine-exploration-benchmarks`.
- `.git` is missing or the path is not a git repository.
- The branch has uncommitted `Sources/`/`Tests/`/`Package.*`/asset changes unrelated to the packet (beyond the allowed-dirty list in Section 2).
- `Package.swift`, `Package.resolved`, or bundled assets appear changed unexpectedly in `git diff`.
- `swift test` fails in a way not present in the Packet 01 baseline log.
- The implementation turns out to require touching a forbidden file.
- Required screenshots cannot be captured (finish the code work, do NOT push, report "blocked on screenshots").
- A migration would require changing a storage key.
- A UI relocation reveals behavior hidden inside a view's `onAppear`/`task`/`onDisappear`/timer/observer lifecycle (report the file, the behavior, and a proposed extraction — do not move the view).

---

## 4. Packet Execution Protocol

Every packet follows this exact sequence:

1. **Inspect repo state** — run the Section 2 git checks; verify allowed-dirty only.
2. **Confirm branch** — `speech-engine-exploration-benchmarks`, else stop.
3. **Inspect relevant files** — read every file in the packet's "files likely touched" and "required inspection" lists before editing anything.
4. **Restate packet scope** — in your own words, list what you will and will not do; if your restatement conflicts with the prompt, stop.
5. **Implement only the packet** — no drive-by fixes, no opportunistic refactors, no renames outside scope.
6. **Formatting/checks** — match surrounding code style; no new dependencies; no new warnings if avoidable.
7. **`swift build`** — must succeed.
8. **`swift test`** — zero new failures vs the Packet 01 baseline log (`docs/refactor_baseline/packet_01/swift_test.log`).
9. **Targeted tests** — run the packet's `--filter` list.
10. **Screenshots** — if UI changed: `./build.sh`, launch `open ~/Applications/DexDictate.app`, capture with `screencapture -x docs/refactor_baseline/packet_NN/<name>.png` for each required surface. If a state can't be reached without live speech or a first-run reset, list it in the report as "needs Andrew".
11. **Feature-loss checklist** — run the packet's rows from `DexDictate_Feature_Loss_Checklist.md`, plus the always-on rows: dictation loop works, ticker scrolls, watermarks rotate, launch animation plays.
12. **Inspect `git diff`** — read the full diff; confirm no forbidden file, no storage key, no asset, no `Package.*` change; confirm nothing from the never-stage list is staged.
13. **Commit** — explicit paths only, packet-specific message (given per packet), conventional-commit style.
14. **Push** — only if build + tests pass and the diff is clean. Otherwise stop and report.
15. **Final report** — use the template in Section 22, verbatim structure.

---

## 5. Packet Dependency Graph

```text
P01 Baseline Freeze
 └── P02 Settings Window Shell
      ├── P03 General + Appearance        ┐
      ├── P04 Dictation + Audio           │  independent of each other;
      ├── P05 Output + Per-App Rules      │  run ONE AT A TIME, any order
      ├── P06 Vocabulary + Commands       │  (recommended: 03→04→05→06→07)
      └── P07 Models/Accuracy + Benchmark ┘
           └── P08 Diagnostics + Recovery + Advanced   (needs 03–07 done:
                │                                       it empties & retires
                │                                       the Quick Settings stack)
                └── P09 Popover Slim-Down
                     └── P10 Terminology Sweep
                          ├── P11 Dexter & Personality
                          │    └── P12A Experimental Adoption Inventory
                          │         └── [GATE: Andrew signs inventory]
                          │              └── P12B Experimental Retirement   (GATED)
                          ├── [GATE: Andrew approves] P13 Smart Cleanup     (GATED;
                          │        earliest after P08; recommended after P10)
                          └── P15 Visual Polish
                               └── [GATE: Andrew approves] P14 Live Preview (GATED;
                                        engine-adjacent; runs alone; last)
```

Sequential spine: 01 → 02 → (03…07) → 08 → 09 → 10. After 10: 11, 12A, 15 in any order (one at a time). **Gated packets: 12B, 13, 14** — each requires a fresh, explicit, written approval from Andrew before Sonnet may start.

---

## 6. Claude Sonnet Prompt: Packet 01 — Baseline Freeze

--- BEGIN PACKET 01 PROMPT — paste everything between BEGIN and END to Sonnet ---

# Packet 01 — Baseline Freeze (docs/artifacts only, zero source edits)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate, a macOS menu-bar dictation app (SwiftUI + AppKit, Swift Package Manager). Execute only this packet. Do not improvise.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record (read-only, for rationale): `DexDictate_Fable5_UIUX_Recovery_Plan.md`
- The dictation engine works and is fully tested. This refactor will move UI surfaces only. This packet moves nothing — it records the "before" state.

## Hard rules
No feature deletions. No rewrites. No engine/audio/output changes. No Dexter removals (launch animation, onboarding wizard, ticker, watermarks, profiles, quote packs, bundled MP4/PNG assets). No storage-key changes. No agent frameworks. No hard-coded BigMac/westcat/11435. Parakeet is NOT solved live transcription. Do not combine packets. Do not continue on unsafe git state. Do not push failing tests.

## Forbidden files (this packet: ALL source files are forbidden — zero edits under `Sources/`, `Tests/`, `Package.*`, `scripts/`, assets)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
…plus every other file under `Sources/` and `Tests/` for this packet.

## Stop conditions
Stop and report (do not proceed) if: wrong branch; `.git` missing; uncommitted `Sources/`/`Tests/`/`Package.*`/asset changes exist beyond the allowed-dirty list (`.resurrection/*`, `pre_fable/`, the two Fable `.md` docs, `docs/refactor_baseline/`); `swift test` fails (record the failure — that IS the baseline, but flag it to Andrew before any later packet runs); you are tempted to edit any source file.

## Goal
Create a reproducible pre-refactor record: screenshots of every UI surface, a saved `swift test` log, and a safety tag.

## Steps
1. Git checks: `git rev-parse --abbrev-ref HEAD`, `git status --porcelain`, `git log --oneline -3`.
2. `mkdir -p docs/refactor_baseline/packet_01`
3. `swift test 2>&1 | tee docs/refactor_baseline/packet_01/swift_test.log` — record pass/fail counts. (Known-flaky: `MainActorActionTests.testRunAsyncExecutesOnMainActor` — if it alone fails, rerun once and note it.)
4. Build and launch the app: `./build.sh` then `open ~/Applications/DexDictate.app`.
5. Capture screenshots into `docs/refactor_baseline/packet_01/` using `screencapture -x <path>.png` with the target surface visible. Targets:
   - idle popover; post-dictation popover (needs a real dictation — if you cannot dictate, mark "needs Andrew")
   - every Quick Settings card expanded (Input, Output, Accuracy & Speed, Transcription Engines, Profiles & History, Appearance & System, Benchmarks & Corpus, Experimental UI) — one shot per card
   - History window; Custom Vocabulary editor; Voice Commands editor (`CustomCommandsSheet`); Per-App Insertion Rules window; Benchmark Capture window
   - Floating HUD (during recording if possible, else idle)
   - onboarding pages (only if reachable via the five-tap-version-string gesture without resetting app defaults — do NOT reset defaults)
   - experimental state-first popover and its Settings & History surface (enable via Quick Settings → Experimental UI; disable again afterward and verify the standard UI returns)
   - launch animation still (relaunch the app and capture during playback if timing allows)
6. Any target you cannot reach: list it in `docs/refactor_baseline/packet_01/NEEDS_ANDREW.md` with the reason. As supplementary evidence, note that `pre_fable/DexDictate_Fable5_Screenshot_Packet.zip` contains 59 pre-captured frames — reference it, do not duplicate it.
7. Tag: `git tag pre-uiux-refactor && git push origin pre-uiux-refactor` (tag only; ask nothing else of the remote).
8. Commit ONLY `docs/refactor_baseline/packet_01/` by explicit path. Never `git add -A`. Never stage `.resurrection/`, `pre_fable/`, `.build/`, `SNAPSHOT/`, `baseline.csv`, `benchmark_baseline.json`.

## Acceptance criteria
- Zero changes under `Sources/`, `Tests/`, `Package.*`, `scripts/`, assets (verify with `git diff --stat`).
- Test log saved; screenshot set covers all reachable targets; NEEDS_ANDREW.md lists the rest; tag pushed.

## Commit
`docs: packet 01 — UI/UX refactor baseline freeze (screenshots + test log)`
Push only if the diff contains exclusively `docs/refactor_baseline/packet_01/`.

## Rollback
`git revert` the commit and delete the tag (`git tag -d pre-uiux-refactor; git push origin :refs/tags/pre-uiux-refactor`). No other cleanup possible or needed.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 01 — Baseline Freeze
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests: n/a
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed: n/a (baseline)
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: 02 — Settings Window Shell
```

--- END PACKET 01 PROMPT ---

---

## 7. Claude Sonnet Prompt: Packet 02 — Settings Window Shell

--- BEGIN PACKET 02 PROMPT ---

# Packet 02 — Settings Window Shell (empty pages only; nothing migrates)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Sections 5, 6, 11.
- Prerequisite: Packet 01 committed (`docs/refactor_baseline/packet_01/` exists). If missing, stop.

## Hard rules
No feature deletions. No rewrites. No engine/audio/output changes. No Dexter removals or asset changes. No storage-key changes. No control migration in this packet — pages are placeholders only. Do not combine packets. Do not continue on unsafe git state. Do not push failing tests.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Also do not modify `QuickSettingsView.swift` in this packet (it stays fully intact and primary).

## Stop conditions
Global set (Section 3 of the handoff pack) plus: if adding the gear button requires restructuring the popover header beyond inserting one button, stop and report; if window hosting requires changes inside `DexDictateApp.swift` that alter MenuBarExtra/popover lifecycle behavior, stop and report with a proposal.

## Goal
A real macOS Settings window with sidebar navigation and 11 placeholder pages, opened from a new gear button in the popover header (and ⌘, if cleanly attachable). Old UI untouched and still primary.

## Files likely touched
- NEW: `Sources/DexDictate/SettingsWindow/SettingsWindowController.swift` (or equivalent following the repo's existing detached-window pattern), `SettingsSidebar.swift`, and 11 stub page files: `GeneralSettingsPage.swift`, `DictationSettingsPage.swift`, `AudioSettingsPage.swift`, `OutputSettingsPage.swift`, `VocabularyCommandsPage.swift`, `ModelsAccuracyPage.swift`, `SmartCleanupPage.swift` (placeholder saying "Not configured — coming later"), `HistorySettingsPage.swift`, `DexterPersonalityPage.swift`, `DiagnosticsPage.swift`, `AdvancedPage.swift`
- EDIT (minimal): the popover header view (inspect `DexDictateApp.swift`, `MenuBarIconController.swift`, `ControlsView.swift`, `FooterView.swift` to find where the header lives) — add one gear button that opens the window.

## Required inspection before editing
1. Read `HistoryWindow.swift` and `HelpWindowController.swift` — these are the repo's existing detached-window precedents. **Reuse their hosting pattern**; do not invent a new windowing approach.
2. Read `DexDictateApp.swift` to understand the app lifecycle (MenuBarExtra vs NSStatusItem) before wiring ⌘,.
3. Read `SurfaceTokens.swift` / `PopoverSizing.swift` for existing style tokens; use them.

## Implementation steps
1. Build the window: sidebar with the 11 items in this exact order and naming — General, Dictation, Audio & Microphone, Output & Insertion, Vocabulary & Commands, Models & Accuracy, Smart Cleanup, History, Dexter & Personality, Diagnostics & Recovery, Advanced.
2. Each page: title + one placeholder line ("Settings for X will move here"). No controls.
3. Gear button in popover header opens (or focuses, if already open) the window. Window is a normal window — it must not be floating/always-on-top and must not steal focus from dictation targets when closed.
4. ⌘, shortcut only if it attaches cleanly to the existing scene/window setup; otherwise skip and note it.

## Acceptance criteria
- Window opens/closes cleanly; sidebar navigates all 11 pages; reopening restores last page or defaults to General.
- Old popover and Quick Settings completely unchanged (gear button aside).
- Dictation works with the settings window open AND after it closes (no focus-stealing: dictate into Notes with the window open).
- `swift build` clean; `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · manual: full dictation loop (hold Middle Mouse, speak, release → text lands in Notes); open/close window 5×; verify Quick Settings still opens.

## Screenshots
`docs/refactor_baseline/packet_02/`: settings window on General; sidebar showing all 11 items; popover header with gear.

## Commit
Stage explicit paths only. `feat(ui): packet 02 — empty Settings window shell with 11-page sidebar`
Push only if build+tests pass and diff shows only the new files + minimal header edit.

## Rollback
Single revert removes window + gear button; zero behavioral surface elsewhere.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 02 — Settings Window Shell
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks: (ticker scrolls / watermark rotates / launch animation plays)
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: 03 — General + Appearance Migration
```

--- END PACKET 02 PROMPT ---

---

## 8. Claude Sonnet Prompt: Packet 03 — General + Appearance Migration

--- BEGIN PACKET 03 PROMPT ---

# Packet 03 — Migrate General + system-appearance controls (move views intact; same storage keys)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 11 page 1 (General).
- Prerequisite: Packet 02 merged (Settings window exists). If missing, stop.

## Hard rules
No feature deletions. No rewrites. No engine/audio/output changes. No Dexter removals or asset changes. **No storage-key changes — controls must keep their exact `@AppStorage`/UserDefaults keys.** Old card rows are HIDDEN (conditionally excluded), never deleted, until Packet 12B. Do not combine packets. Do not continue on unsafe git state. Do not push failing tests.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
`OnboardingView.swift` internals are forbidden — the Replay button may only CALL the existing presentation entry point, exactly as the five-tap gesture does.

## Stop conditions
Global set plus: any migrated control's storage key would need to change; the five-tap onboarding entry point is not callable without modifying `OnboardingView.swift`; theme/profile logic turns out to be entangled with the controls being moved (theme picker and Dexter profile controls are NOT in this packet — they move in Packet 11).

## Goal
Settings → General becomes functional with exactly these relocated controls: Launch at Login; Play Start Sound; Play Stop Sound; Menu Bar Style picker; Status Color + Reset; a new "Replay Onboarding" button; a "Restore Defaults" button (duplicated here — the popover's existing Restore Defaults stays where it is until Packet 09).

## Files likely touched
- `Sources/DexDictate/SettingsWindow/GeneralSettingsPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` (hide the migrated rows in the Appearance & System card behind a `showLegacyRows`-style condition; do not delete code)
- Possibly `Sources/DexDictate/FooterView.swift` READ-ONLY (to find the five-tap gesture's target call)

## Required inspection before editing
1. Read the Appearance & System card in `QuickSettingsView.swift` end-to-end. List every control, its binding, and its storage key. **Check for lifecycle logic (`onAppear`/`task`/timers/observers) in the card — if any exists on the rows being moved, STOP and report.**
2. Read `Sources/DexDictateKit/Settings/LaunchAtLogin.swift` (logic stays put; only its UI moves).
3. Find how the five-tap version gesture reopens onboarding; the Replay button calls the same function.

## Implementation steps
1. Move the listed control views into GeneralSettingsPage, preserving bindings and keys verbatim. Keep the Menu Bar Style control in its current form (dropdown + preview); the visual icon grid upgrade is Packet 15, not now.
2. Hide (do not delete) the migrated rows in the card; the card header may remain with its unmigrated rows (theme picker, status color if entangled — status color moves only if it's a clean move; otherwise leave it and note).
3. Add Replay Onboarding (calls existing entry). Add Restore Defaults (calls the exact function the popover button calls).

## Acceptance criteria
- Every migrated control round-trips: change in Settings → close → reopen → persisted; and the same value is honored by the app (icon changes live, sounds play/don't play, Launch at Login registers with the system).
- Old card no longer shows migrated rows; nothing else in the card changed.
- Replay Onboarding presents the wizard; completing/cancelling it returns cleanly.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter LaunchAtLogin` · manual toggles for each control · feature-loss checklist rows: **Launch at Login**, **Onboarding & Permission Polling** (replay path only — do not reset defaults).

## Screenshots
`docs/refactor_baseline/packet_03/`: General page; Appearance & System card after hiding rows.

## Commit
`refactor(ui): packet 03 — migrate General settings to Settings window (behavior-preserving)`

## Rollback
Single revert restores card rows (they were hidden, not deleted).

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 03 — General + Appearance Migration
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: 04 — Dictation + Audio Migration
```

--- END PACKET 03 PROMPT ---

---

## 9. Claude Sonnet Prompt: Packet 04 — Dictation + Audio Migration

--- BEGIN PACKET 04 PROMPT ---

# Packet 04 — Migrate trigger + audio-device settings (lifecycle inspection is mandatory)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 11 pages 2–3.
- Prerequisite: Packet 02 merged. If missing, stop.

## Hard rules
No feature deletions. No rewrites. **Absolutely no changes to the audio engine, event tap, tap installer, resampler, or recovery files.** No Dexter removals. No storage-key changes. Hide old rows, never delete. Do not combine packets. Do not continue on unsafe git state. Do not push failing tests.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
`ShortcutRecorder.swift` internals are forbidden too — the recorder VIEW is re-hosted, its logic untouched.

## Stop conditions
Global set plus (MANDATORY): **before moving anything, inspect the Input card in `QuickSettingsView.swift` for lifecycle behavior — `onAppear`, `task`, `onDisappear`, `Timer`, Combine subscriptions, NotificationCenter observers. If ANY behavior (device scanning, route-health polling, permission polling, recorder arming) lives inside the card's view lifecycle rather than in a service/controller, STOP and report the exact code location and a proposed extraction. Do not move the view.** Also stop if the device picker's population logic would need to change to be re-hosted.

## Goal
Settings → Dictation gets: trigger style (Hold/Toggle), the ShortcutRecorder host view, silence timeout slider, adaptive tail preset picker. Settings → Audio & Microphone gets: input device picker, input level meter (if one exists in the card), silence trim toggle. Route Health rows DO NOT move in this packet (they move to Diagnostics in Packet 08); Vocabulary/Voice Commands buttons DO NOT move (Packet 06).

## Files likely touched
- `Sources/DexDictate/SettingsWindow/DictationSettingsPage.swift`, `AudioSettingsPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` (hide migrated rows only)
- `Sources/DexDictate/ShortcutRecorder.swift` READ-ONLY (re-host its view)

## Required inspection before editing
1. Full read of the Input card and every view it composes. Produce the lifecycle inventory demanded by the stop condition and include it in your final report even if clean.
2. Identify every storage key involved (trigger mode, shortcut binding, silence timeout, tail preset, input device UID `inputDeviceUID`, silence trim). Record them; verify unchanged after the move via `git diff | grep -i appstorage`.

## Implementation steps
1. Move the listed views intact to their pages, preserving bindings/keys.
2. Hide migrated rows in the Input card; the card remains (Route Health + vocab/commands buttons still live there until Packets 06/08).
3. Add the caption under silence timeout: "For long dictation, raise this or turn it off." (string addition only).

## Acceptance criteria
- Hold-to-talk works; toggle mode works; shortcut re-recording works (mouse and keyboard) from the new page.
- Device switch from the new page takes effect; unplugging the preferred mic still falls back automatically (recovery untouched).
- Silence timeout honored in toggle mode; tail preset selection persists.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter AudioRecorderRecovery` (must be untouched-green) · manual trigger matrix (hold ×2, toggle ×2, re-record shortcut) · mic switch + unplug test · feature-loss checklist rows: **Local Whisper Dictation**, **Audio Route Recovery & Fallback**.

## Screenshots
`docs/refactor_baseline/packet_04/`: Dictation page; Audio & Microphone page; remaining Input card.

## Commit
`refactor(ui): packet 04 — migrate dictation triggers and audio device settings (behavior-preserving)`

## Rollback
Single revert; hidden card rows reappear.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 04 — Dictation + Audio Migration
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (must include the lifecycle inventory finding)
- Rollback required: No/Yes
- Next recommended packet: 05 — Output + Per-App Rules
```

--- END PACKET 04 PROMPT ---

---

## 10. Claude Sonnet Prompt: Packet 05 — Output + Per-App Rules

--- BEGIN PACKET 05 PROMPT ---

# Packet 05 — Migrate output toggles + per-app rules surface (no insertion-behavior changes)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 11 page 4.
- Prerequisite: Packet 02 merged. If missing, stop.

## Hard rules
No feature deletions. No rewrites. **No changes to insertion, clipboard, secure-input, or output-coordination logic — only where their toggles are displayed.** No Dexter removals. No storage-key changes (e.g. `copyOnlyInSensitiveFields` keeps its key). Hide old rows, never delete. Do not combine packets. Unsafe git state → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Also forbidden: any logic file backing per-app overrides (e.g. the `AppInsertionOverridesManager` type wherever it lives in `DexDictateKit`).

## Stop conditions
Global set plus: `PerAppInsertionSheet.swift` cannot be re-hosted without modifying override logic; any output toggle's lifecycle inventory (same check as Packet 04) shows behavior in the card's view lifecycle; the correction-sheet toggle turns out to be wired through engine files.

## Goal
Settings → Output & Insertion gets: Auto-Paste (Insert at Cursor), Use Accessibility API for Insertion, Correction Sheet toggle (rename to "Review Before Insert" happens in Packet 10, NOT now), Copy Only in Sensitive Fields, Filter Profanity, a short informational note about clipboard restore (display text only), and the Per-App Rules surface.

## Files likely touched
- `Sources/DexDictate/SettingsWindow/OutputSettingsPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` (hide migrated Output-card rows; Safe Mode toggle stays until Packet 08)
- `Sources/DexDictate/PerAppInsertionSheet.swift` — **preferred approach: keep this sheet/window as-is and open it from a prominent "Manage Per-App Rules…" button on the page.** Embed its content inline ONLY if the view is trivially re-hostable with zero logic edits. If embedding needs any logic change, use the button. Do not rewrite the sheet.

## Required inspection before editing
1. Full read of the Output card in `QuickSettingsView.swift`; lifecycle inventory (same protocol as Packet 04 — stop if behavior lives in view lifecycle).
2. Read `PerAppInsertionSheet.swift` enough to decide button-vs-embed. Record the decision and reason in the report.
3. List all storage keys involved; verify unchanged post-move.

## Implementation steps
1. Move the toggle views intact; group as: "Where text goes" (auto-paste, AX API), "Safety" (sensitive fields, correction sheet, profanity), "Per-App Rules" (button or embedded table).
2. The existing destructive warning text about "Replace Entire Field" must remain verbatim wherever the rules surface renders (restyling is Packet 15).
3. Hide migrated rows in the Output card.

## Acceptance criteria
- Configure a per-app rule (e.g. force Copy Only for a specific app) → that app copies, others paste. Remove the rule → behavior reverts.
- Password field dictation → copy-only fallback still triggers (untouched logic, verified anyway).
- All toggles round-trip and are honored (test auto-paste off → result is copied, not pasted).
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter AppInsertionOverrides` · `swift test --filter SecureInputContext` · `swift test --filter OutputCoordinator` · `swift test --filter ClipboardManager` · manual: per-app rule round-trip, password-field test, clipboard-restore test (copy string → dictate → original clipboard restored) · feature-loss checklist rows: **Per-App Insertion Overrides**, **Secure-Field Copy-Only Fallback**, **Clipboard Restoration & Payload Cap**, **Accessibility API Direct Insertion**.

## Screenshots
`docs/refactor_baseline/packet_05/`: Output & Insertion page; per-app rules surface; remaining Output card.

## Commit
`refactor(ui): packet 05 — migrate output and per-app insertion settings (behavior-preserving)`

## Rollback
Single revert; hidden rows reappear; sheet unchanged either way.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 05 — Output + Per-App Rules
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include button-vs-embed decision + lifecycle inventory)
- Rollback required: No/Yes
- Next recommended packet: 06 — Vocabulary + Commands
```

--- END PACKET 05 PROMPT ---

---

## 11. Claude Sonnet Prompt: Packet 06 — Vocabulary + Commands

--- BEGIN PACKET 06 PROMPT ---

# Packet 06 — Vocabulary & Commands page (surface, don't rewrite)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Sections 11 (page 5) and 12.
- Prerequisite: Packet 02 merged. If missing, stop.

## Hard rules
No feature deletions. No rewrites. **`Sources/DexDictateKit/VocabularyManager.swift` and `Sources/DexDictateKit/CommandProcessor.swift` logic must not change** (if a trivial, unavoidable exposure tweak seems required, stop and report instead). No schema/storage-key changes — the "Learned" badge ships only if provenance data already exists. No Dexter removals. Hide old entry points, never delete. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Plus: `Sources/DexDictateKit/VocabularyManager.swift`, `Sources/DexDictateKit/CommandProcessor.swift` (logic).

## Stop conditions
Global set plus: the editors (`VocabularySettingsView.swift`, `CustomCommandsSheet.swift`) cannot be re-hosted without logic edits; learned-correction provenance would require adding a stored field (schema change → out of scope).

## Goal
Settings → Vocabulary & Commands becomes the single destination for both systems: a Vocabulary section (hosting the existing `VocabularySettingsView` content) and a Voice Commands section (hosting the existing `CustomCommandsSheet` content), replacing the two buried buttons in the Input card. Import/export preserved if present. Learned corrections remain reachable exactly as today (History window "Learn correction"), and appear in the vocabulary list as they do in the existing manager.

## Files likely touched
- `Sources/DexDictate/SettingsWindow/VocabularyCommandsPage.swift` (build out)
- `Sources/DexDictate/VocabularySettingsView.swift`, `Sources/DexDictate/CustomCommandsSheet.swift` (re-host their content views; internal logic untouched — if their windowing wrapper must be separated from their content view, do the minimal split and note it)
- `Sources/DexDictate/QuickSettingsView.swift` (hide the two buttons in the Input card)
- `Sources/DexDictate/VocabularyCorrectionSheet.swift` READ-ONLY (learn-correction flow; must keep working unchanged)

## Required inspection before editing
1. Read both editor views; identify content-view vs window-wrapper structure; identify whether import/export exists and where.
2. Read how learned corrections are stored (does an entry carry provenance/source info?). If yes, a "Learned" badge may render from existing data. If no, skip the badge and note it.
3. Lifecycle inventory on both editors (same stop rule as Packets 04/05).

## Implementation steps
1. Two-section page (or two tabs) hosting the existing content views.
2. Hide the Input-card buttons; if any other code path opens the old detached editors (e.g. History window), leave those paths working — they may open the same content in its old window until Packet 12B.
3. One caption line at page bottom: "After transcription: Commands run first, then Vocabulary corrections, then the text is inserted." (string only; verify order against `CommandProcessor`/`VocabularyManager` call order by reading `TranscriptionEngine.swift` READ-ONLY — if the real order differs, write the true order).

## Acceptance criteria
- Add vocabulary entry foo→bar on the page → dictate "foo" → "bar" is typed. Delete entry → behavior reverts.
- Define/verify a voice command (e.g. built-in "scratch that") executes.
- History window → Learn Correction still works and the new mapping appears in the page's vocabulary list.
- Import/export (if present) works from the new page.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter Vocabulary` · `swift test --filter CommandProcessor` · manual foo→bar round-trip, scratch-that, learn-correction round-trip · feature-loss checklist rows: **Custom Vocabulary and learned corrections**, **Voice Commands**.

## Screenshots
`docs/refactor_baseline/packet_06/`: Vocabulary section with an entry; Commands section; Input card without the two buttons.

## Commit
`refactor(ui): packet 06 — vocabulary & commands settings page (behavior-preserving)`

## Rollback
Single revert; old buttons reappear.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 06 — Vocabulary + Commands
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include learned-provenance finding + pipeline-order verification)
- Rollback required: No/Yes
- Next recommended packet: 07 — Models + Accuracy + Benchmark Relocation
```

--- END PACKET 06 PROMPT ---

---

## 12. Claude Sonnet Prompt: Packet 07 — Models + Accuracy + Benchmark Relocation

--- BEGIN PACKET 07 PROMPT ---

# Packet 07 — Models & Accuracy page; benchmark machinery leaves the popover

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 11 page 6.
- Prerequisite: Packet 02 merged. If missing, stop.

## Hard rules
No feature deletions — benchmarking is fully preserved, only its ENTRY POINT and status display relocate. No changes to `Sources/DexDictateKit/Benchmarking/ModelBenchmarking.swift`, `WhisperModelCatalog.swift`, promotion policy, or `BenchmarkCaptureWindow.swift` internals. **Keep old internal/user-facing names (Accuracy Retry, Context Injection) — renames are Packet 10.** No storage-key changes (`activeWhisperModelID_v1`, `modelSelectionMode_v1` keys unchanged). Hide old card, never delete. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Plus: `Sources/DexDictateKit/Benchmarking/*` (logic), `Sources/DexDictate/BenchmarkCaptureWindow.swift` (internals; opening it is fine), `Sources/DexDictate/ModelSelectionActions.swift` (logic — its UI hooks may be re-hosted).

## Stop conditions
Global set plus: lifecycle inventory of the Accuracy & Speed and Benchmarks & Corpus cards shows behavior in view lifecycle (e.g. idle benchmark scheduling armed by the card's appearance) — stop and report; model import flow requires logic edits to re-host.

## Goal
Settings → Models & Accuracy gets: active model picker; Import Model; model/end preset picker; Accuracy Retry toggle (old name); Context Injection toggle (old name); an "Open Benchmark Lab…" button opening the existing Benchmark Capture window; a one-line last-promotion/status summary if trivially readable from existing published state. The popover's Benchmarks & Corpus card is hidden entirely — no benchmark status, session IDs, queue display, or run buttons remain in the popover. Benchmark automation cadence controls (idle triggers) do NOT move here — they go to Advanced in Packet 08; leave them where they are, hidden with their card only if they live in the Benchmarks card (note where they are for Packet 08).

## Files likely touched
- `Sources/DexDictate/SettingsWindow/ModelsAccuracyPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` (hide Accuracy & Speed rows being moved + entire Benchmarks & Corpus card)
- `Sources/DexDictate/ModelSelectionActions.swift` READ-ONLY / re-host hooks

## Required inspection before editing
1. Full read of Accuracy & Speed and Benchmarks & Corpus cards; lifecycle inventory (stop rule applies).
2. Identify where "Trim Leading/Trailing Silence" and "Trailing Trim Experiment" live: the trim toggle belongs to Audio (already moved in Packet 04 — if it wasn't, move it now and note); the "Trailing Trim Experiment" flag is for Packet 08's Advanced page — leave in place, note location.
3. Confirm the Benchmark Capture window opens via an action you can call from the new button.

## Implementation steps
1. Build the page; full-width buttons (no "Import Mo…" truncation).
2. Hide the migrated rows and the Benchmarks card.
3. Verify auto-promotion still functions headlessly (it must not depend on the hidden card being visible — if it does, that's a lifecycle stop condition).

## Acceptance criteria
- Model switch persists and is used by the next dictation; Import Model accepts a GGML `.bin`.
- Preset switch persists. Accuracy Retry toggle works: a deliberately poor dictation (whisper quietly) surfaces the retry button in the popover as before.
- "Open Benchmark Lab…" opens the capture window; a benchmark run still completes and writes `benchmark_baseline.json` (do NOT commit that file).
- Popover contains zero benchmark UI.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter BenchmarkPromotion` · `swift test --filter AdaptiveBenchmark` · manual model switch + import + retry-button check · feature-loss checklist rows: **Model Benchmarking & Promotion**, **Smart Quality Retry (Accuracy Retry)**, **Context Injection**.

## Screenshots
`docs/refactor_baseline/packet_07/`: Models & Accuracy page; popover after benchmark card removal; Benchmark Lab opened from the page.

## Commit
`refactor(ui): packet 07 — models & accuracy settings page; relocate benchmark entry out of popover`

## Rollback
Single revert; cards reappear.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 07 — Models + Accuracy + Benchmark Relocation
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include lifecycle inventory + location of automation-cadence controls for Packet 08)
- Rollback required: No/Yes
- Next recommended packet: 08 — Diagnostics + Recovery + Advanced
```

--- END PACKET 07 PROMPT ---

---

## 13. Claude Sonnet Prompt: Packet 08 — Diagnostics + Recovery + Advanced

--- BEGIN PACKET 08 PROMPT ---

# Packet 08 — Diagnostics & Recovery + Advanced pages; retire the Quick Settings stack from the popover

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 11 pages 10–11.
- Prerequisites: Packets 03–07 all merged (this packet empties the remaining cards and hides the Quick Settings entry). If any are missing, stop.

## Hard rules
No feature deletions. **No changes to `Sources/DexDictateKit/Services/CoreAudioResetService.swift` logic, the recovery planner, or `PermissionManager.swift` logic — only where their UI renders.** The Reset Core Audio admin-prompt flow must remain byte-identical in behavior. Safe Mode snapshot/restore logic (`SafeModePreset.swift`) untouched — only its toggle moves. No storage-key changes. Hide, never delete. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Plus: `Sources/DexDictateKit/Services/CoreAudioResetService.swift`, `Sources/DexDictateKit/Settings/SafeModePreset.swift`, `Sources/DexDictateKit/Permissions/PermissionManager.swift` (logic).

## Stop conditions
Global set plus: Route Health display turns out to OWN its observers inside the card view (lifecycle stop — report extraction proposal); permission polling is armed by a card's appearance; removing the Quick Settings entry breaks any remaining un-migrated control (inventory first — if anything is still homed only in a card, stop and report).

## Goal
Settings → Diagnostics & Recovery gets: permission status rows (Mic / Accessibility / Input Monitoring) with existing Fix actions; Route Health panel (Active Input, Recoveries, Last Recovery — moved from the Input card); Safe Mode toggle + its existing explanation; a visually fenced "System Repair" group containing Reset Core Audio with its warning about admin privileges. Settings → Advanced gets: experiment flags (e.g. Trailing Trim Experiment), benchmark automation cadence controls (from wherever Packet 07's report located them), and the Experimental UI switch. THEN: with every card's content confirmed re-homed, hide the "Quick Settings" entry from the popover entirely (conditional, not deleted).

## Files likely touched
- `Sources/DexDictate/SettingsWindow/DiagnosticsPage.swift`, `AdvancedPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` (hide remaining rows + the whole entry)
- `Sources/DexDictate/PermissionBannerView.swift` READ-ONLY (understand permission display precedents)
- The popover view that presents Quick Settings (from `ControlsView.swift` / `FooterView.swift` / `DexDictateApp.swift` — find it, hide the entry)

## Required inspection before editing
1. **Pre-removal inventory (mandatory, goes in the report):** list every control still visible anywhere in the Quick Settings stack; each must have a Settings-window home (from Packets 03–07 or this packet) before the entry is hidden. Anything unaccounted for → stop.
2. Reset Core Audio UI region (`QuickSettingsView.swift` around the Advanced card): read fully; the button must call the identical service function.
3. Route Health rows: confirm they are display-only consumers of published state (else lifecycle stop).

## Implementation steps
1. Build both pages; move views intact.
2. "System Repair" fencing: bordered group, warning text preserved, button styling consistent with existing tokens (`SurfaceTokens.swift`).
3. Hide the Quick Settings entry from the popover last, after the inventory passes.

## Acceptance criteria
- Reset Core Audio prompts for administrator password and executes (verify prompt appears; cancel is fine — do not actually reset unless Andrew is present).
- Safe Mode on → hold-only + copy-only + no sounds; off → prior settings restored.
- Route Health values update live on the Diagnostics page (switch default input to see a recovery count).
- Permission rows reflect real states.
- Popover no longer shows Quick Settings; every former control reachable in the Settings window.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter AudioRecorderRecovery` · manual Safe Mode matrix, Reset prompt check, route-change check · feature-loss checklist rows: **Reset Core Audio UI & Command**, **Audio Route Recovery & Fallback**, plus re-run **Local Whisper Dictation**.

## Screenshots
`docs/refactor_baseline/packet_08/`: Diagnostics page; System Repair group; Advanced page; popover without Quick Settings.

## Commit
`refactor(ui): packet 08 — diagnostics/recovery/advanced pages; retire Quick Settings stack from popover`

## Rollback
Single revert restores the Quick Settings entry and card rows.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 08 — Diagnostics + Recovery + Advanced
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (must include the pre-removal inventory)
- Rollback required: No/Yes
- Next recommended packet: 09 — Popover Slim-Down
```

--- END PACKET 08 PROMPT ---

---

## 14. Claude Sonnet Prompt: Packet 09 — Popover Slim-Down

--- BEGIN PACKET 09 PROMPT ---

# Packet 09 — Popover slim-down (two staged commits; old popover hidden, not deleted)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 10 (the popover contract — follow it exactly).
- Prerequisites: Packets 02–08 merged (settings all have homes). If not, stop.

## Hard rules
No feature deletions. No engine/audio/output changes. **`FlavorTickerView.swift` internals forbidden — its container may be repositioned; its marquee logic, timing, and bounds may not change.** **`WatermarkAssetProvider.swift` forbidden — watermark PLACEMENT changes are consumer-side (where the popover renders the image), not provider-side.** Old popover view files (`ControlsView.swift`, `HistoryView.swift`, `FooterView.swift`, etc.) are HIDDEN behind a switch, not deleted — deletion waits for Packet 12B. No storage-key changes. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```

## Stop conditions
Global set plus: the popover root cannot host an alternate layout without touching MenuBarExtra lifecycle in `DexDictateApp.swift` beyond a view-swap (report a proposal first); the result/retry/learn-correction actions are wired in a way that a new layout cannot re-trigger without engine edits; the ticker cannot be repositioned without editing its internals.

## Goal — implement the approved popover contract
Header: power toggle (with confirm) · "DexDictate" title · Help · gear. Ticker: full width, top, unchanged behavior. State hero: state dot + "Ready"/recording/processing, trigger hint ("Hold Middle Mouse to talk"), primary **Start/Stop Dictation button**; Dexter watermark renders in the hero zone when idle ONLY. Last result: 2–3 line transcript on a plain background (NO watermark under text), Pasted/Copied badge (existing), contextual "Retry Last in Accuracy Mode" (rename comes in Packet 10) and "Learn Correction" buttons, optional inline area reserved. History: last 3 rows + "Open History Window…". Status line: "Mic: X · model" (click opens Settings). Footer: `Settings… ⌘,` · `⋯` overflow (Transcribe File…, Safe Mode toggle, Pause Dictation, Quit App) · version string. Error/recovery banner replaces the hero on permission/mic failure with one sentence + one Fix button (reads existing signals — `PermissionBannerView.swift` is the precedent). REMOVED from popover: Quick Settings remnants, giant red Turn Off Dictation button, permanent Transcribe File button, "Restore Defaults" (now in General), floating TRIGGER/Scheduled label stack, all benchmark traces.

## Staged execution (two commits inside this packet)
- **Stage A (commit 1):** build the new popover layout as new files (`PopoverHeroView.swift`, `PopoverResultView.swift`, `PopoverHistoryTeaser.swift`, `PopoverRootView.swift`) selectable via an internal debug flag default-OFF. Old popover remains default. Validate both render.
- **Stage B (commit 2):** flip the default to the new popover; old popover views remain in the codebase, unreferenced by default but compilable. Full validation below runs on Stage B.

## Required inspection before editing
1. Read the current popover composition (`DexDictateApp.swift` popover content, `ControlsView.swift`, `HistoryView.swift`, `FooterView.swift`, `PermissionBannerView.swift`, `PopoverSizing.swift`, `SurfaceTokens.swift`).
2. Identify how Start/Stop is currently invoked programmatically (the engine API the old record affordance calls) — the new button calls the same API.
3. Identify the events behind "Pasted into active app" badge and retry/learn-correction visibility; the new result view subscribes to the same state.

## Acceptance criteria
- Full dictation loop works from BOTH the new button and the hardware trigger; hold and toggle both work.
- Retry and Learn Correction appear under the same conditions as before and function.
- History teaser shows the 3 most recent; Open History works.
- No text renders over a watermark anywhere in the popover; watermark appears in idle hero and/or empty-history zones and still rotates.
- Ticker scrolls at top exactly as before.
- Error banner appears when Accessibility permission is revoked (test via System Settings toggle if possible; else simulate per existing test hooks and note).
- Overflow: Transcribe File works; Safe Mode toggles; Quit quits.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter OutputPipelineHardening` · manual full matrix above · feature-loss checklist rows: **Local Whisper Dictation**, **Floating HUD & Tickers**, **Smart Quality Retry**, **Custom Vocabulary and learned corrections** (learn-correction button path) · Dexter checks: ticker, watermark rotation, launch animation, profile switch.

## Screenshots
`docs/refactor_baseline/packet_09/`: idle popover; recording state; post-dictation with badge; error banner; overflow menu open. Compare against the Section 10 wireframe and note deviations.

## Commits
Stage A: `feat(ui): packet 09a — new slim popover layout behind internal flag (old UI default)`
Stage B: `feat(ui): packet 09b — make slim popover the default (legacy popover retained, hidden)`

## Rollback
Revert Stage B alone to restore the old popover instantly; revert both to remove the new layout.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 09 — Popover Slim-Down (Stages A+B)
- Branch:
- Commit hash: (both)
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include wireframe deviations)
- Rollback required: No/Yes
- Next recommended packet: 10 — Terminology Sweep
```

--- END PACKET 09 PROMPT ---

---

## 15. Claude Sonnet Prompt: Packet 10 — Terminology Sweep

--- BEGIN PACKET 10 PROMPT ---

# Packet 10 — Terminology sweep (display strings ONLY; zero keys, zero logic)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 7 (mode taxonomy).
- Prerequisites: Packets 03–09 merged. If not, stop.

## Hard rules
**String-only.** No `@AppStorage`/UserDefaults key changes. No `SettingsMigration.swift` changes. No logic changes. No identifier/type/function renames (internal code names stay; only user-visible text changes). No Dexter removals. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
EXCEPTION: if a user-facing string literal lives inside a forbidden file, report it in the final report instead of editing that file. Help content files ARE editable (`HelpView.swift` / help content sources).

## Stop conditions
Global set plus: a rename appears to require changing a stored value (e.g. a history tag is persisted with the old term as data — in that case rename only the DISPLAY of the tag, not stored values, or stop and report); a string is constructed from an identifier you'd have to rename.

## Renames (user-facing only)
- "Accuracy Retry" → **"Quality Retry"**
- "Retry Last in Accuracy Mode" → **"Retry with Higher Quality"**
- "Correction Sheet" → **"Review Before Insert"**
- "Context Injection" / "Inject Focused Field Context" / "hidden context biasing" → **"Context Priming"** (caption: "Reads the text around your cursor so names and jargon come out right.")
- "Smart Retry" (anywhere) → **"Quality Retry"**
- "Optimization" as a settings group name → remove/replace with the host page's plain grouping
- Model preset labels: consolidate to **Fast / Balanced / Accurate** where they describe model/decode presets (do NOT touch the tail-timing preset names Stable/Fast/Conservative unless they collide in one view — if they collide, rename tail presets to "Tail timing: Stable/Fast/Conservative" as a caption-level disambiguation)

## Steps
1. `grep -rn "Accuracy Retry\|Retry Last in Accuracy\|Correction Sheet\|Context Injection\|Smart Retry" Sources/ --include=*.swift` — build the full hit list first; include it in the report.
2. Apply renames to display strings, Help window text, and any "Found at:" paths in help so they match the new Settings locations.
3. Verify zero key changes: `git diff | grep -n "AppStorage\|UserDefaults"` must show no key-string modifications.
4. Post-sweep grep: retired terms must return zero user-facing hits (internal symbol names may remain and are listed in the report).

## Acceptance criteria
- All renamed strings render in UI and Help; retired terms absent from user-facing text; settings persist across the change (same keys); history tags display new names without data migration.
- `swift test` zero new failures; `swift test --filter SettingsMigration` green.

## Validation commands
`swift build` · `swift test` · `swift test --filter SettingsMigration` · manual read-through of every Settings page, popover, and the Help sections that mention renamed features.

## Screenshots
`docs/refactor_baseline/packet_10/`: Models & Accuracy page (Quality Retry visible); popover retry button; one Help page with updated path.

## Commit
`refactor(strings): packet 10 — terminology consolidation (display strings only, no keys, no logic)`

## Rollback
Single string-only revert.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 10 — Terminology Sweep
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include grep hit list + any strings living in forbidden files)
- Rollback required: No/Yes
- Next recommended packet: 11 — Dexter & Personality
```

--- END PACKET 10 PROMPT ---

---

## 16. Claude Sonnet Prompt: Packet 11 — Dexter & Personality Page

--- BEGIN PACKET 11 PROMPT ---

# Packet 11 — Dexter & Personality page + identity presentation polish (the ONLY packet allowed near Dexter presentation)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 9. Dexter is the product's identity — this packet gives it a settings home and fixes presentation issues; it must not weaken it.
- Prerequisites: Packets 02–10 merged. If not, stop.

## Hard rules — Dexter preservation is the point of this packet
MUST PRESERVE UNCHANGED: launch animation behavior (`LaunchIntroController.swift` — forbidden), onboarding wizard (`OnboardingView.swift` — forbidden), ticker marquee logic/timing (`FlavorTickerView.swift` — forbidden; container placement only), watermark selection/randomization/no-repeat logic (`WatermarkAssetProvider.swift` — forbidden; placement is consumer-side), profile state logic (`ProfileManager.swift` — forbidden), quote pack contents (`FlavorQuotePacks.swift` — forbidden), ALL bundled MP4/PNG assets. No storage-key changes. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Plus `Sources/DexDictateKit/Quotes/FlavorQuotePacks.swift` and all bundled media assets.

## Stop conditions
Global set plus: any desired control (ticker toggle, watermark toggle/shuffle) has NO existing setting/API to bind to — do not invent new stored settings without reporting first; the theme seam fix requires editing ticker or watermark internals.

## Goal
Settings → Dexter & Personality gets: profile picker as visual cards (Standard / Canadian / Australian, showing existing regional icons — reads `ProfileManager` published state, sets profile via its existing API); theme picker (System / Cyberpunk / Minimalist / High Contrast — relocated from wherever it currently renders); ticker controls (on/off and any existing speed/behavior settings — only if such settings already exist); inline result quote toggle (only if Packet 12A has not yet adopted it, add the page slot with "coming with experimental adoption" placeholder); watermark backdrop toggle + "Shuffle Now" button (calls existing `refreshDynamicContent()`-style API if present). ALSO: fix the theme seam (popover header renders light while body dark under Minimalist — consumer-side style fix); verify no remaining surface renders text over a watermark.

## Files likely touched
- `Sources/DexDictate/SettingsWindow/DexterPersonalityPage.swift` (build out)
- `Sources/DexDictate/QuickSettingsView.swift` or wherever the theme picker still renders (hide old row)
- Popover chrome files for the seam fix (`SurfaceTokens.swift`, popover root)

## Required inspection before editing
1. Read `ProfileManager.swift`, `WatermarkAssetProvider.swift`, `FlavorTickerView.swift` READ-ONLY: list the public APIs/published state available to bind. The page may only call existing APIs.
2. Find the theme seam: which view applies theme background to header vs body; fix at the consumer level.
3. Inventory existing ticker/watermark settings keys (if none exist for on/off, report rather than invent).

## Acceptance criteria
- Profile switch on the page swaps quotes and regional icons live (ticker shows the new pack).
- All four themes apply without the header/body seam.
- Watermark shuffle rotates without immediate repeat (existing logic proves itself).
- Ticker, launch animation, onboarding all behave exactly as before.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · `swift test --filter ProfileContent` · manual: profile matrix ×3, theme matrix ×4, shuffle ×5 · feature-loss checklist rows: **Dexter Imagery**, **RSS-Style News Ticker Feed**, **Randomized Dexter Backgrounds**, **Launch Animation**, **Dexter Identity Layer**.

## Screenshots
`docs/refactor_baseline/packet_11/`: Dexter & Personality page; each theme applied (4 shots); a regional profile active.

## Commit
`feat(ui): packet 11 — Dexter & Personality settings page; theme seam fix (identity-preserving)`

## Rollback
Single revert; identity behavior was never changed, only exposed.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 11 — Dexter & Personality
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (include API-availability findings for ticker/watermark controls)
- Rollback required: No/Yes
- Next recommended packet: 12A — Experimental Adoption Inventory
```

--- END PACKET 11 PROMPT ---

---

## 17. Claude Sonnet Prompt: Packet 12A — Experimental Adoption Inventory and Safe Adoption

--- BEGIN PACKET 12A PROMPT ---

# Packet 12A — Experimental UI adoption inventory + safe component adoption (NO deletion)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Sections 5 and 17 (Phase 9/10).
- Prerequisites: Packets 09–10 merged. If not, stop.
- The experimental UI lives in `Sources/DexDictate/ExperimentalUI/`: `DexStateFirstPopoverView.swift`, `DexStateFirstComponents.swift`, `DexCommandPaletteView.swift`, `DexNanoHUDView.swift`, `DexDexterFeedView.swift`, `DexExperimentalEntry.swift`, `DexExperimentalHubViews.swift`, `DexExperimentalUIStateAdapter.swift`, `DexLayeredRevealView.swift`.

## Hard rules
**DELETE NOTHING. The experimental UI must remain fully functional after this packet.** Adoption means re-hosting/adapting a component into the standard UI, leaving the original in place. No engine changes. No Dexter removals. No storage-key changes (adopted components keep or read existing flags; new standard-UI toggles may be added ONLY as new keys, never repurposing old ones — list any new key in the report). Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```

## Stop conditions
Global set plus: a component cannot be adopted without modifying its experimental original or an engine file; the command palette's action registry is entangled with experimental-only state (report; partial adoption is acceptable).

## Goal
1. **Inventory (mandatory deliverable):** `docs/experimental_adoption_inventory.md` — a table of EVERY experimental capability (state-first popover layout, Permissions OK pill, pinned "daily six" controls, engine/trigger chips, Nano HUD, Command Palette ⌘K, Dexter Feed, All Features hub, Switch UI, inline result quote, anything else found by reading all files in `ExperimentalUI/`) with columns: capability · experimental file · standard-UI home (existing / adopted-this-packet / MISSING) · notes. Every MISSING row blocks Packet 12B.
2. **Safe adoptions (only if cleanly liftable, each optional):**
   - Command Palette (⌘K) available from the standard popover.
   - Nano HUD compact style as an option for the existing Floating HUD (option, not replacement).
   - Inline Dexter result quote under the popover's last result (toggle in Dexter & Personality, default per existing behavior).
   Skip any adoption that isn't clean; mark it in the inventory instead.

## Acceptance criteria
- Inventory complete and honest (MISSING rows allowed — they gate 12B, they don't fail 12A).
- Adopted components work in the standard UI AND the experimental UI still works when switched on (test Switch UI both ways).
- Standard popover default behavior unchanged for users who don't invoke adopted components.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · manual: ⌘K palette opens/executes an action (if adopted); Nano HUD option renders (if adopted); experimental UI on→off→on round-trip still works; full dictation loop in both UIs.

## Screenshots
`docs/refactor_baseline/packet_12a/`: adopted components in standard UI; experimental popover still functional.

## Commit
`feat(ui): packet 12a — experimental adoption inventory + safe component adoption (no deletions)`

## Rollback
Single revert removes adoptions; inventory doc harmless either way.

## Final report — use exactly this template, then STOP (do not proceed to 12B)
```markdown
## Packet Result
- Packet: 12A — Experimental Adoption Inventory + Safe Adoption
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (MISSING inventory rows; skipped adoptions and why; any new storage keys added)
- Rollback required: No/Yes
- Next recommended packet: NONE — Packet 12B requires Andrew's explicit written approval of the inventory
```

--- END PACKET 12A PROMPT ---

---

## 18. Claude Sonnet Prompt: Packet 12B — Experimental UI Retirement (GATED)

--- BEGIN PACKET 12B PROMPT ---

# Packet 12B — Experimental UI retirement (GATED)

**Do not run this packet unless Andrew has explicitly approved experimental UI retirement after reviewing Packet 12A.** If you cannot find that approval stated in your instructions for this session, stop now and report "gate not satisfied".

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM).

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Prerequisites: Packet 12A merged; `docs/experimental_adoption_inventory.md` exists with ZERO rows marked MISSING; Andrew's explicit approval. Any prerequisite absent → stop.

## Hard rules
Behavior must be fully preserved via the standard UI — retirement removes a duplicate SURFACE, not any capability. No engine changes. No Dexter removals (the Dexter Feed capability must already have its standard home — ticker/inline quote — per the inventory). No storage-key changes; the old experimental-UI enable flag's key stays (its reader may be removed; the key is never reused). Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
Adopted components (palette, Nano HUD option, inline quote — now living in standard paths) must NOT be removed with the experimental surface.

## Stop conditions
Global set plus: any inventory row is MISSING or ambiguous; removal creates dangling references to adopted components; the legacy standard popover files (hidden since Packet 09) would be swept up — this packet removes ONLY the `ExperimentalUI/` surface and the Switch UI affordance; ask Andrew separately about deleting the legacy popover views (recommended: same packet ONLY if he pre-approved it; otherwise leave hidden).

## Steps
1. Re-verify the inventory against the current code.
2. Remove (delete or fully unreference — prefer DELETE for the surface files, per approval) the state-first surface: `DexStateFirstPopoverView.swift`, `DexStateFirstComponents.swift`, `DexExperimentalEntry.swift`, `DexExperimentalHubViews.swift`, `DexExperimentalUIStateAdapter.swift`, `DexLayeredRevealView.swift`, `DexDexterFeedView.swift`, and the Switch UI affordance + the Experimental UI switch row in Settings → Advanced. KEEP: `DexCommandPaletteView.swift` and `DexNanoHUDView.swift` if the 12A adoptions re-host them directly (move them out of `ExperimentalUI/` if so; note the move).
3. Grep for dangling references; build; run the FULL feature-loss checklist (every row in `DexDictate_Feature_Loss_Checklist.md`) on the standard UI alone.

## Acceptance criteria
- App builds and runs with no experimental surface and no dangling references.
- FULL feature-loss checklist passes on the standard UI.
- Adopted components still work.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · full checklist run · full Dexter checks · full dictation matrix (hold/toggle × insert/copy).

## Screenshots
`docs/refactor_baseline/packet_12b/`: Advanced page without the switch; popover; ⌘K palette still working.

## Commit
`refactor(ui): packet 12b — retire experimental state-first UI surface (capabilities preserved in standard UI)` — single commit so it is trivially revertible.

## Rollback
`git revert` the single commit restores the entire surface.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 12B — Experimental UI Retirement
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations: (must state: FULL feature-loss checklist result)
- Screenshots captured:
- Feature-loss checklist rows completed: ALL
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: 15 — Visual Polish (or 13 if approved)
```

--- END PACKET 12B PROMPT ---

---

## 19. Claude Sonnet Prompt: Packet 13 — Smart Cleanup / Remote Ollama (GATED)

--- BEGIN PACKET 13 PROMPT ---

# Packet 13 — Smart Cleanup (remote Ollama) settings page + client (GATED)

**Do not run this packet until the Settings shell and taxonomy migration are approved — Packets 02–08 merged and Andrew has explicitly approved starting Smart Cleanup work.** If that approval is not stated for this session, stop and report "gate not satisfied".

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM).

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 14; `DexDictate_Remote_Ollama_Stack_Baseline.md` (read both before coding).
- Smart Cleanup = LLM **post-processing** of the final committed transcript (cleanup/formatting). It is NOT transcription, NOT live ASR, NOT a Whisper replacement. The audit confirms zero existing network-LLM code — everything here is new and isolated.

## Hard rules
Local batch Whisper remains the transcription engine and the delivered output path — **this packet must not change when or what text is inserted.** Initial form: cleanup runs AFTER delivery and stores a "Cleaned" variant in History next to the always-preserved raw transcript. No agent frameworks — plain `URLSession` calls to OpenAI-compatible `/v1` endpoints. **No hard-coded `BigMac`, `westcat`, or `11435`** — these may appear ONLY inside example/help strings clearly marked as examples. API key in Keychain, placeholder text `ollama`. No engine/output file changes. Cleanup failure/timeout → raw result stands, one status line, never a modal, never a delay to insertion. History storage additions must be additive/forward-compatible; if they require `SettingsMigration.swift` changes, STOP and report (that file is forbidden). Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
If observing "transcription completed" requires a hook that doesn't exist outside `TranscriptionEngine.swift`, STOP and report the needed observation point — do not add it yourself.

## Stop conditions
Global set plus: history model can't take an additive cleaned-variant field without migration-file changes; no observable completion event exists outside forbidden files; Keychain integration requires entitlement changes (report first).

## Goal
- NEW `Sources/DexDictateKit/SmartCleanup/`: `SmartCleanupSettings.swift` (base URL, model, enabled; key via Keychain), `SmartCleanupClient.swift` (`/v1/models` GET; `/v1/chat/completions` POST, `stream:false`, timeout), `SmartCleanupCoordinator.swift` (listens for completed committed transcripts when enabled; produces cleaned variant into History).
- Settings → Smart Cleanup page (replacing the Packet 02 placeholder): Enable toggle; provider label "OpenAI-Compatible Server (Ollama, etc.)"; Base URL field (placeholder example `http://127.0.0.1:11435/v1`); Model field; API key SecureField (placeholder `ollama`); **Test Connection** (lists model count/names) and **Test Inference** ("Reply with OK only." → shows reply + round-trip ms) buttons with inline status; collapsed "How the tunnel works" help containing the generic command `ssh -N -L <LOCAL_PORT>:127.0.0.1:11434 <USER>@<HOST>`, the localhost warning ("127.0.0.1 always means THIS Mac…"), and the SSH/Tailscale recommendation; static failure-fallback statement ("If cleanup fails, you get the raw transcript — always").
- Warnings: non-loopback cleartext base URL → inline warning (not blocking); unreachable endpoint on test → clear error.
- History window: cleaned variant shown beside raw with "Use raw" swap (display-level; raw is never deleted or overwritten).
- Diagnostics page: one status row ("Smart Cleanup endpoint: reachable / unreachable / disabled").

## Acceptance criteria
- With a live tunnel: Test Connection lists models; Test Inference returns OK; an enabled dictation produces a Cleaned history variant; insertion latency unchanged (cleanup is post-delivery).
- With a dead endpoint: dictation completely unaffected; status row shows unreachable; no modal, no retry storm (single attempt + backoff at most).
- Disabled (default): zero network activity (verify no requests fire).
- Raw transcript always present in History.
- `swift test` zero new failures; new unit tests for client request-building and URL validation included.

## Validation commands
`swift build` · `swift test` · new `swift test --filter SmartCleanup` · manual parity check: in-app Test Connection vs `curl -s http://127.0.0.1:<port>/v1/models` · dead-endpoint matrix · feature-loss checklist rows: **Local Whisper Dictation**, **Transcription History** behaviors.

## Screenshots
`docs/refactor_baseline/packet_13/`: Smart Cleanup page (disabled state, configured state, test results, warning state); History with raw+cleaned pair.

## Commit
`feat(cleanup): packet 13 — Smart Cleanup settings page + OpenAI-compatible client (post-processing only, raw always preserved)`

## Rollback
Disable toggle (default off) is the runtime rollback; `git revert` the commit for full removal. History field additions must tolerate absence (additive).

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 13 — Smart Cleanup / Remote Ollama
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations: (live-tunnel + dead-endpoint matrices)
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: 15 — Visual Polish (14 only with separate approval)
```

--- END PACKET 13 PROMPT ---

---

## 20. Claude Sonnet Prompt: Packet 14 — Live Preview Prototype (GATED)

--- BEGIN PACKET 14 PROMPT ---

# Packet 14 — Live Preview prototype, display-only (GATED; engine-adjacent; runs alone)

**Do not run this packet unless Andrew explicitly approves live preview implementation for this session.** If that approval is not stated, stop and report "gate not satisfied". This packet must never run in the same session or branch state as any other packet's uncommitted work.

You are Claude Sonnet in Claude Code, executing ONE engine-adjacent packet of the DexDictate refactor. Maximum conservatism applies.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Section 13 (Phase L1 only).
- **Live transcription is NOT solved. Parakeet failed expectations (stability, threading, CPU contention). You are building a display-only preview that can never affect committed output.** The baseline notes streaming providers (`Nemotron`/`AppleSpeech`) already exist behind `TranscriptionProviderRegistry` and are used for preview captions in some paths — your first job is to find what already exists and observe it, not to build a new streaming stack.

## Hard rules
Batch Whisper remains the ONLY committed-output path — this packet may not touch it. **Provisional text is never inserted into any target app** (no AX writes, no paste, nothing — display in DexDictate surfaces only). **Do not add new audio taps** — observe existing published audio/text streams only; if no safe observable stream exists, STOP and report exactly what is missing. Preview provider must suspend the instant capture stops (batch Whisper gets uncontested compute). Throttle UI updates to ≤4/sec, whole-line replacement. Kill switch: any preview-provider error disables preview for the session, logs to Diagnostics, and leaves dictation untouched. Default OFF (toggle in Settings → Dictation, labeled "Live Preview (experimental)"). Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify — INCLUDING in this packet)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```
"Engine-adjacent" means you may OBSERVE engine state through existing published interfaces (`TranscriptionProviderRegistry`, existing streaming provider outputs, published recording state) — it does not license editing forbidden files. If observation requires new hooks inside them → stop and report the exact needed hook.

## Stop conditions
Global set plus: no existing streaming provider output is observable without forbidden-file edits; preview cannot be QoS-fenced below capture; CPU contention measurably delays batch transcription start (see acceptance test); any code path would write provisional text toward the output pipeline.

## Goal
- NEW `Sources/DexDictate/LivePreview/LivePreviewController.swift` (subscribe to existing streaming provider partials when enabled + recording), NEW caption view rendered in the Floating HUD and/or popover state hero, styled unmistakably provisional (dimmed/italic + "PREVIEW" tag), clearing on stop with a visible handoff ("Finalizing…" → committed result).
- Settings → Dictation toggle, default OFF.
- Diagnostics log line on any preview error + session kill switch.
- NEW invariant test: with preview enabled vs disabled, the committed transcript for the same audio buffer is byte-identical (use existing test fixtures/sample corpus; if the engine's test seams don't allow this, STOP and report rather than weakening the test).

## Acceptance criteria
- Toggle OFF (default): zero preview provider activity (verify no provider load).
- Toggle ON: captions appear while speaking, ≤4 updates/sec, clear on stop; final text arrives exactly as with preview off.
- Invariant test passes and is committed as a permanent guard.
- Simulated provider failure (kill/throw in a controlled way through the provider's own error path) → dictation completes normally; preview disabled for session; Diagnostics logged.
- Batch transcription start latency unchanged within noise (measure with existing benchmark tooling: run `./scripts/benchmark.sh --audio sample_corpus/sample.wav` before/after if available; else time manually and report).
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · new `swift test --filter LivePreview` (or the invariant test's suite) · benchmark latency comparison · extended manual dictation session (≥10 dictations with preview on) · feature-loss checklist rows: **Local Whisper Dictation**, **Live Transcription (Requirement)** row (batch baseline intact, preview isolated).

## Screenshots
`docs/refactor_baseline/packet_14/`: HUD with PREVIEW captions during speech; handoff moment; Settings toggle.

## Commit
`feat(preview): packet 14 — display-only live preview prototype (batch Whisper remains authoritative; default off)`

## Rollback
Toggle default-off is the runtime rollback; `git revert` for removal. The invariant test stays even if the feature is reverted — commit it separately if reverting becomes likely.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 14 — Live Preview Prototype (L1)
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests: (must include invariant test result)
- Manual validations: (must include latency comparison + failure simulation)
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet: none (end of pack) or as Andrew directs
```

--- END PACKET 14 PROMPT ---

---

## 21. Claude Sonnet Prompt: Packet 15 — Visual Polish

--- BEGIN PACKET 15 PROMPT ---

# Packet 15 — Visual polish (presentation only; zero behavior change)

You are Claude Sonnet in Claude Code, executing ONE packet of a staged, behavior-preserving UI/UX refactor of DexDictate (macOS menu-bar dictation app, SwiftUI + AppKit, SPM). Execute only this packet.

## Context
- Repo: `/Users/andrew/DexDictate_MacOS.nosync` · Branch: `speech-engine-exploration-benchmarks` (stop if not on it)
- Plan of record: `DexDictate_Fable5_UIUX_Recovery_Plan.md`, Sections 3 (visual findings) and 18 Packet 15.
- Prerequisites: structural packets 02–11 merged (this packet must not run before structure exists). If not, stop.

## Hard rules
Presentation only: layout constants, typography, spacing, truncation fixes, container styling. **No behavior, binding, logic, storage, or string-meaning changes** (typo fixes fine; renames are done — Packet 10). Dexter internals remain forbidden (seam/clipping fixes are consumer-side; if not already fixed in Packet 11, they may be finished here at the consumer level only). No new dependencies. Do not combine packets. Unsafe git → stop. Failing tests → no push.

## Forbidden files (read-only; do not modify)
```text
Sources/DexDictateKit/Services/AudioRecorderService.swift
Sources/DexDictateKit/Services/AudioRecorderRecoverySupport.swift
Sources/DexDictateObjCSupport/AudioTapInstaller.m
Sources/DexDictateKit/Services/AudioResampler.swift
Sources/DexDictateKit/Permissions/InputMonitor.swift
Sources/DexDictateKit/Output/ClipboardManager.swift
Sources/DexDictateKit/Output/SecureInputContext.swift
Sources/DexDictateKit/Output/OutputCoordinator.swift
Sources/DexDictateKit/TranscriptionEngine.swift
Sources/DexDictateKit/Services/WhisperService.swift
Sources/DexDictateKit/Settings/SettingsMigration.swift
Sources/DexDictate/OnboardingView.swift
Sources/DexDictate/LaunchIntroController.swift
Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift
Sources/DexDictate/FlavorTickerView.swift
Sources/DexDictateKit/Profiles/ProfileManager.swift
```

## Stop conditions
Global set plus: a "polish" fix turns out to require a binding/logic change; a truncation can only be fixed by renaming (defer, report).

## Goal — fix the documented visual issues
1. **Truncation audit:** at default popover width and minimum Settings-window size, no control label truncates. Known offenders from the screenshot packet: "Import Mo…", "Run Bench…", "Restore Stab…" (frame 010 — likely already fixed by relocation; verify), chips "Midd…"/"Hol…" if any chip pattern was adopted.
2. **Menu Bar Style picker** → visual icon grid (General page; deferred from Packet 03) — same options, same key, better presentation.
3. **Destructive warning callouts:** "Replace Entire Field" warning and Reset Core Audio warning restyled as consistent alert-style callouts (text unchanged).
4. **Typography/spacing:** consistent section-header style across all 11 pages via `SurfaceTokens.swift`-style shared constants; consistent row heights.
5. **HUD placement review:** capture current placement screenshots for Andrew; adjust only if he has pre-specified a change, else report options.
6. **Theme seam** if any residue remains (consumer-side only).

## Acceptance criteria
- Zero truncated labels at default sizes (walk every page + popover states).
- All four themes render consistently.
- `git diff` contains no binding/logic/string-meaning changes.
- `swift test` zero new failures.

## Validation commands
`swift build` · `swift test` · manual walkthrough of every page and popover state in all 4 themes · Dexter checks (ticker, watermark, animation) · one full dictation loop.

## Screenshots
`docs/refactor_baseline/packet_15/`: every Settings page; popover states; the callouts; before/after pairs for each fixed truncation.

## Commit
`style(ui): packet 15 — visual polish (truncation, spacing, callouts; zero behavior change)`

## Rollback
Single revert; purely cosmetic.

## Final report — use exactly this template
```markdown
## Packet Result
- Packet: 15 — Visual Polish
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues: (HUD placement options if not pre-specified)
- Rollback required: No/Yes
- Next recommended packet: as Andrew directs (12B/13/14 gates)
```

--- END PACKET 15 PROMPT ---

---

## 22. Standard Final Report Template for Sonnet

Every packet ends with this exact template (already embedded in each prompt above; reproduced here as the canonical copy):

```markdown
## Packet Result

- Packet:
- Branch:
- Commit hash:
- Pushed: Yes/No
- Files changed:
- Files inspected but not changed:
- Forbidden files touched: No/Yes
- Tests run:
- Test result:
- Targeted tests:
- Manual validations:
- Screenshots captured:
- Feature-loss checklist rows completed:
- Dexter preservation checks:
- Known issues:
- Rollback required: No/Yes
- Next recommended packet:
```

Rules for filling it: "Files changed" lists every path in the commit; "Files inspected but not changed" proves the required reading happened; "Forbidden files touched" must be **No** — a Yes means the packet failed its own rules and must be reported before any push; "Test result" states counts vs the Packet 01 baseline; "Known issues" must include every mandated inventory/finding the packet's prompt demands (lifecycle inventories, adoption gaps, grep hit lists); "Dexter preservation checks" is never "n/a" after Packet 01.

---

## 23. Risk Corrections / Improvements to the Original Fable Plan

Tightenings applied in this handoff pack relative to `DexDictate_Fable5_UIUX_Recovery_Plan.md`, specifically because the executor is Claude Sonnet running without cross-session memory:

1. **Packet 09 formally split into staged commits (09A flag-off build, 09B default flip).** The original plan said "hide, don't delete"; the pack makes the flip its own revertible commit so the old popover is restorable with one revert even mid-packet.
2. **"Move view intact" hardened into a mandatory lifecycle inspection with a stop condition** (Packets 03–08). The original plan flagged this risk; the pack makes the inventory a required report artifact even when clean, because a silent "looked fine" is exactly where an executor loses `onAppear`-armed behavior (route-health polling, permission polling, idle benchmark scheduling).
3. **Packet 05 defaults to button-not-embed for Per-App Rules.** The original plan preferred embedding the sheet content; embedding a complex AppKit sheet is where an eager executor starts rewriting insertion-adjacent UI. The pack inverts the default: keep the existing sheet, embed only if trivially clean, record the decision.
4. **Packet 03 no longer removes the popover's Restore Defaults** (duplication allowed until Packet 09) and defers the icon-grid upgrade to Packet 15 — migration packets are now strictly move-only, popover edits are quarantined to Packets 02 (gear only) and 09.
5. **Packet 07 explicitly parks benchmark automation cadence for Packet 08** and forbids touching promotion logic; the original plan mentioned this in passing — the pack makes it a tracked handoff (07's report must state where the controls live for 08).
6. **Storage-key protection is now mechanical, not aspirational:** every migration packet requires `git diff | grep AppStorage`-style verification, and Packet 10 (renames) explicitly handles the persisted-tag trap (rename tag *display*, never stored values).
7. **Screenshots are mandatory for every UI-touching packet** (03–09, 11, 12A/B, 13, 15), with a defined "blocked on screenshots = no push, report" behavior instead of the plan's softer "capture requirements".
8. **Packet 12B additionally protects the legacy standard-popover files** hidden by Packet 09 — the original plan bundled "cleanup old duplicate UI paths" loosely; the pack makes deleting the legacy popover a separately-approved decision so 12B can't over-delete.
9. **Packet 13 (Smart Cleanup) further gated and further constrained:** earliest after Packet 08 (a page needs the shell + taxonomy), recommended after Packet 10; cleanup is post-delivery-only in its first form (the plan allowed a clean-before-insert future — the pack forbids it for this packet, removing all insertion-latency risk); a `SettingsMigration.swift` dependency is an explicit stop.
10. **Packet 14 (Live Preview) pushed to last and hardened:** the plan had it as Phase 7 mid-sequence; the pack schedules it after Packet 15, alone, with three added teeth — no new audio taps under any circumstance, a mandatory stop if no observable stream exists outside forbidden files, and the byte-identical invariant test as a permanent, separately-committable guard.
11. **Git hygiene made explicit for this repo's real state:** `.resurrection/` churn and `pre_fable/` are named allowed-dirt that must never be staged; `git add -A` is banned; never-stage list includes `benchmark_baseline.json`/`baseline.csv`/`SNAPSHOT/` (benchmark runs during validation would otherwise dirty them into a UI commit).
12. **Packet ordering change vs the plan's numbering: none.** The spine (01→02→03…08→09→10→11→12A→15, gated 12B/13/14) matches the plan; the only sequencing correction is moving Live Preview from mid-sequence to last, for the reason in item 10.
13. **File-name corrections from repo inspection:** the commands editor is `CustomCommandsSheet.swift` (not a "VoiceCommandsView"); popover composition involves `ControlsView.swift`, `FooterView.swift`, `HistoryView.swift`, `PermissionBannerView.swift`, `PopoverSizing.swift`, `SurfaceTokens.swift`; the experimental surface is the nine `Dex*.swift` files under `Sources/DexDictate/ExperimentalUI/`. Packet prompts use these real names so Sonnet doesn't hunt.

No serious flaw was found in the original plan's strategy; all corrections are executor-safety tightenings.

---

## 24. First Recommended Sonnet Task

```text
Packet 01 — Baseline Freeze
```

Hand Sonnet the Packet 01 prompt (Section 6) verbatim, alone, in a fresh session.

**However: no implementation — including Packet 01's tag and commit — should begin until Andrew has reviewed and approved, from `DexDictate_Fable5_UIUX_Recovery_Plan.md`:**

- the **product architecture** (Section 5),
- the **navigation model** (Section 6),
- the **settings taxonomy** (Section 11 — the 11 pages and their contents),
- the **mode names** (Section 7).

Those four decisions determine which file every control moves into. Approving them first costs nothing; changing them after Packet 03 costs a packet each.

*End of handoff pack.*
