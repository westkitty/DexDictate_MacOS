# Packet 04 — Screenshot / Manual Validation Gaps

Same LSUIElement/accessibility blocker as Packets 01–03 — cannot click through the popover
or Settings window in this environment.

Not captured this packet:
- Screenshot: Dictation page
- Screenshot: Audio & Microphone page
- Screenshot: remaining Input card (post-hide)

Manual validations not performed (require live UI interaction and/or real audio):
- Hold-to-talk / toggle trigger matrix (hold ×2, toggle ×2)
- Shortcut re-recording (mouse and keyboard) from the new Dictation page
- Mic switch from the new Audio page + unplug-preferred-mic fallback test
- Silence timeout honored in toggle mode; tail preset persistence

What WAS verified for real:
- `swift build` — clean
- `swift test` — 382 passed, 0 failures (matches Packet 01 baseline)
- `swift test --filter AudioRecorderRecovery` — 5/5 passed, untouched-green as required
- `./build.sh` succeeded; app launched and confirmed running via `ps aux`
- Full `git diff` reviewed: `QuickSettingsView.swift` (rows hidden behind two new flags,
  `showLegacyInputRows` and `showLegacyTailTimingRows`; `SettingToggleWithInfo` widened to
  internal), `SettingsWindow/DictationSettingsPage.swift` and `AudioSettingsPage.swift`
  (built out), `SettingsWindowController.swift`/`SettingsRootView.swift`/`DexDictateApp.swift`
  (threaded the app's existing `AudioDeviceScanner` instance through to the new Audio page —
  see lifecycle inventory below). `ShortcutRecorder.swift` itself: zero lines touched. No
  forbidden files touched. No `@AppStorage` key added/removed/renamed (grepped the diff).

## Mandatory lifecycle inventory (Input + Accuracy & Speed cards)

Required by this packet before moving anything:
- No `onAppear`/`task`/`onDisappear`/`Timer`/observer is scoped to the Input card or the
  Accuracy & Speed card themselves. The only lifecycle hook touching either card is
  `QuickSettingsView`'s single top-level `.onAppear` (shared by every card), and none of its
  calls (`menuBarIconController.refreshAssets()`, `modelCatalog.refresh()`,
  `benchmarkResultsStore.reload()`, profanity text sync, `launchAtLoginController` refresh)
  relate to the controls this packet migrates (Input Device picker, Silence Timeout,
  ShortcutRecorder, End Preset, Adaptive Tail Delay).
- `AudioDeviceScanner` (backs `scanner.availableDevices`) manages its own lifecycle inside
  its own `init()`/`deinit` (starts a CoreAudio device-change listener at construction, tears
  it down at deinit) — a service-owned lifecycle, not a view one. Instantiating a *second*
  `AudioDeviceScanner()` for the Settings window would have stood up a redundant CoreAudio
  listener without breaking anything, but to avoid that duplication I threaded the app's
  single existing instance through `SettingsWindowController.show(scanner:)` →
  `SettingsRootView` → `AudioSettingsPage` instead of creating a new one.
- `ShortcutRecorder`'s `.onDisappear { stopRecording() }` cleans up its own local `NSEvent`
  monitor and is tied to the view's own lifecycle, not the card's — it works identically
  wherever it's hosted, so no extraction was needed. File left completely untouched.
- Conclusion: no behavior was found hidden in the card's own view lifecycle that would have
  required a stop. The one structural change made (threading the shared scanner) was to
  avoid a wasteful duplicate, not to work around a hidden dependency.
