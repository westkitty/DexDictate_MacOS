# DexDictate UI/UX Recovery and Refactor Plan

**Author:** Fable 5 (assessment pass — no code, no implementation claims)
**Date:** 2026-07-09
**Sources:** `DexDictate_Fable5_Assessment_Packet.md`, `DexDictate_Feature_Function_Baseline.md`, `DexDictate_Feature_Loss_Checklist.md`, `DexDictate_Remote_Ollama_Stack_Baseline.md`, `DexDictate_Fable5_Screenshot_Packet.zip` (59 frames extracted from `BetterCapture_2026-07-09-02.44.57.mov`, reviewed directly)
**Baseline commit:** `9eea598f11b77352f094af68ebd4f71f36dac0ef` (safety tag `pre-fable-audit-20260709-0222`)

> Note on materials: all four Markdown baselines and the screenshot zip were available and were read. The screenshots were extracted and inspected frame-by-frame; visual conclusions below are grounded in specific filenames, not hypothesized. No `file://` links were relied on beyond the actual files present in the repository.

---

## 1. Executive Verdict

**DexDictate is feature-rich and UI-buried. The correct move is reorganization, not removal.**

1. **Feature-rich but UI-buried: confirmed.** The app has production-grade subsystems most commercial dictation tools lack — audio route recovery with a retry planner, an Objective-C exception bridge around AVAudioEngine taps, focus-mismatch guards, secure-field copy-only fallback, clipboard restore with a payload cap, on-device benchmarking with model auto-promotion, learned corrections, per-app insertion rules, and Siri App Intents. Almost none of this is discoverable. The Help window (frames `006`–`031`) has **19 sidebar sections** — the help system is larger and better organized than the app's own settings, and it spends its pages documenting where things are hidden (e.g. frame `010`: "Accuracy Retry (opt-in) — Found at: Quick Settings → Benchmark → Optimization → Accuracy Retry toggle"). When your help file needs a three-level path to describe a checkbox, the information architecture has failed, not the feature.

2. **The core app should be preserved.** Engine, audio capture, recovery, insertion, and output pipelines are tested (382/382 passing at baseline), hardened, and explicitly gated as do-not-touch. Nothing in the screenshots suggests engineering problems; everything suggests *presentation* problems.

3. **The UI needs reorganization, not feature removal.** Every failure visible in the screenshots is an information-architecture failure: expert tooling in the daily popover (frame `046` shows a raw benchmark session ID string and a "medium.en Queued" run inside the menu-bar surface), settings buried below "Quit App" (frame `037`), destructive actions with the strongest visual weight (frames `003`/`032`: the red "Turn Off Dictation" button is the most prominent element in the idle popover), and two parallel UIs (standard + state-first) doing the same job with different styling.

4. **Fable recommends a behavior-preserving refactor**, staged so that no packet touches the audio engine, event tap, clipboard, or insertion pipelines. The refactor is almost entirely *view relocation*: the settings content already exists; it needs a real Settings window to live in, a popover slimmed to daily-driver essentials, and one consistent vocabulary of names.

5. **Biggest risks**, in order:
   - **Regression by relocation** — moving a view that silently owns behavior (e.g. a card whose `onAppear` starts route-health polling) and losing the behavior. Mitigation: move views intact, one packet per surface, feature-loss checklist after each packet.
   - **Dexter flattening** — a "clean up the popover" pass that quietly deletes the watermark, ticker, or launch animation because they're the easiest things to cut. Mitigation: Dexter elements get their own settings page and explicit acceptance criteria in every packet.
   - **Scope bleed into the engine** — live transcription or Ollama work leaking into UI packets. Mitigation: those are separate, later, explicitly gated phases.
   - **The experimental UI limbo** — keeping two full UI paths indefinitely doubles every future change. Mitigation: a deliberate adopt-then-retire plan (Section 17, Phase 10).

6. **The first thing Andrew should approve before implementation starts:** the product architecture and navigation model (Sections 5–6) plus the settings taxonomy (Section 11) and mode names (Section 7). Everything downstream — every Antigravity packet — is mechanical once those three decisions are signed off. Do not let Antigravity start Packet 1 until the taxonomy is approved, because the taxonomy determines which file every control moves into.

---

## 2. Product Diagnosis

### What DexDictate currently is

A macOS menu-bar dictation app with a local-first Whisper engine, wrapped in three overlapping UI generations: (a) a standard popover with a folding `QuickSettingsView` card stack, (b) a constellation of detached AppKit windows/sheets (History, Custom Vocabulary, Voice Commands, Per-App Insertion Rules, Benchmark Capture), and (c) an opt-in experimental "state-first" popover with its own Nano HUD, command palette, Dexter feed, and duplicate settings hub. On top sits a strong, genuinely distinctive brand layer: Dexter the sacred dog, with launch animations, randomized watermarks, a marquee ticker, regional profiles, and quote packs.

### Why the current UI/UX is failing — separated by dimension

**Engineering quality: strong.** The baseline documents and test suite describe a hardened engine. The fragile lists are known and fenced. This is not a rescue of code; it is a rescue of presentation.

**Feature depth: excessive for the container it lives in.** The popover is a ~300pt-wide surface hosting what is functionally a full preferences application: 6+ collapsible cards (Input, Output, Accuracy & Speed, Transcription Engines, Profiles & History, Appearance & System, Benchmarks & Corpus, Experimental UI), each of which would be a page in a normal app's Settings window. The container is wrong, not the content.

**Visual design: inconsistent, not incompetent.** The dark theme, monospace ticker, and Dexter art have a real identity. But: truncated buttons ("Import Mo…", "Run Bench…", "Restore Stab…" in frame `010`'s embedded screenshot; "Midd…", "Hol…" chips in frame `056`), centered floating label stacks with no grouping ("Ready / TRIGGER / Middle Mouse / Scheduled" in frames `003`/`032`), a theme seam where the popover header renders light while the body is dark (frame `048`, Minimalist theme), and body text rendered directly over the watermark (frame `001`, blue result text over Dexter's face).

**Information architecture: the core failure.** Evidence:
- Settings entry is *below* "Quit App", "Restore Defaults", and "About" in the scroll order (frame `037`).
- Vocabulary and Voice Commands — headline power features — are two small buttons inside the *Input* card, under Route Health diagnostics rows (frame `041`). Vocabulary is not an input concern.
- The Accuracy & Speed card's own subtitle admits the problem: "Model choice, tail timing, smart retry, and **hidden context biasing**" (frame `041`).
- Accuracy Retry lives at Quick Settings → Benchmark → Optimization (per the Help window, frame `010`) — a quality feature filed under an expert tool.
- Benchmarks & Corpus expands inline in the popover with five buttons, a disabled button, a raw session-ID string, and a queue status (frame `046`).

**Onboarding: good, and underused.** The four-page wizard with looping video is high quality (baseline docs; embedded still in frame `006`). The problem is that everything the wizard teaches (hold-to-talk, trigger choice) is not reinforced by the popover afterward — the popover shows "TRIGGER / Middle Mouse" as floating text rather than an affordance.

**Advanced-user affordances: present but scattered.** Power users must know that vocabulary is under Input, retry is under Benchmark, per-app rules are at the bottom of Output, and the benchmark lab is behind a card toggle. Even experts dig.

**Beginner-user overload: severe.** A first-time user opening the popover sees a ticker, a history panel, a floating state stack, a file-transcription button, and a large red destructive button — before any record affordance. There is no obvious "press this to dictate" in the idle standard popover (frames `003`, `032`, `034`); the primary action is a hardware trigger the popover only names in passing.

**Dexter identity: strong asset, currently competing with usability in two places and underexposed in others.** The watermark sits behind body text and controls in the standard popover (frames `001`, `041`), reducing legibility, while the launch animation, quote packs, and regional profiles — genuinely differentiating — are configured in a generic "Profiles & History" card with no celebration. The experimental UI's "Dexter Feed" and inline quote ("That was tolerable. Barely." — frame `056`) show the *right* instinct: Dexter as commentary layer, not as background noise under text.

---

## 3. Visual Evidence Assessment

All references are to `screens/<filename>` in `DexDictate_Fable5_Screenshot_Packet.zip`.

### Standard popover (frames 001, 003, 004, 032, 034, 037)

- **`001_00m05.897s.png`** — post-dictation state. Findings: DEX FEED ticker at top (good identity, good placement); a history card and the current result rendered as centered blue text **directly over the Dexter watermark**, hurting legibility; a "TRIGGER / Middle Mouse" floating label pair; a green "Pasted into active app" pill (excellent feedback — keep); "Retry Last in Accuracy Mode" and "Learn Correction" buttons (excellent features, but presented as bare centered buttons with no grouping); an orphaned "Scheduled" label with no visible referent; "Transcribe File…" as a permanent large button.
- **`003_00m28.713s.png` / `032` / `034`** — idle state, plus the launch brand card visible at left in `003` (Dexter + mic + "Speak. Dictate. Done." — this asset is genuinely good). Findings: **the most visually prominent element in the idle popover is the red "Turn Off Dictation" button**, with "Quit App" second. The primary user goal (start dictating) has no button at all — it's represented by the floating "Ready / TRIGGER / Middle Mouse / Scheduled" text stack centered over the watermark. Destructive prominence inverted from user intent. The watermark art rotates between frames (`032` vs `034` show different Dexter poses) — the randomization works and is charming; its *placement under interactive content* is the problem.
- **`037_01m54.600s.png`** — scrolled to bottom: "Quick Settings — Show pinned controls and folded panels" appears **below** Quit App, Restore Defaults, About, and the version string. Settings are the last discoverable item in the app.

### Quick Settings card stack (frames 041, 044, 046, 048, 050)

