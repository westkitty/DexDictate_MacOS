# Packet 08 — MANDATORY PRE-REMOVAL INVENTORY FINDING (stop condition triggered)

This packet's own instructions require, before hiding the "Quick Settings" entry from the
popover: **"list every control still visible anywhere in the Quick Settings stack; each must
have a Settings-window home (from Packets 03–07 or this packet) before the entry is hidden.
Anything unaccounted for → stop."**

I did that inventory. Several controls are NOT accounted for by any packet in the approved
02–12A/15 sequence. Per the packet's explicit stop condition, **I did not hide the Quick
Settings entry point.** Everything else in this packet (Diagnostics & Recovery page, Advanced
page, hiding the specific rows this packet's goal text assigns) is complete, tested, and
pushed. Only the final "retire Quick Settings from the popover" step is withheld.

## Full inventory of the Quick Settings stack (after this packet's own migrations)

**Accounted for** (migrated in a prior packet or this one, hidden behind a flag; original
control now lives in its Settings page):
- Input card: Input Device, Silence Timeout, ShortcutRecorder (Packet 04); Custom
  Vocabulary/Voice Commands buttons (Packet 06); Route Health (this packet)
- Output card: Auto-Paste, Copy Only in Sensitive Fields, Use Accessibility API, Filter
  Profanity, Per-App Rules button (Packet 05); Safe Mode (this packet)
- Accuracy & Speed card: End Preset, Adaptive Tail Delay, Trim Leading/Trailing Silence
  (Packet 04); Correction Sheet (Packet 05); Active Model, Model Selection, Accuracy Retry
  (+auto-retry), Use Context From Focused Field (Packet 07); Trailing Trim Experiment (this
  packet)
- Benchmarks & Corpus group (was inside Accuracy & Speed): entire group hidden (Packet 07);
  Import Model and Open Benchmark Capture re-created as new call sites in Models & Accuracy
- Appearance & System card: Status Color, sounds, Launch at Login, Menu Bar Style (Packet 03)
- Experimental UI card: all four flags (this packet)
- Advanced card: Reset Core Audio (this packet) — card is now empty and fully hidden

**NOT accounted for — no packet in the 02–12A/15 sequence claims these:**
1. **"Pause browser media during dictation"** toggle (Input card) — a real, working feature
   with its own permission-prompt behavior (Automation permission for Chrome/Brave/Edge).
   No page owns it.
2. **"Show Floating HUD"** toggle (Output card) — controls whether the floating HUD window
   appears at all. No page owns it. (Its *content* — Nano HUD — is an experimental flag now
   on the Advanced page, but the on/off switch for the HUD itself is not migrated.)
3. **"Context Biasing" / "Bias Mode" picker** (Accuracy & Speed card, `dictationDomainMode`)
   — a real, separate feature from Context Injection (per-app-focus vocabulary biasing vs.
   cursor-context reading). No page owns it. Explicitly flagged as unassigned in Packet 07's
   own report.
4. **Entire "Transcription Engines" card** (`LiveTranscriptionStatusView`) — Live
   Transcription toggle, Command Mode toggle, provider compatibility info, and (per code
   inspection) live/on-demand model downloads for the Parakeet, Nemotron, and Moonshine
   transcription providers. This is a substantial, real feature area. **No packet in the
   approved sequence mentions it at all.**
5. **"Show Dictation Stats"** toggle (Profiles & History card) — controls the in-popover
   stats ticker (word count, session duration, WPM). Not mentioned in Packet 11's goal text
   (which only names the flavor ticker, not the stats ticker).
6. **"Persist History Across Sessions"** toggle (Profiles & History card) — controls whether
   transcription history survives app relaunch. Not mentioned anywhere.
7. **The "History" Settings-window page itself** (`HistorySettingsPage.swift`) — the sidebar
   has an 11th destination for this, but no packet from 02 through 15 in the approved
   sequence has a goal that builds it out. It's still the Packet 02 placeholder.

Also noted, not blocking (both already flagged as intentionally deferred by name in earlier
packets, not orphans): the Profile picker / Return to Standard / flavor-ticker toggles in
"Profiles & History" and the theme picker in "Appearance & System" are explicitly Packet 11's
job and Packet 11 has not run yet — they're accounted for by a *future* packet, per the
inventory rule's own wording ("Packets 03–07 **or this packet**" — items 1–7 above are the
ones with no claim from *any* packet, past or future, in the plan).

## Why this matters for the rest of the run

Packet 09 (Popover Slim-Down) builds a new, slim popover and explicitly removes "all Quick
Settings remnants" from it. If the Quick Settings entry were hidden now, or if Packet 09 runs
next and drops the old popover's reachability, items 1–7 above become **permanently
unreachable in the running app** — a real feature-loss regression, not a cosmetic gap. This
is exactly the scenario Packet 08's stop condition exists to catch.

## Recommendation (Andrew's call, not mine to make)

The Quick Settings entry point remains visible and fully functional in the popover — nothing
is broken or regressed by this packet. Before Packet 09 (or any later packet) runs, items
1–7 need one of:
- assignment to an existing page (e.g., "Show Floating HUD" and "Show Dictation Stats" could
  plausibly join Packet 11's Dexter & Personality or a General/History page; "Pause browser
  media" and "Context Biasing" could join Models & Accuracy or a new page; "Transcription
  Engines" and "History" likely need their own dedicated packet given their size), or
- an explicit decision that they're acceptable to leave in the legacy popover permanently
  (in which case Packet 09/12B need updated instructions so they don't assume a fully empty
  Quick Settings stack).

**I'm pausing the autopilot run here rather than continuing to Packet 09**, since Packet 09
depends on Packet 08 having fully retired Quick Settings, which it explicitly has not (by
design, per the stop condition). See the final response to this turn for the full summary.
