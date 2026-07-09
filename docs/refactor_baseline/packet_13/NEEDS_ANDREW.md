# Packet 13 — Manual Validation Gaps

## No live Ollama tunnel available

The full success-path validation (Test Connection listing real installed models, Test
Inference getting a real "OK" reply with round-trip time, an enabled dictation producing a
real Cleaned history variant) requires an actual reachable OpenAI-compatible endpoint —
either a local Ollama instance or an SSH/Tailscale tunnel to one. Neither is available in
this environment. This is an environmental gap, not a code gap: the client code, request
building, and error handling are unit tested and verified against a genuinely dead port
(`curl` connection-refused), but the true success path has never round-tripped against a
live server. Recommend testing this yourself against your `westcat`/BigMac tunnel before
relying on it.

## Same LSUIElement/accessibility blocker as every prior packet

No screenshots, no manual click-through of the Smart Cleanup Settings page (toggle,
fields, Test Connection/Test Inference buttons, tunnel-help disclosure, warning callout)
or the History window's new Cleaned/Raw swap — same automation gap documented in every
packet this entire session.

## Design choices worth a second look

- `SmartCleanupCoordinator.reachability` updates only when a real check happens (Test
  Connection, a real cleanup attempt, or the coordinator's own `refreshReachability()`) —
  there's no background polling loop. If you'd rather the Diagnostics row auto-refresh
  periodically, that's a follow-up, not something this packet added.
- The "Use raw"/"Use cleaned" swap lives only in the detached History window
  (`HistoryWindow.swift`), not the popover's inline history teaser or the classic
  popover's `HistoryView.swift` — the plan of record specifically named "History window."
  If you want the cleaned variant surfaced in those inline views too, that's additional
  scope beyond what was asked here.

No new orphaned controls, no new forbidden-file strings, no storage-key changes to
`AppSettings.swift` (Smart Cleanup's 3 new keys live in its own isolated settings file).