- **`041_02m35.538s.png`** — Input card open: Route Health diagnostic rows (Active Input / Recoveries / Last Recovery — diagnostics content) sit directly above "Custom Vocabulary" and "Voice Commands" buttons (content/output features) and an "Input: Middle Mouse" row (trigger config). Three unrelated domains in one card. Below, the Output card exposes six toggles plus Per-App Insertion Rules with a "Manage…" button. Simultaneously, a detached **Custom Vocabulary** window floats at left: a mostly-empty grey pane with the input fields pinned at the bottom edge — visually unfinished.
- **`044_02m50.155s.png`** — the card stack continues: "Accuracy & Speed", "Transcription Engines" ("Live-preview captions, command detection, and which engine dictates"), "Profiles & History" ("Flavor profile, ticker behavior, stats, and persistence"), "Appearance & System". Four more full settings domains stacked in the popover scroll. Behind it, the detached **Per-App Insertion Rules** window shows dense numbered how-to prose and an orange warning ("'Replace Entire Field' sends Cmd+A then Cmd+V. It destroys all existing text in the focused field…") — the right warning, in a wall-of-text presentation.
- **`046_03m31.327s.png`** — "Benchmarks & Corpus" expanded **inside the popover**: five buttons (one disabled), a raw session identifier (`benchmark-capture-20260709T064828Z`), "Current Run / medium.en / Queued", and "No cached benchmark results for the current preset yet." This is a lab bench inside a menu-bar popover. The Benchmark Capture window itself (visible behind) is fine — the *entry point and status* don't belong in the daily surface.
- **`048_04m08.758s.png`** — theme seam: with the Minimalist theme mid-selection, the popover header band renders light while the body stays dark. Also visible: Appearance & System card with Appearance dropdown, Status Color swatch + Reset, sound toggles, Launch at Login, Menu Bar Style prose and a wide "DexDictate" style preview button — a full General-settings page compressed into a card.
- **`050_04m27.733s.png`** — same card with "Experimental UI — Preview surfaces — off by default. No dictation behavior changes." The experimental gateway lives at the bottom of an appearance card.

### Help window (frames 006, 010, 014, 018, 023, 028)

- **`006_00m39.737s.png`** — Help sidebar: Welcome, Getting Started, Permissions, Trigger Setup, Recording & Audio, Transcription, Output & Pasting, Transcription History, Custom Vocabulary, Voice Commands, Profiles, Appearance & …, Floating HUD, Safe Mode, Benchmarking, Shortcuts & Siri, Diagnostics, Experimental UI, About — **19 sections**. This sidebar is, almost verbatim, the settings taxonomy the app itself lacks. Note the tip: "Tap the version string in the footer five times to reopen the onboarding screen" — a hidden gesture documented only in help.
- **`010_00m46.318s.png`** — Transcription page documents: "Accuracy Retry (opt-in) — Found at: Quick Settings → Benchmark → Optimization → Accuracy Retry toggle." The embedded UI screenshot shows a checkbox stack (Trim Leading/Trailing Silence, Trailing Trim Experiment, Accuracy Retry, Correction Sheet) and truncated buttons ("Import Mo…", "Run Bench…", "Restore Stab…"). "Trailing Trim Experiment" — an experiment flag — sits beside daily-quality toggles.
- **`014_00m56.240s.png`** — Appearance help: four themes (System, Cyberpunk, Minimalist, High Contrast), five menu-bar icon styles (Mic + Text, Mic Only, Custom Icon from 18 bundled icons, Logo Only, Emoji). Real personality features, currently described rather than showcased.
- **`018_01m02.420s.png`** — Safe Mode help: a real safety feature ("low-risk preset: Hold to Talk trigger, clipboard-only output, no sound effects") that is discoverable mostly through documentation.
- **`023_01m06.762s.png`** — Shortcuts & Siri: three App Intents (Start/Stop/Toggle Dictation). A shippable, marketable feature that appears nowhere in the app UI.
- **`028_01m16.133s.png`** — Experimental UI help enumerates the duplicate surface set: State-first Popover, Nano HUD, Command Palette, Dexter Feed, All Features, Switch UI. Confirms full duplication of settings access ("Every DexDictate feature is accessible without switching surfaces").

### Experimental state-first UI (frames 056, 058)

- **`056_05m54.288s.png`** — the state-first popover is **structurally better** than the standard one: a clear state hero (mic icon + "Ready"), a "Permissions OK" pill, engine/trigger chips, a last-transcription field, an inline Dexter quote ("That was tolerable. Barely."), and four clean rows (Settings & History, All Features, Commands ⌘K, Switch UI). Problems: chips truncate ("Midd…", "Hol…"); the engine chip exposes "Parakeet TDT 0.6B v3" — an engine that must not be presented as the solved live path; there is still no primary record *button* for mouse-first users.
- **`058_06m26.793s.png`** — the experimental "Settings & History" window plus the Nano HUD strip ("Ready" with mic glyph — compact and good). Its Quick Settings header reads "Pinned controls stay visible. Deeper tuning is folded into panels" — the same folding pattern as the standard UI, restyled. Pinned Controls (Trigger Mode Hold/Toggle segmented control, Input and Model dropdowns side-by-side, Auto-Paste and Safe Mode checkboxes) are a genuinely good "daily six" cluster worth adopting.

### Summary of visual verdicts

| Verdict | Evidence |
|---|---|
| Crowded / over-nested popover | 037, 041, 044, 046 |
| Destructive action has top prominence; no primary record button | 003, 032, 034 |
| Expert tooling in daily surface | 046 (benchmark queue in popover) |
| Truncated controls / doesn't fit available space | 010 (embedded), 056 chips |
| Wrong feature grouping | 041 (vocabulary under Input; diagnostics beside triggers) |
| Theme inconsistency | 048 (light header / dark body seam) |
| Dexter watermark competing with text | 001, 041 |
| Dexter working well | 003 (launch card), 001/032 (ticker), 056 (inline quote), rotating watermarks in idle states |
| Duplicate UI path confirmed | 028, 056, 058 |
| Help system substituting for IA | 006–031 (19 sections; buried-path documentation) |

---

## 4. Core Product Principle

> **DexDictate is a serious dictation engine with a dog at the front desk.**
>
> The engine is invisible, local, and trustworthy: press your trigger, speak, and correct text lands where you were typing — every time, even when microphones vanish or focus shifts. The daily surface shows only what a dictating user needs *right now*: state, result, and one obvious action. All depth — vocabulary, commands, models, benchmarks, insertion rules, diagnostics, remote cleanup — lives one deliberate step away in a real macOS Settings window, organized so an expert can find any control in two clicks. Dexter is the voice and face of the product — he greets you at launch, comments on your work in the ticker, and hosts onboarding — but he never stands between your eyes and your words.

Operationally this means four rules that resolve every design question below:

1. **Popover = today.** State, primary action, last result, quick history, and Dexter's ticker. Nothing that a user wouldn't touch during a normal dictation day.
2. **Settings window = configuration.** Every toggle, dropdown, and manager sheet gets a page in one window with a sidebar. No folding cards, no settings-behind-Quit.
3. **One name per concept.** Every mode/feature has exactly one user-facing name used in popover, settings, help, and history tags (Section 7).
4. **Dexter frames content; he never underlays it.** Watermarks live in empty states, headers, and dedicated zones — never beneath body text or controls.

---

## 5. Proposed Product Architecture

Six surfaces, each with a single job:

1. **Menu-bar popover (compact, fixed-height, non-scrolling for core content).** Daily driver: state hero, primary record button, last result with contextual actions (Quality Retry, Learn Correction), status line (mic · model · mode), quick history (last 3 + "Open History"), ticker, error/recovery banner slot. Settings icon in header. No settings content, no benchmarks, no file transcription button in the default layout (moved to overflow menu), no Quit in primary visual weight.
2. **Settings window (new; the centerpiece of this refactor).** A standard macOS settings window (`NavigationSplitView`-style sidebar, fixed width pages) absorbing: all QuickSettingsView cards, the Vocabulary and Voice Commands sheets' entry points, Per-App Insertion Rules, model management, benchmark entry, Dexter/profile configuration, diagnostics, and (future) Smart Cleanup. Eleven pages (Section 11).
3. **History & Corrections window (existing, kept detached).** Already high quality per baseline. Becomes the single home for transcripts, search, export, learned corrections. Reachable from popover ("Open History") and Settings → History.
4. **Benchmark Lab window (existing Benchmark Capture window, kept detached, renamed "Benchmark Lab").** Golden-prompt capture, WER results, model promotion review. Entry from Settings → Models & Accuracy only. All benchmark status leaves the popover.
5. **HUD layer (existing Floating HUD + adopted Nano HUD pattern).** Recording state and level meter near the user's work; the future home of Live Preview captions (Section 13). Never steals focus.
6. **Onboarding wizard (existing, preserved intact).** Four-page video wizard, plus one added page slot in the future for choosing "Simple vs. Full" starting layout (Section 8). Re-entry moves from the hidden five-tap gesture to an explicit "Replay Onboarding" button in Settings → General (the gesture can stay as an easter egg).

The experimental state-first UI is not a seventh surface: its best components (state hero, Permissions pill, pinned "daily six", Nano HUD, inline Dexter quote, command palette) are **adopted into the standard surfaces**, and the duplicate path is retired at the end (Section 17, Phase 10) — only after the standard UI has absorbed what made it good.

---

## 6. Proposed Navigation Model

### Surface map

| Surface | Purpose | User type | Contains | Deliberately excludes |
|---|---|---|---|---|
| **Popover** | Dictate today | Everyone | State hero; Start/Stop button; trigger+mode chip; last result + Pasted/Copied badge; Quality Retry + Learn Correction (contextual); mic·model status line; last 3 history rows; ticker; error banner; footer: Settings…, ⋯ overflow (Transcribe File…, Safe Mode toggle, Pause Dictation, Quit) | All settings cards; benchmarks; route-health numbers; vocabulary/commands editors; experimental toggles |
| **Settings window** | Configure everything | Everyone (progressive) | 11 sidebar pages (Section 11) | Live dictation controls; transcript content |
| **History & Corrections window** | Review and fix the record | Everyday + advanced | Search, export, clear, undo-delete, learned-correction workflow, retry-from-history | Settings |
| **Benchmark Lab window** | Validate and promote models | Advanced | Corpus capture, golden prompts, WER runs, promotion review | Anything needed daily |
| **HUD** | Glanceable state while working | Everyone | Recording/processing state, level meter; (future) live preview captions | Buttons that steal focus; settings |
| **Onboarding wizard** | First run | New users | Welcome, Permissions, Trigger, Completion (+future layout choice) | Advanced configuration |

### Where each navigation element lives

