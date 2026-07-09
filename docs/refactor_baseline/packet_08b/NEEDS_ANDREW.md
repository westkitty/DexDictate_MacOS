# Packet 08B — Screenshot / Manual Validation Gaps + Sequencing Note

Same LSUIElement/accessibility blocker as every prior packet — cannot click through the
popover or Settings window in this environment.

Not captured this packet:
- Screenshots of the four updated pages (Dictation, General, Models & Accuracy, History)
- Screenshot of Quick Settings with all seven originally-orphaned rows/cards absent

Manual validations not performed (require live UI interaction and/or real audio):
- Pause browser media toggle round-trip (with actual Chrome/Brave/Edge + Automation prompt)
- Show Floating HUD toggle from the new General page actually shows/hides the HUD window
- Context Biasing / Bias Mode picker round-trip
- Live Transcription / Command Mode toggles + a real provider download from the new page
- Open History Window button opens the same window the popover's detach button does
- Show Dictation Stats / Persist History Across Sessions round-trip

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- Targeted: searched for `History`/`LiveTranscription`/`TranscriptionProvider`/`CommandMode`
  test classes — only `TranscriptionHistoryTests`, `SettingsMigrationTests`,
  `AppSettingsRestoreDefaultsTests`, `PermissionSettingsLinkerTests` exist and are relevant;
  ran `swift test --filter "SettingsMigration|TranscriptionHistory|AppSettingsRestoreDefaults|PermissionSettingsLinker"`
  — 14/14 passed. No test class exists specifically for `LiveTranscriptionStatusView`,
  `TranscriptionProviderRegistry`, or Command Mode — stating this honestly rather than
  inventing a filter that matches nothing.
- `./build.sh` succeeded; app launched and confirmed running via `ps aux` (checked twice)
- Full `git diff` reviewed: all eight changed files are the expected ones (four Settings
  pages built out further, `QuickSettingsView.swift` rows/cards hidden, three
  wiring/threading files for `historyController`). No forbidden files. No `@AppStorage` key
  added/removed/renamed (grepped the diff).

## Sequencing note (not a new blocker, but affects what happens next)

Per the fresh inventory (`QUICK_SETTINGS_FINAL_INVENTORY.md`), the Quick Settings entry
point was **not** hidden — five controls (Profile picker, Return to Standard, both ticker
toggles, Theme picker) are still only reachable there, and they're assigned to Packet 11,
which hasn't run yet in this session. I'm continuing to Packet 09 as instructed. Packet 09's
own validation commands include a "profile switch" Dexter check — if that reveals the same
gap in a way that blocks Packet 09's acceptance criteria, I'll report it there rather than
silently paper over it.
