# Packet 08B — Fresh Quick Settings Inventory

Taken after migrating the seven items from Andrew's mapping. Every card in the popover's
Quick Settings stack, listing what's still visible (not gated behind a `false` flag) vs.
what's now hidden because it has a Settings-window home.

## Input card
- Hidden: Input Device, Silence Timeout, ShortcutRecorder (Packet 04); Custom
  Vocabulary/Voice Commands buttons (Packet 06); Route Health (Packet 08); **Pause browser
  media during dictation (Packet 08B → Settings → Dictation)**
- Visible: none — card is now empty

## Output card
- Hidden: Auto-Paste, Copy Only in Sensitive Fields, Use Accessibility API, Filter
  Profanity, Per-App Rules button (Packet 05); Safe Mode (Packet 08); **Show Floating HUD
  (Packet 08B → Settings → General)**
- Visible: none — card is now empty

## Accuracy & Speed card
- Hidden: End Preset, Adaptive Tail Delay, Trim Leading/Trailing Silence (Packet 04);
  Correction Sheet (Packet 05); Active Model, Model Selection, Accuracy Retry (+auto-retry),
  Use Context From Focused Field (Packet 07); Trailing Trim Experiment (Packet 08);
  **Context Biasing / Bias Mode (Packet 08B → Settings → Models & Accuracy)**
- Visible: none — card is now empty

## Benchmarks & Corpus group (was inside Accuracy & Speed)
- Hidden entirely (Packet 07); Import Model / Open Benchmark Capture re-created as new call
  sites in Models & Accuracy

## Transcription Engines card
- Hidden entirely (**Packet 08B → Settings → Models & Accuracy**, re-hosting
  `LiveTranscriptionStatusView` intact)

## Profiles & History card
- Hidden: **Show Dictation Stats, Persist History Across Sessions (Packet 08B → Settings →
  History)**
- Visible: Profile picker, Return to Standard button, Show Flavor Ticker toggle, Animate
  Flavor Ticker toggle — **explicitly assigned to Packet 11 (Dexter & Personality)**, which
  has not run yet in this session. Not new orphans; same status Packet 08's report gave them.

## Appearance & System card
- Hidden: Status Color, sounds, Launch at Login, Menu Bar Style (Packet 03)
- Visible: Theme/Appearance picker — **explicitly assigned to Packet 11**, not yet run.

## Experimental UI card
- Hidden entirely (Packet 08 → Settings → Advanced)

## Advanced card
- Hidden entirely (Packet 08 → Settings → Diagnostics & Recovery / Advanced) — card is now
  empty

## Pinned Controls Strip (outside the cards, always visible when Quick Settings is expanded)
- Trigger Mode segmented control, compact Input Device picker, compact Model picker, compact
  Auto-Paste toggle, compact Safe Mode toggle — all **duplicates of bindings that already
  have a Settings-window home** (Packets 04/07/05/08). Not orphans; left as-is, out of this
  packet's scope (pinned-strip cleanup belongs to Packet 09's popover contract work).

## Result: NOT every former Quick Settings item is accounted for by an *existing* home

Five controls (Profile picker, Return to Standard, Show Flavor Ticker, Animate Flavor
Ticker, Theme picker) are named in Packet 11's goal text but Packet 11 has not executed
yet. They are reachable **only** through the still-visible Quick Settings entry right now.

**Decision: the Quick Settings entry point was NOT hidden in this packet.** Hiding it now
would strand those five controls — including profile switching and theme selection — for
the entire window between now and whenever Packet 11 completes later in this run. That is a
real, if temporary, reachability regression for the actual running app, not a cosmetic gap.

This is a narrower, better-understood situation than the finding at the top of Packet 08:
these five items *do* have a named, approved, already-scheduled destination (Packet 11) —
they are just not there *yet*. I'm treating "hide the entry point" as a Packet 11-completion
condition rather than an 08B one, and will re-run this inventory once Packet 11 lands to
confirm it's then safe to hide.