- Popover header: power toggle (left) · "DexDictate" title · Help (opens Help window) · **gear (opens Settings window)** — settings promoted from below-Quit to the header.
- Popover footer: quiet text links, macOS-menu-style: `Settings… ⌘,` · `⋯` overflow · version string.
- Settings sidebar: 11 items, always visible, no collapsing (Section 11).
- Detached windows are opened from named buttons, never from inside folded cards: History from popover + Settings → History; Vocabulary/Commands editors from Settings → Vocabulary & Commands; Per-App Rules from Settings → Output & Insertion; Benchmark Lab from Settings → Models & Accuracy.
- Command palette (⌘K, adopted from experimental UI): optional accelerator overlaying the popover, searchable actions ("Open Vocabulary", "Toggle Safe Mode", "Retry Last"). Advanced-user affordance that costs beginners nothing.

---

## 7. Proposed Mode Taxonomy

Two orthogonal axes plus named features — the current confusion comes from mixing *trigger styles*, *pipeline behaviors*, and *correction tools* into one vocabulary ("accuracy preset" vs "accuracy retry" vs "smart retry" vs "balanced").

### Axis 1 — Trigger Style (how recording starts/stops)

| Name | Short label | User-facing description | Technical behavior | Default | UI location |
|---|---|---|---|---|---|
| **Hold to Talk** | Hold | "Hold your trigger, speak, release to transcribe." | Trigger-down starts capture (with 750ms pre-roll buffer), trigger-up stops; adaptive tail delay before close | **On** (default trigger: Middle Mouse) | Settings → Dictation; shown as chip in popover |
| **Toggle Dictation** | Toggle | "Press once to start, press again (or pause) to stop." | Trigger toggles capture; silence timeout auto-stops | Off | Settings → Dictation |

("Long dictation" is not a separate mode — it is Toggle with a longer silence timeout. The silence-timeout slider gets the caption "For long dictation, raise this or turn it off.")

### Axis 2 — Output Behavior (where text goes)

| Name | Short label | Description | Technical behavior | Default | UI |
|---|---|---|---|---|---|
| **Insert at Cursor** | Insert | "Types the result into the app you're using." | Accessibility insertion when possible, synthetic paste otherwise; focus-mismatch guard; clipboard restore | **On** | Settings → Output & Insertion |
| **Copy Only** | Copy | "Puts the result on the clipboard; you paste it." | No insertion; also the automatic fallback for secure fields and focus mismatch | Off (but auto-engaged by guards) | Settings → Output & Insertion; per-app rules can force it |
| **Safe Mode** | Safe | "One switch to the most cautious behavior." | Preset: Hold to Talk + Copy Only + no sounds; snapshots and restores prior settings | Off | Popover overflow + Settings → Diagnostics & Recovery |

### Pipeline features (one name each, used everywhere)

| Name (replaces) | Short label | User-facing description | Technical behavior | Default | UI |
|---|---|---|---|---|---|
| **Standard Dictation** (batch/final transcription) | — | "Speak, release, get your text." | Record → resample 16kHz → silence trim → single-batch local Whisper → output | Always on; the product | Implicit |
| **Model Preset: Fast / Balanced / Accurate** (was "balanced preset", "accuracy preset", "stable/fast/conservative" end presets) | Preset | "Choose speed vs. accuracy for the model." | Decode/param presets for the active Whisper model | Balanced | Settings → Models & Accuracy |
| **Quality Retry** (was Accuracy Retry / Smart Retry / "Retry Last in Accuracy Mode") | Retry | "If a result looks wrong, DexDictate re-transcribes the same audio more carefully." | Re-runs cached buffer with higher-quality params; auto or via button; history-tagged "Quality Retry" | Auto-suggest on | Settings → Models & Accuracy; contextual button in popover: **"Retry with Higher Quality"** |
| **Review Before Insert** (was Correction Sheet) | Review | "See and edit the text before it's typed." | Confirmation sheet between transcription and output | Off | Settings → Output & Insertion |
| **Vocabulary** (Custom Vocabulary + learned corrections, presented as one system with two sources) | Vocab | "Words DexDictate always gets right — yours and learned." | Text replacements + biasing; learned corrections feed the same list tagged "Learned" | On (empty) | Settings → Vocabulary & Commands; "Learn Correction" in popover/History adds entries |
| **Voice Commands** | Commands | "Say it, DexDictate does it — 'scratch that', your macros." | Keyword → action mapping via CommandProcessor | On (built-ins) | Settings → Vocabulary & Commands |
| **Context Priming** (was Context Injection / "hidden context biasing") | Priming | "Reads the text around your cursor so names and jargon come out right." | Feeds last ~200 chars of focused field to Whisper as prompt | Off | Settings → Models & Accuracy |
| **Live Preview** (future; Section 13) | Preview | "See provisional words in the HUD while you speak. Final text is still checked before it's typed." | Streaming provider → HUD captions only; batch Whisper remains committed output | Off (Phase L1) | Settings → Dictation (once shipped) |
| **Live Typing** (future, opt-in; Section 13) | Live Type | "Types provisional words as you speak. Experimental." | Streaming partials inserted with replacement protocol | Off, behind Advanced | Settings → Advanced (Phase L3) |
| **Smart Cleanup** (future; Section 14) | Cleanup | "After transcription, your own server tidies the text." | Final transcript → OpenAI-compatible endpoint → cleaned text; raw always preserved; fallback to raw on failure | Off | Settings → Smart Cleanup |

**Terminology retirements:** "Accuracy Retry", "Smart Retry", "Accuracy Mode", "Correction Sheet", "Context Injection", "Optimization" (as a group name), and "Benchmark" as a settings-path segment for non-benchmark features. Each is renamed everywhere (UI strings, help, history tags) in one dedicated packet (Packet 8) so the rename is atomic and greppable.

---

## 8. Beginner vs Advanced Experience

### First-time user path

1. Launch animation (kept, as is — it is 3 seconds of brand).
2. Onboarding wizard: Welcome → Permissions → Choose Your Trigger → Done (all existing).
3. First popover open: state hero says "Ready — hold Middle Mouse and speak", with the Start Dictation button as the visible alternative. The ticker runs. Nothing else demands attention.
4. First successful dictation: green "Pasted into active app" badge; Dexter ticker reacts (existing quote-pack behavior).
5. If anything breaks (permission revoked, mic gone): the error banner slot in the popover shows one plain sentence and one button ("Microphone unavailable — Fix…" → opens Settings → Diagnostics & Recovery with the relevant row highlighted).

### Everyday user sees

The popover only (Section 10). Their total configuration exposure: the trigger chip, the mic·model status line (clickable → Settings), and the overflow menu. They may never open Settings and lose nothing.

### Advanced users expand into

- **Settings window**: all 11 pages, always two clicks from anywhere (gear icon → sidebar).
- **Command palette (⌘K)**: direct action access.
- **Benchmark Lab**, **History & Corrections**, **Per-App Rules** — detached tools launched from their settings pages.
- **Advanced page**: experiment flags, live-typing opt-in (future), benchmark automation cadence, experimental UI switch (until retired).

### Where the sharp tools live

- **Diagnostics live in Settings → Diagnostics & Recovery**: route health stats (moved out of the Input card), permission status rows, recovery log, Reset Core Audio.
- **Risky controls are visually fenced**: Reset Core Audio gets a bordered "System Repair" group with its admin-prompt warning; "Replace Entire Field" per-app preset keeps its destructive warning but formatted as a proper macOS alert-style callout, not orange prose.
- **Experiments live in Settings → Advanced only** ("Trailing Trim Experiment" moves here from beside daily toggles).

### How users avoid being overwhelmed

Not with an "expert mode" switch (two modes double testing and hide features unpredictably) but with **placement**: the popover has no settings; each settings page leads with its three most-used controls and pushes rarities into a "More" group at the bottom of the page; experiments and one-time repairs are quarantined on the last two sidebar pages. Progressive disclosure by geography, not by a global mode flag. (If Andrew later wants a "Simple popover" preference — hiding history rows and the status line — it fits as one toggle in Settings → General without forking layouts.)

---

## 9. Dexter Identity Integration Plan

Dexter's current problem is placement, not volume: he's *under* the text where he hurts, and *absent* from settings where he'd delight.

| Element | Verdict | Plan |
|---|---|---|
| **Launch animation** (`LaunchIntroController.swift`, 8 randomized MP4s) | Keep prominent, untouched | No behavioral change. Polish allowed later (window level/alignment per baseline packet notes). Fragile-listed; only Packet 9 may touch presentation parameters, nothing else. |
| **Onboarding wizard** (4 pages, looping video) | Keep prominent, untouched | Preserved as-is. Add explicit "Replay Onboarding" button in Settings → General (keep the five-tap easter egg too). |
| **RSS-style ticker** (`FlavorTickerView.swift`) | Keep prominent — it IS the popover's personality | Stays pinned at popover top, full width. Polish: consistent height, no clipping (checklist item), respects Reduce Motion (existing behavior preserved). Gains one new source in the future: Smart Cleanup status lines ("BigMac is thinking…") — flavor, not logs. |
| **Randomized watermark backgrounds** (`WatermarkAssetProvider.swift`) | Keep, **relocate within surfaces** | The single most important Dexter change: watermarks render in *empty states* (empty history, idle hero zone), page headers of the Settings window (small, corner-anchored, per-page rotation), the About page (large), and the HUD idle state. They never render under body text, transcripts, or controls. Same provider, same randomization/no-repeat logic, new placement contract. |
| **Regional profiles** (Australian/Canadian icon packs + quote packs) | Keep, elevate | Get a real home: **Settings → Dexter & Personality**, with profile cards showing the regional icons (currently profiles hide inside "Profiles & History"). Behavior (vocab + quote swap via `ProfileManager`) unchanged. |
| **Dexter quotes** (`FlavorQuotePacks.swift`) | Keep, extend placement | Ticker remains primary. Adopt the experimental UI's inline result quote (frame `056`: "That was tolerable. Barely.") as an optional line under the last result in the popover — off/on toggle in Dexter & Personality. |
| **Dexter Feed (experimental)** | Adopt the concept | The stateful commentary feed folds into ticker + inline quote behaviors; the separate experimental surface retires with Phase 10. |
| **Menu-bar icon styles** (18 bundled Dex icons, emoji option) | Keep, showcase | Move to Settings → General with a visual icon picker grid instead of a dropdown + prose (frame `048` shows the current prose-heavy version). |
| **Themes** (System/Cyberpunk/Minimalist/High Contrast) | Keep | Move to Dexter & Personality (they are identity, not system config). Fix the header/body seam (frame `048`) as a Packet 9 polish item. |

