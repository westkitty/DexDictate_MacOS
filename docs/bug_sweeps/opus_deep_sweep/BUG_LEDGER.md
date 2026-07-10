# Opus Deep Sweep — Bug Ledger

Result of Pass 1 (deep audit) and Pass 2 (fixes): **no new confirmed bugs found.**

The app entered this sweep after three prior evidence-backed sweeps
(settings-clickability BUG-004, settings-navigation BUG-005, model-selection
BUG-006/BUG-007, and the post-campaign sweep BUG-001/002/003) that closed every
confirmed defect. This sweep independently re-audited all areas A–H (see
`COVERAGE_MAP.md`) against current source and found no reproducible or evidence-backed
defect that is safe and narrow enough to fix.

Per the packet's rules, suspected risks were NOT fixed — they are recorded in
`RISK_REGISTER.md` with exact confirmation steps. Nothing in this ledger is left as
"needs more investigation": each risk is either dismissed with reasoning or carried
forward with a precise, Andrew-verifiable reproduction.

No `### BUG-0xx` entries are recorded because none were confirmed. The format below is
retained for reference so a future confirmed bug can be appended in-place.

---

### BUG-000: (template — no confirmed bugs this sweep)
- Status: not reproducible
- Severity: —
- Area: —
- Evidence: —
- Root cause: —
- Proposed fix: —
- Validation method: —
- Fix result: No confirmed bug; nothing fixed.

---

## Carried-forward confirmed bugs from prior sweeps (all already fixed — verified still fixed)

| ID | Title | Prior status | Verified this sweep |
|---|---|---|---|
| BUG-001 | Quit confirmationDialog never appeared in slim popover | fixed (`860b17d7`) | ✅ `PopoverRootView.confirmAndQuit()` uses `NSAlert.runModal()` |
| BUG-002 | Live Preview "Finalizing…" badge stuck true | fixed | ✅ `LivePreviewController` default branch calls `endSession(clearImmediately: true)` |
| BUG-003 | `SmartCleanupCoordinator` Swift-6 actor-isolation warning | fixed | ✅ `init(settings: SmartCleanupSettings? = nil)` resolves default in body |
| BUG-004 | Standard Floating HUD intercepted clicks | fixed | ✅ `ignoresMouseEvents = !useExperimentalNanoHUD` |
| BUG-005 | Settings sidebar didn't drive detail pane | fixed | ✅ `selection` is local `@State` in `SettingsRootView` |
| BUG-006 | Model selection clarity + Stop button placement | fixed | ✅ Active Dictation Model picker + Stop pinned outside ScrollView |
| BUG-007 | Legacy multilingual models looked like duplicate downloads | fixed | ✅ `Base (Multilingual)`/`Small (Multilingual)` labels present |
