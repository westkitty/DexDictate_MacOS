# Model Selection Done Gate

## Verdict
- Status: CLOSED pending Andrew live click-through
- Reason: BUG-007's root cause was fully identified against real filesystem/log evidence (not
  hypothesized), the smallest correct fix was applied, all automated checks pass, and the full
  model-selection section (Settings top picker, Model Library, popover dropdown, Other Engines,
  persistence, BUG-006B stop-button regression) was re-audited against current source and found
  correct. Nothing remains for me to verify from this environment — only Andrew's own eyes on
  the actual on-screen wording and a real click-through remain.

## Code validation
- swift build: PASS (clean, exit 0)
- swift test: PASS (417 tests, 0 failures)
- targeted WhisperModelCatalogTests: PASS (8/8)
- targeted ModelSelectionActionsTests: PASS (7/7)
- ./build.sh: PASS (clean, exit 0, installed to /Applications/DexDictate.app)
- app relaunch: PASS (confirmed via `ps aux`, single process running)

## Model catalog validation
- Download path: `~/Library/Application Support/DexDictate/Models/<id>.bin` — confirmed via code
  read and real filesystem inspection.
- Scan path: same directory — confirmed identical to download path (no mismatch).
- Imported model recognition: unaffected by this fix; confirmed via existing + passing tests.
- Downloaded model recognition: correct for both the app's own naming (`<id>.bin`) and legacy
  whisper.cpp naming (`ggml-<stem>[.en].bin`); the latter's non-English display name now
  disambiguated with "(Multilingual)" for stems with a real `.en` catalog counterpart.
- Missing sidecar behavior: correctly recognized without a sidecar for the legacy scan path (by
  design, confirmed by existing + new tests) — sidecars are only required for the
  imported/downloaded-via-app origin.
- Refresh behavior: `downloadModel` calls `refresh()` on success; confirmed by code read, no
  evidence of staleness in real logs.
- Relaunch persistence: confirmed directly against real `debug.log`/`diagnostics.jsonl` entries
  showing the same models loading successfully across multiple relaunches and across debug vs.
  production builds.

## UI validation expectations
- Settings Active Dictation Model: labeled correctly, wired through
  `ModelSelectionActions.applyActiveModelSelection`, matches status caption — confirmed via
  source re-read, no drift since BUG-006.
- Settings Model Library: Installed/Download/Other-Engines sections present and correctly
  populated; downloadable rows never checkmarked; confirmed via source re-read.
- Popover dropdown: same three-section grouping, same shared `ModelSelectionActions` calls as
  Settings — confirmed via source re-read.
- Other Engines / Engine Roles: labeled with real role + On/Off state, never presented as
  active-model rows — confirmed via source re-read.
- Download rows: explicit "— Download" action text, never a selection checkmark — confirmed via
  source re-read and test coverage.
- Stop button placement: Start in hero (idle only), Stop in `PopoverRootView` below chips/result
  and above footer — confirmed unchanged since BUG-006B via source re-read.

## Remaining manual validation for Andrew
- [ ] Settings selector changes label and persists
- [ ] Popover selector matches Settings
- [ ] Downloaded model stays installed after relaunch
- [ ] Other Engines are role-labeled, not fake dictation models
- [ ] Stop button placement is correct while recording
- [ ] Confirm the new "(Multilingual)" labels on your existing Base/Small installs read clearly
      and don't feel like a demotion — this is a wording choice, easy to iterate on if you'd
      prefer different phrasing (e.g. "Base (non-English)")

## Remaining risks
- None identified in code, catalog, or UI logic. The only open item is a subjective wording
  check (whether "(Multilingual)" is the clearest possible phrasing for a non-technical user) —
  not a defect, a taste call Andrew can weigh in on.