**What remains prominent:** launch animation, ticker, onboarding, menu-bar Dex icons.
**What becomes subtler:** watermarks (relocated to empty zones — still everywhere, never in the way).
**What gets *more* exposure than today:** regional profiles and quote packs (dedicated settings page), icon picker, inline result quotes.
**What is forbidden:** removing any asset, pack, animation, or the randomization behaviors; shipping any packet whose acceptance criteria don't include the Dexter checklist rows (Section 19).

---

## 10. Main Popover Redesign

Fixed content, no scrolling for the core; only the history section may grow by rows. Target ~340pt wide.

```
┌──────────────────────────────────────────┐
│ ⏻   DexDictate                    ?   ⚙ │  header: power / help / SETTINGS
├──────────────────────────────────────────┤
│ ▓DEX▓ /// THAT WAS TOLERABLE. BARELY. //│  ticker (full width, fixed height)
├──────────────────────────────────────────┤
│                                          │
│        ●  Ready                          │  STATE HERO
│        Hold Middle Mouse to talk         │  (state + trigger hint;
│                                          │   Dexter watermark HERE when idle,
│      ┌──────────────────────────┐        │   level meter here when recording,
│      │   🎙  Start Dictation    │        │   provisional captions here in
│      └──────────────────────────┘        │   future Live Preview)
│                                          │
├──────────────────────────────────────────┤
│ LAST RESULT                          ⧉  │
│ "Adversarially critique what we already  │  last transcript (2–3 lines, plain
│  have and come up with anything else…"   │  background — NO watermark under it)
│ ✓ Pasted into Safari                     │  outcome badge (kept as-is)
│ [Retry with Higher Quality] [Learn Fix]  │  contextual: only after low-
│ “That was tolerable. Barely.” —Dex       │  confidence / optional Dex quote
├──────────────────────────────────────────┤
│ HISTORY                                  │
│ 2:32 AM  Adversarially critique what…   │  last 3, click = copy,
│ 2:14 AM  Send the draft to Marcus and…  │  right-click = actions
│ 1:58 AM  Note to self: the tail delay…  │
│ Open History Window…                  ›  │
├──────────────────────────────────────────┤
│ Mic: MacBook Pro Microphone · medium.en  │  status line → click opens Settings
├──────────────────────────────────────────┤
│ Settings… ⌘,        ⋯          v1.7.0   │  footer (⋯ = Transcribe File…,
└──────────────────────────────────────────┘   Safe Mode, Pause Dictation, Quit)
```

**Error/recovery state** replaces the state hero (never a separate dialog):

```
│  ⚠  Microphone unavailable               │
│  Your preferred mic disconnected.        │
│  Using: MacBook Pro Microphone           │
│  [Fix in Settings…]                      │
```

Recovery events reuse the existing route-recovery signals; the banner is one line + one button. Permission failures get the same treatment ("Accessibility permission lost — text will be copied, not typed. [Fix…]").

**Recording state:** hero swaps to level meter + elapsed time + "Release to transcribe" (Hold) or a Stop button (Toggle). **Processing state:** hero shows "Transcribing…" with the existing processing watermark art beside (not under) the label.

