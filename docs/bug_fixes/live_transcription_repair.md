# Live Transcription / Live Preview Repair

## User-visible symptom

Enabling "Live Transcription" (and/or "Live Preview") produced no visible text while the
user was speaking. Final (batch Whisper) transcription still worked correctly — only the
live, word-by-word captions never appeared.

## Confirmed root cause

Not a single broken wire. Two compounding, verified issues:

1. **Two independently-gated settings, one description promising the behavior of both.**
   `AppSettings.liveTranscriptionEnabled` (Settings → Models & Accuracy, default **on**)
   controls which transcription *provider* gets selected for streaming. A **separate**
   setting, `AppSettings.livePreviewEnabled` (Settings → Dictation, previously default
   **off**, labeled "(experimental)"), is what actually let `LivePreviewController`
   subscribe to anything at all. The "Live Transcription" toggle's own description already
   said *"When on, DexDictate shows live partial captions while you speak"* — but that
   alone did nothing without also finding and enabling the second, differently-worded,
   differently-located toggle.

2. **Neither streaming-capable provider is available out of the box**, which is the
   *dominant* real-world cause. `TranscriptionProviderRegistry.resolveActiveProvider`
   correctly prefers Nemotron, then Apple Speech, then falls back to Whisper
   (`usesLiveStreaming: false`) — and in the common case, both are unavailable:
   - **Nemotron** requires an explicit, separate on-demand model download; nothing
     prompts the user to do this.
   - **Apple Speech** requires the macOS Speech Recognition permission, which was
     requested exactly once, silently, at app launch
     (`AppleSpeechTranscriptionProvider.requestAuthorizationIfNeeded()`), with a no-op
     completion handler and no retry. A passive system dialog with no explanatory
     context is easy to miss or dismiss; once missed, nothing ever asked again.

   Confirmed empirically: the new regression tests call the real, un-mocked
   `resolveActiveProvider(liveTranscriptionEnabled: true)` in this sandbox and it
   deterministically reports both providers unavailable (`Speech Recognition permission
   hasn't been granted yet.` / `Nemotron models are downloaded but not loaded yet.`) —
   the exact real-world condition this bug report describes.

   When neither provider is available, `TranscriptionEngine.liveTranscript` never
   receives partial updates during `.listening`, so **every** live-text surface has
   nothing to show — this is correct/honest given the constraint, but the app gave the
   user almost no signal about *why*, and the one place that did explain it
   (`LiveTranscriptionStatusView` in Settings → Models & Accuracy) was invisible from the
   actual dictation UI (the popover/HUD, where the user is watching for live text).

## Full data path traced

1. Microphone buffer → `AudioRecorderService` tap → `audioService.onRawAudioBuffer` (wired
   in `TranscriptionEngine.startLiveProviderSessionIfNeeded()`).
2. Buffer → `provider.appendAudioBuffer(_:)` (Nemotron/Apple Speech only — final-only
   engines never receive this).
3. Provider's own recognition callback → `provider.onPartialResult` → guarded on
   `state == .listening` → `TranscriptionEngine.liveTranscript` (`@Published`).
4. **Three separate UI consumers** of `liveTranscript`, discovered during tracing:
   - `DexTranscriptCard` in `PopoverRootView` (the current default slim popover) —
     reads `engine.liveTranscript` **directly, ungated** by `livePreviewEnabled`.
   - `LivePreviewCaptionView` in `PopoverHeroView`/`FloatingHUD` — via
     `LivePreviewController`, subscribed to `engine.$liveTranscript` (throttled 250ms),
     **gated** behind `livePreviewEnabled`.
   - `DexNanoHUDView` — shows `liveTranscript` only during `.transcribing` (a
     "Processing…" placeholder after speech ends, not live-while-speaking text; a red
     herring for this bug, left untouched).
5. `TranscriptionProviderRegistry.resolveActiveProvider` runs fresh on every
   `startListening()` call and publishes `lastResolution` (`@Published`), which already
   carried an honest `fallbackExplanation` — just never surfaced outside one Settings page.

## Provider capability findings

The capability model already existed per-provider (`supportsStreaming`,
`supportsPartialResults` on the `TranscriptionProvider` protocol) — no new capability
struct was needed.

| Provider | Partial results | Notes |
|---|---|---|
| Nemotron 3.5 ASR Streaming | **Yes** | Requires explicit on-demand model download |
| Apple Speech | **Yes** | Requires Speech Recognition OS permission |
| WhisperKit (compatibility) | No | Batch-only, always available |
| Parakeet | No | Batch-only |
| Moonshine | No (declares `supportsPartialResults = false`; `onPartialResult` never invoked) | Command-mode only |

## Files changed

