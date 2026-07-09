# Packet 12A-B — Manual Validation Gaps

Same LSUIElement/accessibility blocker as every prior packet — no screenshots, no manual
click-through validation possible for:
- Compact controls row: trigger pill rebind popover, model pill menu (Whisper + other
  engines sections), mode pill tap-to-toggle, output chips' conditional rendering (safe
  mode / clipboard-fallback chips only appear under those specific states).
- Live transcript + mic meter: only renders while `engine.state == .listening`, which
  requires an actual microphone input session to trigger — can't be reached without live
  speech.
- Dexter Feed: "Shuffle lines" button and its random-sampling render.

All three were verified by reading the exact reused view/property definitions (see
`ADOPTION_PLAN.md`) and confirming `swift build`/`swift test` pass, not by driving the UI.

No new NEEDS_ANDREW findings beyond the manual-validation gap — no new orphaned controls,
no new forbidden-file strings, no storage-key changes.