**What is intentionally NOT in the popover anymore:**
- Quick Settings card stack (→ Settings window, whole).
- "Turn Off Dictation" as a giant red button (→ header power toggle; confirmation on click).
- "Quit App" button (→ overflow menu, standard for menu-bar apps).
- "Transcribe File…" as a permanent primary-width button (→ overflow; it's an occasional task).
- "Restore Defaults" (→ Settings → General).
- Route health numbers, benchmark status, session IDs (→ Diagnostics / Benchmark Lab).
- The floating "TRIGGER / Middle Mouse / Scheduled" label stack (trigger folds into the hero hint; "Scheduled" surfaces only as a status chip when a scheduled benchmark actually runs, in Settings).

---

## 11. Settings Redesign

One window, sidebar navigation, 11 pages. Order = frequency of use, descending; the last three are deliberately the sharp/rare tools.

| # | Page | Contents | Why here |
|---|---|---|---|
| 1 | **General** | Launch at Login; start/stop sounds; menu-bar icon style (visual grid of the 18 Dex icons, Mic+Text, Emoji…); status color + reset; Replay Onboarding; Restore Defaults | System-integration basics every macOS user looks for first |
| 2 | **Dictation** | Trigger style (Hold to Talk / Toggle segmented); trigger shortcut recorder (mouse + keyboard); silence timeout slider (with long-dictation caption); pre-roll capture note; adaptive tail preset (Stable/Fast/Conservative, renamed captions); *(future)* Live Preview toggle | The core loop's knobs, one page, no nesting |
| 3 | **Audio & Microphone** | Input device picker; automatic-fallback explanation line; input level test meter; silence-trim toggle | Device concerns separated from trigger concerns (currently mixed in the Input card, frame `041`) |
| 4 | **Output & Insertion** | Insert at Cursor vs Copy Only; Use Accessibility API toggle; Review Before Insert; Copy Only in Sensitive Fields; Filter Profanity; clipboard-restore note (informational); **Per-App Rules** table inline (app list + rule; Add Current App; the existing sheet's logic embedded as a page section, destructive "Replace Entire Field" warning restyled as alert callout) | Everything about where text lands; per-app rules stop being a buried detached sheet |
| 5 | **Vocabulary & Commands** | Two tabs or two sections: Vocabulary (replacements table, Learned badge on learned corrections, import/export) and Voice Commands (command list, keyword → action editor, built-ins shown) | The two content-shaping systems, promoted from buttons-inside-Input-card to a destination |
| 6 | **Models & Accuracy** | Active model picker + Import Model; Model Preset (Fast/Balanced/Accurate); Quality Retry (auto / ask / off); Context Priming toggle (renamed, with plain-English caption); "Open Benchmark Lab…" button + last-promotion summary line | Model choice and quality behaviors together; the lab is one click away but its machinery is out of the page |
| 7 | **Smart Cleanup** *(future; page ships with Packet 10)* | Provider on/off; Base URL; Model name; API key (SecureField, placeholder `ollama`); Test Connection / Test Inference buttons + status; tunnel help disclosure (Section 14); failure-fallback explanation ("If cleanup fails, you get the raw transcript — always") | Remote post-processing is a domain of its own; must never look like a transcription-engine choice |
| 8 | **History** | Retention (persist across sessions toggle); stats display (word count, WPM — moved from "Profiles & History" card); Open History Window…; Clear History (with confirm) | History *policy* here; history *content* stays in its window |
| 9 | **Dexter & Personality** | Profile picker (Standard/Canadian/Australian) as visual cards with regional icons; theme picker (System/Cyberpunk/Minimalist/High Contrast); ticker behavior (on/off, speed, Reduce Motion note); inline result quotes toggle; watermark backdrops toggle + "shuffle now"; launch-animation toggle is **deliberately absent** (animation always plays; it's the brand) — only a Reduce Motion system setting affects it | Dexter gets a named home; identity features become discoverable instead of folded |
| 10 | **Diagnostics & Recovery** | Permission status rows (Mic / Accessibility / Input Monitoring) with Fix buttons; Route Health panel (active input, recoveries, last recovery — relocated from Input card); recovery log; Safe Mode toggle + explanation; **System Repair** fenced group: Reset Core Audio (admin prompt warning) | All "when things go wrong" tools in one predictable place |
| 11 | **Advanced** | Experiment flags (Trailing Trim Experiment, etc.); benchmark automation cadence (idle-trigger settings); experimental UI switch (until Phase 10 retirement); *(future)* Live Typing opt-in; developer/debug toggles | Quarantine zone; the page whose existence lets every other page stay clean |

Notes:
- **No page nests disclosure cards.** Sections within a page are flat groups with headers.
- **Search**: v1 ships without settings search; the sidebar is short enough. (Help window already has search.)
- **The Help window keeps its 19 sections** but each "Found at:" path gets rewritten in Packet 8 to the new two-click paths.

---

## 12. History, Corrections, Vocabulary, and Commands Workflow

These four features are one loop — *dictate → review → fix → never see that error again* — currently split across a popover feed, a detached history window, two AppKit sheets buried in the Input card, and a "Learn Correction" button that appears contextually (frame `001`).

**Where each lives:**
- **History** (the record): History & Corrections window. Popover shows last 3 rows as a teaser. Settings → History holds policy only.
- **Learned corrections** (fixes derived from history): created via "Learn Correction" in the popover result area and in the History window; **stored and displayed in Settings → Vocabulary & Commands** with a "Learned" badge, because a learned correction *is* a vocabulary entry with provenance. One list, two sources — this ends the current situation where learned corrections are invisible after creation.
- **Vocabulary** (manual replacements + bias terms): Settings → Vocabulary & Commands, Vocabulary section.
- **Voice Commands** (spoken macros): Settings → Vocabulary & Commands, Commands section.

**Discovery flow (how a user finds all of this without a manual):**
1. A transcript comes out wrong → the popover's result area shows "Learn Correction" right there (existing behavior, kept).
2. Clicking it opens a small two-field sheet (wrong → right), and the confirmation toast says "Saved to Vocabulary — DexDictate will get this right next time," with the word *Vocabulary* linking to the settings page. The feature teaches its own location.
3. In the History window, every entry keeps its existing right-click/row actions (copy, retry, learn correction, delete/undo-delete).
4. Voice Commands are discovered through the built-ins: history rows executed as commands get a "Command: scratch that" tag; clicking the tag opens the Commands page.

**Editing:** Vocabulary is a plain table (term, replacement, source badge, enabled checkbox, delete). Commands are a list with keyword, action, enabled. Both get import/export (existing capability preserved).

**Relation to output:** the pipeline order is documented right on the Vocabulary & Commands page in one caption line: *"After transcription: Commands run first, then Vocabulary corrections, then the text is inserted."* (Matches existing CommandProcessor → VocabularyManager behavior; no engine change.)

---

## 13. Live Transcription Architecture Plan

Live transcription is **not solved**. Parakeet streaming was attempted and failed expectations (stability, threading, CPU contention with batch Whisper). The plan below treats streaming ASR as an untrusted preview layer that may be swapped, and batch Whisper as the only authority over committed text — permanently, until proven otherwise.

### Architecture principle

**Two channels, one authority.**
- *Preview channel:* streaming provider (candidates: FluidAudio/Nemotron, AppleSpeech, a rehabilitated Parakeet, or a future provider) → provisional caption stream → **display-only surfaces** (HUD, popover hero). Provisional text is a `UI artifact`, never enters the output pipeline, never touches History (except optionally as diagnostics).
- *Commit channel:* the existing, untouched batch path (stop → resample → trim → Whisper → commands → vocabulary → output). This channel does not know the preview channel exists.

### Phases

**Phase L1 — Live Preview only (HUD captions).**
- Preview captions render in the HUD strip (Nano-HUD-style) and/or the popover state hero while recording.
- Visual contract: provisional text is *styled as provisional* — dimmed/italic with a "PREVIEW" tag; the final result replaces the caption area with confirmed styling. Users must never mistake preview for committed output.
- Provisional lifecycle: tokens may be rewritten freely by the provider; the UI renders whole-line replacement (no per-token animation) at a throttled cadence (e.g. max 4 updates/sec) to prevent flicker — the known Parakeet symptom.
- Resource guard: the preview provider must run at lower QoS than capture, and must be suspended the instant capture stops so batch Whisper gets the ANE/CPU uncontested (this addresses the documented latency-contention failure).
- Kill switch: a single toggle (Settings → Dictation → Live Preview); any preview-provider crash disables preview for the session and logs to Diagnostics, while dictation continues unaffected.

**Phase L2 — Batch commit remains authoritative (hardening, not a feature).**
- Formalize the invariant with tests: with preview enabled, the committed text is byte-identical to a preview-disabled run on the same buffer. Preview can only ever change pixels, not output.
- HUD shows an explicit handoff: captions fade, "Finalizing…" appears, committed text badge follows. This is the Hybrid Mode from the packet, and it is the *shipping* configuration.

**Phase L3 — Optional Live Typing (opt-in, Advanced page, off by default).**
- Only after L1 has proven stable across at least one release cycle.
- Insertion protocol: append-only with a **mark-and-replace commit** — provisional text is inserted with a recorded range; on stop, the provisional range is replaced by the final Whisper transcript in one AX transaction (or, where AX range-replace is unsupported per-app, live typing is refused for that app via the existing per-app rules mechanism).
- Duplicate-text prevention: the commit replaces the provisional range rather than re-inserting; if the range is invalid (user edited mid-dictation), fall back to Copy Only with a banner — never double-insert.
- Cursor drift & focus safety: reuse the existing focus-mismatch guard on every partial insert, not just at commit; any focus change mid-utterance freezes live typing immediately (preview continues in HUD), and the final commit follows existing focus rules.
- Secure fields: live typing is categorically disabled by the existing secure-field heuristics.
- Latency budget: partials older than ~1.5s are not inserted (stale partials are the flicker/duplication source); the HUD always shows the freshest preview even when insertion lags.

**Phase L4 — Smart Cleanup integration (Section 14).**
- Cleanup applies only to the *committed* transcript, post-Whisper, pre-output (or post-output as a "Cleaned" variant in History — recommended initial form, since it cannot delay insertion). It is never in the live path. Remote Ollama is not a live ASR engine and must not be scheduled as one.

### Parakeet's status going forward

Parakeet is demoted to *one candidate preview provider among several*, benchmarked inside the existing Benchmark Lab (which already measures WER/latency) before it is ever re-enabled by default. The experimental UI currently surfaces "Parakeet TDT 0.6B v3" as a headline engine chip (frame `056`); in the redesigned UI, no streaming provider name appears in the daily surface — the popover says "Live Preview: on/off" and the provider choice lives in Settings → Advanced until one provider earns default status.

### Fallback behavior (all phases)

Preview provider fails to load → dictation proceeds, preview silently off, Diagnostics logs it. Preview crashes mid-utterance → captions freeze then clear, capture unaffected, batch commit unaffected. This is the preservation contract: **batch Whisper output must be provably unaffected by any preview state, including crash states.**

---

## 14. Remote Ollama / Smart Cleanup Architecture

**Placement:** Settings → Smart Cleanup (page 7). It is not a transcription engine and must not appear in Models & Accuracy — conflating ASR providers with LLM cleanup is an explicitly forbidden failure mode.

### Settings page contents

- **Enable Smart Cleanup** (master toggle, default off).
- **Provider:** fixed label "OpenAI-Compatible Server (Ollama, etc.)" — one provider type, no framework.
- **Base URL:** free text field, placeholder `http://127.0.0.1:11435/v1`, shown as an *example*, never prefilled as gospel. Validation: must parse as URL; warn (not block) on non-loopback cleartext hosts: "This address is not local. Without a tunnel, your text will travel unencrypted."
- **Model name:** free text (e.g. `llama3`, `mistral`). No default.
- **API key:** SecureField, placeholder text `ollama`, stored in Keychain.
- **Test Connection** button → `GET {base}/v1/models`; success shows model count and the first few names.
- **Test Inference** button → minimal `POST /v1/chat/completions` ("Reply with OK only.", `stream:false`); success shows round-trip time.
- **Tunnel help** (collapsed disclosure, the one allowed disclosure on the page):
  - The generic tunnel command with placeholders: `ssh -N -L <LOCAL_PORT>:127.0.0.1:11434 <USER>@<HOST>`
  - **The localhost warning, verbatim in spirit:** "`127.0.0.1` always means *this* Mac. If your model runs on another machine, you need a tunnel: then `127.0.0.1:<LOCAL_PORT>` on this Mac forwards to the server. Port 11435 is a common choice because it avoids clashing with a local Ollama on 11434."
  - A note recommending SSH or Tailscale, never raw internet exposure of 11434.
- **Failure behavior statement** (static text): "If cleanup fails or times out, DexDictate delivers the raw transcript unchanged. Cleanup never blocks your dictation for more than N seconds." (N configurable in Advanced later; sensible default ~4s if cleanup-before-insert is ever enabled; the initial implementation should clean *after* delivery, storing the cleaned variant in History next to the raw.)
- **No hard-coded values:** "BigMac", "westcat", and `11435` appear nowhere in code or defaults; `11435` appears only inside example strings. Andrew's setup is a *documentation example*, not a default.

### Data handling rules

- Raw transcript is always persisted in History; the cleaned variant is stored alongside, labeled "Cleaned", with a one-click "Use raw" swap.
- Requests are plain `URLSession` calls to `/v1/chat/completions`. No agent framework, no tool-calling, no streaming requirement.
- Connection state surfaces as a status dot on the Smart Cleanup page and (only when enabled *and* failing) as a one-line popover banner — never as a modal.

### Diagnostics

The Test buttons live on the page itself; Diagnostics & Recovery gains one row ("Smart Cleanup endpoint: reachable / unreachable / disabled") so all health checks share one home.

---

## 15. Feature Preservation Map

| Current Feature | Preserve? | Current Problem | Future Location | Refactor Notes | Validation |
|---|---|---|---|---|---|
| Local Whisper dictation | Yes — untouchable | None (engine); no streaming preview | Engine unchanged; popover hero is its face | UI-only packets never import engine modules | `swift test` (WhisperServiceTests); manual dictation smoke test |
| Hold/toggle triggers | Yes | Named only as floating text in popover | Settings → Dictation; chip in popover hero | Move ShortcutRecorder UI intact | Manual: both trigger styles; InputMonitor untouched |
| Silence timeout | Yes | Slider buried in Input card | Settings → Dictation | Slider + new caption | Manual: toggle-mode auto-stop |
| Accuracy retry → **Quality Retry** | Yes | Found at Quick Settings → Benchmark → Optimization (frame 010); three names | Settings → Models & Accuracy; contextual popover button "Retry with Higher Quality" | Rename in Packet 8; logic untouched | Feature-loss checklist item; low-confidence dictation shows button |
| Correction sheet → **Review Before Insert** | Yes | Name collides with corrections/vocabulary | Settings → Output & Insertion | Rename only | Manual: enable, dictate, sheet appears |
| History (inline + window) | Yes | Inline feed dominates popover | Popover: last 3 rows; window unchanged; policy in Settings → History | Window already high quality — do not redesign | History window search/export/undo-delete |
| Custom vocabulary | Yes | Two small buttons inside Input card; empty-looking editor window (frame 041) | Settings → Vocabulary & Commands | Embed editor as page section; keep VocabularyManager | VocabularyLayeringTests; manual replacement round-trip |
| Voice commands | Yes | Same burial as vocabulary | Settings → Vocabulary & Commands | Same | CommandProcessorTests; "scratch that" manual test |
| Context injection → **Context Priming** | Yes | "Hidden context biasing" (card's own words) | Settings → Models & Accuracy | Rename + plain-English caption | FocusedTextReaderTests; checklist priming test |
| Per-app insertion overrides | Yes | Detached sheet at bottom of Output card; wall-of-text help | Settings → Output & Insertion (inline table) | Restyle warning as alert callout; logic untouched | AppInsertionOverridesManagerTests; Slack copy-only manual test |
| Secure-field fallback | Yes | Fine (invisible by design) | Toggle in Output & Insertion (as today) | None | SecureInputContextTests; password-field manual test |
| Focus mismatch guard | Yes | Invisible; no user feedback on trigger | Automatic; popover banner "Focus changed — copied instead" (new, display-only) | Banner reads existing signal; guard logic untouched | OutputPipelineHardeningTests; focus-switch manual test |
| Clipboard restore | Yes | Invisible (correct) | Informational note in Output & Insertion | Do not alter delays (fragile list) | ClipboardManagerTests; >10MB skip test |
| Mic selection | Yes | Inside Input card with diagnostics | Settings → Audio & Microphone | Picker moves intact | Manual device switch |
| Core Audio recovery | Yes — untouchable | Route Health data crowds Input card | Stats → Settings → Diagnostics & Recovery | Display-only relocation | AudioRecorderRecoveryPlannerTests; unplug-mic manual test |
| Reset Core Audio | Yes | In Advanced card | Diagnostics & Recovery → System Repair fenced group | Keep admin-prompt flow byte-identical | Manual: button prompts for admin |
| Launch at login | Yes | In Quick Settings | Settings → General | Move intact | LaunchAtLoginControllerTests |
| Benchmarking & promotion | Yes | Lab machinery inside popover (frame 046) | Benchmark Lab window (existing, renamed); entry from Models & Accuracy; automation cadence in Advanced | Remove popover benchmark status; window unchanged | BenchmarkPromotionPolicyTests; capture window opens; `benchmark_baseline.json` written |
| Model selection / import | Yes | Truncated buttons in card (frame 010) | Settings → Models & Accuracy | Full-width controls | Manual import of GGML model |
| Onboarding wizard | Yes — fragile-listed | Re-entry hidden behind 5-tap gesture | Unchanged; + Replay button in General | Do not touch video looping logic | OnboardingValidationTests; manual walkthrough |
| Launch animation | Yes — fragile-listed | None | Unchanged | Packet 9 may only adjust window level/alignment if approved | Manual: plays, holds brand card, shrinks |
| Ticker | Yes — fragile-listed | Slight clipping risk noted | Popover top (unchanged position) | Height/clipping polish only in Packet 9 | Checklist: scrolls smoothly, no clipping |
| Randomized backgrounds | Yes — fragile-listed | Renders under body text (frames 001, 041) | Empty states, headers, About, HUD idle — never under text | Same provider + randomization; placement contract changes | Checklist: rotation works, no immediate repeats, never under text (new criterion) |
| Regional profiles | Yes | Hidden in "Profiles & History" card | Settings → Dexter & Personality (visual cards) | ProfileManager untouched | ProfileContentTests; Aussie/Canadian quote + icon swap |
| Floating HUD | Yes | Placement/meter needs review | HUD layer; adopts Nano HUD compactness; future Live Preview host | Keep non-focus-stealing behavior | Checklist: HUD opens on record, meter moves |
| Safe Mode | Yes | Discoverable mainly via Help | Popover overflow + Diagnostics & Recovery | Snapshot/restore logic untouched | Manual: toggle on → hold-only + copy-only; toggle off → settings restored |
| Siri Shortcuts / App Intents | Yes | Invisible in-app | Mentioned in Settings → Dictation footer link | None | Manual: "Start dictation with DexDictate" |
| Experimental state-first UI | Behavior yes, surface eventually retired | Full duplicate path | Best components adopted (hero, pill, pinned six, Nano HUD, ⌘K, inline quote); surface removed in Phase 10 **only after adoption verified** | Staged; approval gate before deletion packet | Feature-loss checklist full pass before and after retirement |
| File transcription (Transcribe File…) | Yes | Permanent primary-width button | Popover overflow menu | None | Manual: transcribe a WAV |

---

## 16. Risk Register

| Risk | Severity | Likelihood | Mitigation | Tests / Validation |
|---|---|---|---|---|
| **Audio engine lifecycle** — a UI packet accidentally changes capture init/teardown ordering | Critical | Low (if packets respect forbidden-files lists) | Every packet lists `AudioRecorderService.swift`, `AudioTapInstaller.m`, `AudioResampler.swift` as forbidden; UI moves never import engine modules | `swift test` full suite per packet; unplug-mic manual test |
| **Core Audio recovery** — relocating Route Health display breaks the observer wiring it piggybacks on | High | Medium | Before moving, confirm the card is display-only; if observers live in the view, extract them to a controller first as its own micro-packet | `AudioRecorderRecoveryPlannerTests`, `AudioRecorderRecoveryFailureTests`; manual route-change test |
| **Event tap** — trigger UI rework touches InputMonitor scheduling | Critical | Low | ShortcutRecorder view moves intact; InputMonitor on forbidden list everywhere | Manual hold/toggle after every packet touching Dictation page |
| **Accessibility insertion** — new Settings window steals focus and perturbs frontmost-app detection during tests | High | Medium | Settings window is a normal window (not floating); insertion tests run with window closed; manual insertion test includes settings-window-open case | `AccessibilityInsertionTests`; manual: dictate into Notes with settings open |
| **Clipboard restore** — timing changed by refactor of output feedback UI | High | Low | ClipboardManager delays fragile-listed; badges read events, never hook the pipeline | `ClipboardManagerTests`; copy-then-dictate manual test |
| **Focus mismatch** — new banner logic interferes with the guard instead of observing it | Medium | Low | Banner subscribes to existing outcome events; zero writes into guard state | `OutputPipelineHardeningTests`; focus-switch manual test |
| **Live transcription** — preview provider destabilizes batch pipeline (the Parakeet failure repeating) | High | Medium (in L1+) | Two-channel architecture; QoS fencing; suspend-on-stop; kill switch; L1 ships display-only; byte-identical-output invariant test in L2 | New: preview-on vs preview-off transcript equality test; CPU contention benchmark via Benchmark Lab |
| **Provider settings (Ollama)** — users point at wrong localhost or expose cleartext endpoints | Medium | High (localhost confusion is expected) | Example-not-default URLs; non-loopback cleartext warning; Test Connection/Inference buttons; tunnel help with localhost explanation | Manual: test buttons against live tunnel and against dead port; unit tests for URL validation |
| **UI overcrowding recurs** — new settings pages accrete future features back into the popover | Medium | Medium | Rule 1 (Section 4) written into CLAUDE/contributing docs; popover has a fixed content contract; new features default to a settings page | Design review gate per future feature |
| **Dexter identity flattening** — polish passes strip watermarks/ticker/animation | High (product-defining) | Medium (it's the path of least resistance) | Dexter checklist rows in every packet's acceptance criteria; fragile-file list includes all Dexter files; Packet 9 is the only packet allowed to touch Dexter presentation | Checklist: ticker scrolls, watermarks rotate, launch animation plays, profiles swap — after every packet |
| **Beginner overload persists** — settings window ships but popover keeps old content in parallel | Medium | Medium | Packet 7 (popover slim-down) has explicit removal criteria; screenshots compared against Section 10 wireframe | Screenshot diff vs wireframe; first-run walkthrough |
| **Hidden advanced tools** — power features become *harder* to reach post-move (three clicks instead of a buried two) | Medium | Low | Two-click rule: gear → page; ⌘K palette as accelerator; "Open X" buttons on pages, not nested sheets | Manual: time-to-reach audit for vocabulary, per-app rules, benchmark lab |
| **Settings migration** — renames (Packet 8) orphan `@AppStorage` keys | High | Medium | Renames change display strings only, never storage keys; any key change goes through `SettingsMigration.swift` with tests | `SettingsMigrationTests`; upgrade-from-v1.7.0 manual test |
| **Experimental UI retirement removes an unadopted behavior** | Medium | Medium | Adoption inventory (Packet 11 prerequisite): list every experimental capability, check each has a standard-UI home, Andrew signs off before deletion | Feature-loss checklist run on standard UI only, before deletion packet |

---

## 17. Behavior-Preserving Refactor Strategy

Staged so no phase mixes UI reshaping with engine risk. Each phase = 1–3 Antigravity packets (Section 18).

- **Phase 0 — Baseline freeze.** Screenshot every surface (there's now a packet-capture precedent), record `swift test` output, tag the commit. No code.
- **Phase 1 — Settings window shell.** New empty Settings window with sidebar and 11 blank pages; gear icon added to popover header. Old UI fully intact and primary. Zero behavior change; pure addition.
- **Phase 2 — Content migration, one domain per packet.** Move existing card/sheet content into pages *without redesign*: General+Appearance → General; Input split → Dictation + Audio & Microphone; Output+Per-App → Output & Insertion; Vocabulary+Commands → their page; Accuracy&Speed+Benchmarks entry → Models & Accuracy; Profiles/History/Dexter bits → Dexter & Personality + History; Route Health+Reset+Safe Mode → Diagnostics & Recovery; experiments → Advanced. During this phase both paths work (cards still present); each packet moves one domain and hides only that card.
- **Phase 3 — Popover slim-down.** Rebuild popover per Section 10 wireframe: hero + primary button, result area, 3-row history, status line, footer/overflow. Remove Quick Settings entry, red Turn Off prominence, permanent Transcribe File button. Watermark placement contract applied here (empty zones only).
- **Phase 4 — Terminology consolidation.** One packet, all display strings: Quality Retry, Review Before Insert, Context Priming, Model Presets, etc. Storage keys untouched. Help window paths updated.
- **Phase 5 — Dexter integration.** Dexter & Personality page finished (profile cards, icon grid, theme picker, quote toggles); watermark empty-state polish; theme-seam fix; ticker height polish. The only phase allowed to touch Dexter presentation files.
- **Phase 6 — Live Preview prototype (L1).** Gated behind Andrew's separate approval; engine-adjacent, so it must not share a packet with any UI move. Display-only captions + kill switch + QoS fencing.
- **Phase 7 — Smart Cleanup page (Ollama).** Settings page, URLSession client, test buttons, History raw/cleaned pairing. Network code new and isolated; no engine files.
- **Phase 8 — Visual polish.** Spacing, typography, truncation fixes, alert-callout styling, HUD placement review. No structural change.
- **Phase 9 — Experimental adoption completion.** ⌘K palette in standard popover; Nano HUD becomes the default HUD style (or an option); inline Dex quote toggle. Each adopted from experimental code, re-homed in standard paths.
- **Phase 10 — Duplicate path retirement.** Adoption inventory → Andrew sign-off → remove state-first surface files + Switch UI + its settings duplication. Behavior preserved because everything it did now exists in the standard UI. Full feature-loss checklist before and after.

Ordering rationale vs. the suggested sequence in the brief: identical spirit; the one deliberate change is doing the **settings shell before any popover change** (the popover can only shed content once the content has somewhere to go) and putting **terminology after migration** (renaming while views move creates merge churn; renaming once everything has landed is one clean sweep).

---

## 18. Google Antigravity Implementation Packets

Global rules for every packet:
- **Forbidden in all packets** (unless a packet explicitly and solely targets them with approval): `AudioRecorderService.swift`, `AudioRecorderRecoverySupport.swift`, `AudioTapInstaller.m`, `AudioResampler.swift`, `InputMonitor.swift`, `ClipboardManager.swift`, `SecureInputContext.swift`, `OutputCoordinator.swift`, `TranscriptionEngine.swift`, `WhisperService.swift`, `SettingsMigration.swift` (keys), `OnboardingView.swift`, `LaunchIntroController.swift`, `WatermarkAssetProvider.swift`, `FlavorTickerView.swift`, `ProfileManager.swift`, all bundled MP4/PNG assets.
- **Every packet ends with:** `swift build`, `swift test` (zero new failures), the relevant Feature-Loss Checklist rows, the Dexter checklist rows (ticker scrolls / watermark rotates / launch animation plays), and before/after screenshots of touched surfaces.
- **Rollback condition for every packet:** any checklist row fails, any test regresses, or any feature loses UI exposure → `git revert` the packet's commits; packets are single-commit or small-stack commits for this reason.

---

**Packet 01 — Baseline Freeze**
- **Goal:** Reproducible pre-refactor record.
- **Files touched:** none (adds `docs/refactor_baseline/` screenshots + test log).
- **Forbidden:** all source.
- **Tasks:** capture screenshots of: idle popover, post-dictation popover, every Quick Settings card expanded, each detached window (History, Vocabulary, Commands, Per-App Rules, Benchmark Capture), HUD, onboarding pages, experimental popover + its settings; run `swift test` and save the log; tag `pre-uiux-refactor`.
- **Acceptance:** screenshot set covers all surfaces in Section 15's map; test log shows 0 failures.
- **Validation:** visual inventory reviewed by Andrew.
- **Rollback:** n/a (no code).

**Packet 02 — Settings Window Shell**
- **Goal:** Empty 11-page Settings window reachable from the popover header gear; nothing moves yet.
- **Files touched:** new `Sources/DexDictate/Settings/SettingsWindow.swift`, `SettingsSidebar.swift`, 11 stub page files; `MenuBarIconController.swift` or popover header view (gear button only).
- **Forbidden:** global list; `QuickSettingsView.swift` (untouched this packet).
- **Tasks:** window with sidebar (11 items per Section 11), each page a titled placeholder; ⌘, shortcut; gear icon in popover header.
- **Acceptance:** window opens/closes cleanly; all sidebar items navigate; old UI unchanged; no focus-stealing (dictation works with window open).
- **Validation:** `swift test`; manual dictation with settings window open; screenshots of shell.
- **Rollback:** remove new files + gear button.

**Packet 03 — Migrate General + Appearance-system items**
- **Goal:** General page functional.
- **Files touched:** `GeneralSettingsPage.swift`; extraction (not rewrite) of Launch at Login, sounds, menu-bar style, status color controls from `QuickSettingsView.swift`; hide the Appearance & System card's migrated rows.
- **Forbidden:** global list; theme engine internals.
- **Tasks:** move controls; icon-style dropdown becomes visual grid (same options, same storage keys); add Replay Onboarding button (calls existing onboarding entry); add Restore Defaults (relocated from popover footer).
- **Acceptance:** every migrated control functions identically (same `@AppStorage` keys); Launch at Login registers; icon changes apply live; Appearance & System card no longer shows migrated rows.
- **Validation:** `LaunchAtLoginControllerTests`; manual icon/sound toggles; checklist Launch-at-Login row.
- **Rollback:** revert; card rows reappear.

**Packet 04 — Migrate Dictation + Audio & Microphone**
- **Goal:** Trigger and audio device settings on their pages; Input card retired.
- **Files touched:** `DictationSettingsPage.swift`, `AudioSettingsPage.swift`; move ShortcutRecorder host view, trigger segmented control, silence-timeout slider, tail preset picker, device picker, silence-trim toggle out of `QuickSettingsView.swift`; Route Health rows move to a temporary holding spot (hidden) pending Packet 08.
- **Forbidden:** global list — especially `InputMonitor.swift`, `AudioRecorderService.swift`; ShortcutRecorder internals.
- **Tasks:** relocate views intact; verify no `onAppear`/observer logic is lost from the card (if found, extract to a controller first and flag to Andrew).
- **Acceptance:** hold + toggle both work; shortcut re-recording works; device switch works; silence timeout honored.
- **Validation:** `swift test`; manual trigger matrix (hold, toggle, mouse, keyboard); mic-switch test; checklist rows for triggers and mic.
- **Rollback:** revert.

**Packet 05 — Migrate Output & Insertion + Per-App Rules**
- **Goal:** All output toggles and per-app rules on one page; detached rules sheet content embedded.
- **Files touched:** `OutputSettingsPage.swift`; move toggles (Auto-Paste→Insert at Cursor label later, AX API, sensitive fields, profanity, Review Before Insert) from `QuickSettingsView.swift`; embed `PerAppInsertionSheet.swift` content as a page section (sheet file may remain for compatibility this packet).
- **Forbidden:** `OutputCoordinator.swift`, `SecureInputContext.swift`, `ClipboardManager.swift`, `AppInsertionOverridesManager` logic.
- **Tasks:** move views; restyle the Replace-Entire-Field warning into an alert-style callout (text unchanged in substance).
- **Acceptance:** per-app rule add/remove works; Slack-style copy-only rule honored; secure-field fallback unaffected; all toggles persist on same keys.
- **Validation:** `AppInsertionOverridesManagerTests`, `SecureInputContextTests`, `OutputCoordinatorTests`; manual per-app rule + password-field tests.
- **Rollback:** revert.

**Packet 06 — Vocabulary & Commands Center**
- **Goal:** Dedicated page; buried buttons removed from Input card remnant; learned corrections visible with badges.
- **Files touched:** `VocabularyCommandsPage.swift`; embed `VocabularySettingsView.swift` content + commands editor content; History window's Learn Correction flow gains the "Saved to Vocabulary" toast (string + link only).
- **Forbidden:** `VocabularyManager.swift`, `CommandProcessor.swift` logic.
- **Tasks:** two-section page; Learned badge (reads existing provenance if stored; if not stored, badge is deferred and noted — do not add storage fields in this packet); import/export preserved.
- **Acceptance:** add/edit/delete vocabulary entry round-trips through dictation; command executes; learn-correction from History appears in the page list.
- **Validation:** `VocabularyLayeringTests`, `CommandProcessorTests`; manual foo→bar dictation test; checklist rows.
- **Rollback:** revert; old sheets restored.

**Packet 07 — Models & Accuracy + Benchmark relocation**
- **Goal:** Model management page; benchmark machinery out of popover.
- **Files touched:** `ModelsAccuracyPage.swift`; move model picker/import, presets, Quality Retry toggle (still old name this packet), Context Priming toggle; remove Benchmarks & Corpus card from popover; add "Open Benchmark Lab…" button; benchmark automation cadence controls → parked for Packet 09 (Advanced).
- **Forbidden:** `ModelBenchmarking.swift` logic, `WhisperModelCatalog.swift` logic, promotion policy.
- **Tasks:** relocate; full-width buttons (fixes "Import Mo…" truncation); benchmark status/queue display lives only in the Benchmark Capture window now.
- **Acceptance:** model import works; preset switch works; retry toggle works; Benchmark Lab opens from page; popover contains zero benchmark UI.
- **Validation:** `BenchmarkPromotionPolicyTests`, `AdaptiveBenchmarkControllerTests`; manual benchmark capture open + run; checklist benchmarking row.
- **Rollback:** revert.

**Packet 08 — Diagnostics & Recovery + Advanced pages**
- **Goal:** Route Health, permissions, Safe Mode, Reset Core Audio, experiment flags re-homed. QuickSettingsView card stack now fully empty → remove the Quick Settings entry.
- **Files touched:** `DiagnosticsPage.swift`, `AdvancedPage.swift`; move Route Health rows, Reset Core Audio button block (`QuickSettingsView.swift:753-792` region), Safe Mode toggle, permission rows, experiment flags, experimental-UI switch; delete the now-empty `QuickSettingsView` entry point from the popover.
- **Forbidden:** `CoreAudioResetService.swift` logic, recovery planner, permission manager.
- **Tasks:** fenced "System Repair" group styling for Reset Core Audio; permission rows with Fix buttons (existing deep-link/polling behavior reused).
- **Acceptance:** Reset Core Audio still prompts for admin and executes; Safe Mode snapshot/restore works; route health values update live; popover no longer contains Quick Settings.
- **Validation:** `AudioRecorderRecoveryFailureTests`; manual Reset Core Audio; Safe Mode on/off matrix; checklist rows.
- **Rollback:** revert (Quick Settings entry returns).

**Packet 09 — Popover Slim-Down**
- **Goal:** Rebuild popover per Section 10 wireframe.
- **Files touched:** popover root view(s) in `Sources/DexDictate/` (e.g. the main popover SwiftUI files), new `PopoverHeroView.swift`, `PopoverResultView.swift`, `PopoverHistoryTeaser.swift`; overflow menu; watermark placement contract (empty-zones rendering).
- **Forbidden:** global list; `FlavorTickerView.swift` internals (repositioning its container is allowed; its logic/timing is not); history persistence.
- **Tasks:** state hero + Start button; result area with badge + contextual buttons; 3-row history teaser; status line; footer with Settings…/⋯/version; Turn Off → header power toggle with confirm; Quit/Transcribe File/Safe Mode → overflow; delete floating TRIGGER/Scheduled stack; watermark renders only in hero-idle and empty-history zones.
- **Acceptance:** matches wireframe structurally; dictation full loop works from button and trigger; Retry/Learn Correction appear contextually; no text renders over watermark; error banner shows on simulated permission loss.
- **Validation:** full manual loop; screenshot diff vs wireframe; checklist rows for HUD/ticker/history; `swift test`.
- **Rollback:** revert to prior popover (kept intact in git history; this packet must not delete old view files until Packet 12 confirms stability — hide, don't delete).

**Packet 10 — Terminology Sweep**
- **Goal:** One name per concept, everywhere.
- **Files touched:** display strings across UI files + Help content files. **Zero storage-key changes.**
- **Forbidden:** `AppSettings.swift` keys, `SettingsMigration.swift`, all logic.
- **Tasks:** apply Section 7 renames (Quality Retry, Review Before Insert, Context Priming, Model Preset Fast/Balanced/Accurate, Retry with Higher Quality button, history tags); update Help window "Found at:" paths to new locations; grep-verify retired terms appear nowhere user-facing.
- **Acceptance:** `grep` for retired strings in UI/Help files returns zero; history tags render new names; settings persist across the rename (same keys).
- **Validation:** `SettingsMigrationTests`; upgrade test from Packet-01 baseline build; manual read-through of every settings page + help.
- **Rollback:** string-only revert.

**Packet 11 — Dexter & Personality Page + Identity Polish**
- **Goal:** Dexter's settings home; watermark/ticker/theme polish. The only packet allowed to touch Dexter presentation files.
- **Files touched:** `DexterPersonalityPage.swift`; profile picker cards (reads `ProfileManager`), theme picker relocation, ticker toggle/speed, inline-quote toggle, watermark shuffle button; theme-seam fix (frame 048) in popover chrome; ticker container height fix.
- **Forbidden:** `WatermarkAssetProvider` selection logic, `FlavorQuotePacks` content, `LaunchIntroController` behavior, `ProfileManager` state logic, all media assets.
- **Tasks:** build page; wire existing settings; fix seam; verify Reduce Motion behavior unchanged.
- **Acceptance:** profile switch swaps quotes + icons live; themes apply without seam; ticker toggles; watermark shuffle rotates without immediate repeat; launch animation untouched and playing.
- **Validation:** `ProfileContentTests`; full Dexter checklist; screenshots of page + all four themes.
- **Rollback:** revert.

**Packet 12 — Experimental Adoption + Retirement (two-stage, second stage gated)**
- **Goal:** Stage A: adopt ⌘K palette, Nano-HUD style option, inline quote into standard UI. Stage B (separate approval): remove state-first surface.
- **Files touched:** Stage A: palette host in popover, HUD style option; Stage B: delete `ExperimentalUI/` surface files + Switch UI + experimental settings duplication.
- **Forbidden:** everything else; Stage B forbidden until Andrew signs the adoption inventory.
- **Tasks:** Stage A adoption; produce adoption inventory (every experimental capability → its standard home); Andrew sign-off; Stage B deletion.
- **Acceptance:** Stage A: palette opens with ⌘K, actions execute; Stage B: full feature-loss checklist passes on standard UI alone; no dangling references; app size/behavior stable.
- **Validation:** full checklist before and after Stage B; `swift build && swift test`; manual sweep of all surfaces.
- **Rollback:** Stage B is one revert away; Stage A independent.

**Packet 13 — Smart Cleanup (Ollama) Page**
- **Goal:** Section 14 page + client, isolated network module.
- **Files touched:** new `Sources/DexDictateKit/SmartCleanup/` (client, settings model, Keychain storage), `SmartCleanupPage.swift`, History raw/cleaned pairing (additive fields via proper migration), Diagnostics row.
- **Forbidden:** engine/output files; transcription providers; no changes to when text is inserted (initial form cleans post-delivery into History).
- **Tasks:** page per Section 14; URLSession client for `/v1/models` + `/v1/chat/completions`; warnings (non-loopback cleartext, unreachable tunnel port); Keychain for key; History shows Cleaned variant with "Use raw" swap.
- **Acceptance:** with a live tunnel: Test Connection lists models, Test Inference returns OK, a dictation gains a Cleaned variant; with dead endpoint: raw delivery unaffected, status row shows unreachable, no modal, no delay to insertion.
- **Validation:** unit tests for client + URL validation; manual against real tunnel (`curl` parity per Ollama baseline §2); checklist: raw transcript always present; `SettingsMigrationTests` for History fields.
- **Rollback:** feature-flag off + revert; History migration must be forward-compatible (additive only).

**Packet 14 — Live Preview Prototype (L1) — gated, engine-adjacent, runs alone**
- **Goal:** Display-only HUD captions per Section 13 L1. Requires separate explicit approval from Andrew before starting.
- **Files touched:** new `LivePreviewController.swift` (subscribes to an existing streaming provider), HUD caption view, Settings → Dictation toggle, kill-switch + Diagnostics logging.
- **Forbidden:** `TranscriptionEngine.swift` commit path, `WhisperService.swift`, output pipeline, capture service (may only *observe* existing published audio/text streams; if no observable stream exists, this packet stops and reports — it does not add taps).
- **Tasks:** throttled caption rendering (≤4 updates/s); PREVIEW styling; suspend-on-stop; QoS fencing; session kill switch on provider crash.
- **Acceptance:** captions appear while speaking; final transcript byte-identical to preview-off run on same audio (new invariant test); preview crash does not affect dictation; toggle off = zero provider activity.
- **Validation:** new equality test; CPU contention measurement via Benchmark Lab before/after; full regression suite; extended manual dictation session.
- **Rollback:** toggle default-off + revert; the invariant test remains as a permanent guard.

**Packet 15 — Visual Polish Pass**
- **Goal:** Typography, spacing, truncation, alert callouts, HUD placement — Section 3's cosmetic findings.
- **Files touched:** view files only; a shared style constants file if helpful.
- **Forbidden:** everything on the global list; all logic; Dexter behavior.
- **Tasks:** kill all truncated labels (audit at 340pt popover width and min settings-window width); consistent section header style; alert-callout component for destructive warnings; HUD position review with Andrew.
- **Acceptance:** zero truncated controls at default sizes; screenshots approved by Andrew.
- **Validation:** screenshot set vs Packet 01 baseline; `swift test`.
- **Rollback:** revert.

Suggested execution order: 01→02→03→04→05→06→07→08→09→10→11→12A→15, with 13 (Ollama) and 12B (retirement) and 14 (Live Preview) as separately-approved insertions after 10. Packets 03–08 are independent enough to reorder if a conflict arises, but one at a time.

---

## 19. Validation Checklist (run after every packet)

**Automated**
1. `swift build` — clean.
2. `swift test` — zero new failures vs Packet 01 baseline log (382 passing at baseline; `MainActorActionTests.testRunAsyncExecutesOnMainActor` known-flaky under load — a solo failure there is rerun once before judging).
3. Targeted filters when the packet touches a domain: `swift test --filter AudioRecorderRecovery`, `--filter ClipboardManager`, `--filter SecureInputContext`, `--filter OutputPipelineHardening`, `--filter Vocabulary`, `--filter CommandProcessor`, `--filter AppInsertionOverrides`, `--filter BenchmarkPromotion`, `--filter SettingsMigration`, `--filter Onboarding`.
4. Where applicable: `./scripts/run_quality_paths.sh`; release packets: `./scripts/validate_release.sh .build/DexDictate.app`.

**Manual UI**
5. Full dictation loop: trigger (hold), speak, release → text lands in Notes; repeat with toggle mode.
6. Popover walkthrough: every visible control does what its label says; no dead buttons.
7. Settings walkthrough: every page opens; every migrated control round-trips (change → close → reopen → persisted).
8. Screenshots: before/after of every touched surface, filed under `docs/refactor_baseline/packet_NN/`.

**Feature-loss checklist** (from `DexDictate_Feature_Loss_Checklist.md`)
9. Run the rows relevant to the packet + these every time: Local Whisper Dictation; Accessibility API Direct Insertion; Clipboard Restoration; Focus Mismatch Guard (start recording, switch apps, stop → clipboard not paste); Secure-Field fallback (password field → copy only).

**Core Audio recovery**
10. Unplug/replug or switch default input mid-idle and mid-recording → app recovers, Route Health (Diagnostics page) increments; Reset Core Audio prompts for admin (Packet 08+).

**Dexter identity (every packet, non-negotiable)**
11. Launch animation plays, holds brand card, shrinks away.
12. Ticker scrolls smoothly at popover top, no clipping.
13. Watermarks rotate (shuffle or restart) without immediate repeats — and (Packet 09+) never render under body text or controls.
14. Regional profile switch swaps quotes and icons.
15. Onboarding replays cleanly (five-tap or, post-Packet 03, the Replay button).

**Live transcription fallback (Packet 14+)**
16. Preview on vs preview off: identical committed transcript on same audio (automated invariant + one manual spot check).
17. Kill the preview provider mid-utterance (or simulate) → dictation completes normally.

**Ollama (Packet 13+)**
18. `curl -s http://127.0.0.1:<port>/v1/models` parity with the in-app Test Connection result.
19. Dead endpoint: dictation insertion latency unchanged; raw transcript delivered; status row shows unreachable.
20. Non-loopback cleartext URL entered → warning shown, not blocked.

---

## 20. Final Recommendation

**What should happen next**
1. Andrew reviews and approves, in this order: the product architecture (Section 5), the navigation model (Section 6), the settings taxonomy (Section 11), and the mode names (Section 7). These four decisions determine every packet's file targets; nothing else should move first.
2. On approval, run **Packet 01 (Baseline Freeze)** — it is zero-risk, immediately useful, and produces the screenshot/test artifacts every later packet validates against.
3. Then Packet 02 (Settings Window Shell), and proceed sequentially through the migration packets (03–08), one at a time, with the checklist after each.

**What should not happen next**
- No live transcription work (Packet 14 stays gated until the UI phases are done and Andrew separately approves it). Parakeet does not get re-enabled anywhere in the meantime.
- No Ollama implementation before the settings shell exists (the page needs a home first) — and no hard-coded `westcat`/`BigMac`/`11435` defaults ever.
- No deletion of the experimental UI until the adoption inventory is signed (Packet 12 Stage B gate).
- No touch of the fragile list: audio engine, event tap, clipboard timing, onboarding/launch-animation internals, Dexter assets.
- No combined packets. The failure mode this plan exists to prevent is "one big refactor branch."

**The first Antigravity packet to run:** **Packet 01 — Baseline Freeze**, immediately followed by **Packet 02 — Settings Window Shell** as the first code packet.

**What Andrew should review before implementation starts:** Sections 5, 6, 7, 10 (the popover wireframe — this is the surface he'll live in daily and the one place taste matters most), and 11. If he changes any page grouping or mode name at review time, the change costs nothing; after Packet 03 it costs a packet.

DexDictate does not need to become less. It needs a front desk worthy of the machine behind it — and Dexter, prominently, at that desk.