- `Sources/DexDictateKit/LivePreview/LivePreviewController.swift` — added
  `unavailableReason`, a reactive subscription to
  `registry.$lastResolution` (handles the ordering hazard: `state` flips to `.listening`
  *before* `resolveActiveProvider()` runs), and honest messaging distinguishing "no words
  yet" from "this session will never show words."
- `Sources/DexDictate/LivePreview/LivePreviewCaptionView.swift` — renders the new
  unavailable state.
- `Sources/DexDictateKit/ExperimentalUI/DexExperimentalUIState.swift` — added
  `unavailableReason` to `TranscriptDisplayState` (defaulted, non-breaking).
- `Sources/DexDictate/DexStateFirstComponents.swift` — `DexTranscriptCard` renders the
  new reason.
- `Sources/DexDictate/PopoverRootView.swift` — computes the reason from
  `engine.transcriptionProviderRegistry.lastResolution`.
- `Sources/DexDictateKit/TranscriptionEngine.swift` — re-requests Apple Speech
  authorization at the start of every `startListening()` (not just once at app launch)
  when Live Transcription is enabled; a no-op once the user has answered either way, but
  means a missed launch-time prompt no longer permanently blocks the feature without an
  app restart.
- `Sources/DexDictateKit/Settings/AppSettings.swift` — `livePreviewEnabled` default
  flipped `false` → `true` (and `restoreDefaults()` updated to match), graduating a
  well-tested, well-guarded feature out of an overly cautious rollout default that had
  drifted out of sync with `liveTranscriptionEnabled`.
- `Sources/DexDictate/SettingsWindow/DictationSettingsPage.swift`,
  `Sources/DexDictate/QuickSettingsView.swift` — corrected copy: drops "(experimental)",
  cross-references the two settings, explains the two real unavailability causes.

## State-machine changes

`LivePreviewController` gained one new field (`unavailableReason`) and one new reactive
subscription (`registry.$lastResolution`, subscribed once for the controller's lifetime,
not per-session). It resets to `nil` on `beginSession()` and `endSession(clearImmediately:
true)`, exactly like every other per-session field (`caption`, `micLevel`, `isFinalizing`)
— it cannot bleed across sessions, cancellations, or provider switches.

No changes to the underlying `EngineState` machine, `TranscriptionEngine`'s commit path,
Whisper, output insertion, or Smart Cleanup.

## Tests added

`Tests/DexDictateTests/LivePreviewInvariantTests.swift` (existing file, extended):

1. `testUnavailableReasonExplainsSilentCaptionWhenNoStreamingProviderResolved` — resolution
   computed before listening begins.
2. `testUnavailableReasonUpdatesReactivelyWhenResolutionArrivesAfterListeningBegins` —
   pins the real production ordering (`state → .listening` fires before
   `resolveActiveProvider()`), proving the reactive subscription (not a one-time read)
   is what makes this correct.
3. `testUnavailableReasonStaysNilWhenLiveTranscriptionIsDeliberatelyOff` — a user's
   deliberate choice must never be mislabeled as an engine limitation.
4. `testUnavailableReasonClearsWhenSessionEnds` — no bleed into the next dictation.

All four call the real, un-mocked `TranscriptionProviderRegistry.resolveActiveProvider`
against the real per-provider `healthCheck()` implementations (no mocks) — in this sandbox
they deterministically exercise the unavailable path, which is itself evidence for the
root-cause diagnosis above. `XCTSkipIf` guards each in case a future CI environment
somehow has a genuinely available streaming provider.

## Validation results

- `swift build` — success.
- `swift test` — 432/432 passing.
- `./build.sh` — success; release built, codesigned, installed to
  `/Applications/DexDictate.app`.
- Manual GUI validation: **not performed.** This environment has no Accessibility
  permission granted for AppleScript/System Events UI scripting
  (`osascript is not allowed assistive access (-1719)`, confirmed by direct attempt), so
  clicking through the popover/Settings or capturing real screenshots isn't possible here.
  See "Andrew validation steps" in the final response for the exact manual checks needed.

## Which providers support true partial results

Nemotron and Apple Speech (see table above). Both require additional one-time user setup
(model download / OS permission) that this fix makes honest and visible, but does not
automate — automating a model download or bypassing the OS permission flow would be a
much larger, riskier change than this bug warranted.

## Which providers are final-only

WhisperKit (compatibility/default), Parakeet, Moonshine.

## Remaining limitations

- This fix makes the feature **honest** and **fixes the two-toggle disconnect** — it does
  not make Nemotron or Apple Speech available without the user completing that one-time
  setup. That's a deliberate, minimal-footprint choice (rule: prefer the smallest correct
  architectural fix over a large speculative one), not an oversight.
- The proactive re-request in `startListening()` cannot make the *current* session stream
  (the OS permission dialog is asynchronous) — only the next attempt after the user
  answers it.
- No visual/GUI validation was performed in this environment (see above); Andrew should
  confirm the actual on-screen appearance.
