# Nemotron Activation and Live Transcription Runtime Repair

## User-visible symptom

Nemotron appeared inaccessible even after being downloaded, so DexDictate silently fell
back to a final-only engine — live partial captions never appeared while speaking, and
Speech Recognition permission had no explicit, retryable request path in Settings.

## Confirmed root cause

This is a continuation of the two-toggle disconnect already fixed and documented in
`docs/bug_fixes/live_transcription_repair.md` (commit `2edc949a`). That fix made the
"no streaming provider available" state honest and visible; it did not fix the deeper
reason Nemotron specifically stayed unavailable session after session even once
downloaded.

**Root cause, confirmed by direct filesystem inspection and passing tests:** Nemotron's
(and, identically, Parakeet's) `isModelLoaded`/`manager != nil` is in-memory state that
resets to "not loaded" on every single app launch, while the downloaded model **files**
persist on disk across launches
(`~/Library/Application Support/FluidAudio/Models/nemotron-streaming/2240ms/`, confirmed
present on this dev machine — encoder/decoder/joint/preprocessor `.mlmodelc`,
`tokenizer.json`, `metadata.json` all already cached). Nothing at app startup re-loaded
an already-downloaded model into the fresh process — so `healthCheck()` reported
"Nemotron models are downloaded but not loaded yet" on every single launch, forever,
until the user manually re-clicked the exact same download/select row in Settings →
Models & Accuracy. From the user's perspective this is indistinguishable from Nemotron
being broken or permanently inaccessible.

This is not a missing-metadata problem — the real HuggingFace repo
(`FluidInference/nemotron-speech-streaming-en-0.6b-coreml`, `2240ms` chunk variant) and
its exact on-disk folder name (`nemotron-streaming/2240ms`) were already correctly
defined in FluidAudio's own `ModelNames.swift`, and the download+load workflow
(`StreamingNemotronAsrManager.loadModels`, `DownloadUtils.downloadRepo`) already existed
and worked correctly — it was simply never invoked again after the first successful
download in a prior session.

## Fix

`Sources/DexDictateKit/Transcription/TranscriptionProviderRegistry.swift`:

- New `loadAlreadyDownloadedModelsIfNeeded(settings:)` — loads models that are already on
  disk but not yet loaded into the current process. Zero network activity: it only calls
  the existing `downloadModelsIfNeeded(for:)` (the same call the manual download button
  already triggers) when `modelInstallStatus == .installed` and `healthCheck().isAvailable
  == false`, so the download branch inside that call never actually executes here — it's
  purely a local model-load. Each candidate is gated on the setting that governs whether
  it should be active (`liveTranscriptionEnabled` for Nemotron, `commandModeEnabled` for
  Moonshine; Parakeet is ungated since it's a primary-engine candidate independent of
  either toggle), so this cannot silently start using CPU/ANE for a feature the user has
  turned off. Recomputes `lastResolution` immediately afterward so Settings status rows
  and `LivePreviewController`'s unavailable-reason messaging reflect the newly-loaded
  provider without waiting for the next dictation attempt.

`Sources/DexDictateKit/TranscriptionEngine.swift`:

- `startSystem()` now calls `registry.loadAlreadyDownloadedModelsIfNeeded(settings:)` in a
  detached `Task`, immediately after the existing Apple Speech authorization-request
  block. Detached (not awaited) so model loading — which can take a moment — never delays
  `setupInputMonitor()`, i.e. never delays the trigger becoming responsive.

## Nemotron activation state machine (confirmed, not invented)

| State | Condition | `healthCheck()` |
|---|---|---|
| Not installed | no cached model files on disk | `.unavailable("...aren't downloaded yet...")` |
| Downloading | `isDownloading == true` | `.unavailable("...still downloading.")` |
| Download failed | `lastDownloadError != nil` | `.unavailable("...download failed: ...")` |
| Downloaded, not loaded (the bug) | files on disk, `isModelLoaded == false` | `.unavailable("...downloaded but not loaded yet.")` — now auto-repaired at launch |
| Ready | `isModelLoaded == true` | `.available()` |

All four non-ready states were already correctly distinguished before this fix — the gap
was purely that the "downloaded, not loaded" state never resolved itself without a manual
re-click.

## Live partial-transcription data path (traced, unchanged by this fix)

Re-confirmed the same path documented in `live_transcription_repair.md`: microphone
buffer → `AudioRecorderService` tap → `provider.appendAudioBuffer(_:)` → provider's own
recognition callback → `provider.onPartialResult` → `TranscriptionEngine.liveTranscript`
→ `DexTranscriptCard` / `LivePreviewCaptionView` / `DexNanoHUDView`. This fix does not
change that path at all — it only ensures Nemotron (the preferred streaming provider)
actually reaches `.available()` so `resolveActiveProvider` selects it instead of falling
through to Apple Speech or Whisper compatibility.

## Provider status vocabulary (Models & Accuracy)

`Sources/DexDictateKit/Transcription/ModelSelectionActions.swift` gained
`LiveStreamingStatus` (via `liveStreamingStatus(settings:registry:)`), a small state
machine over the exact vocabulary requested:

- `.readyNemotron` → "Ready — Nemotron"
- `.readyAppleSpeech` → "Ready — Apple Speech"
- `.nemotronLoading` → "Nemotron loading" (while `isDownloading == true`, which now also
  covers the local-load path this fix added, not just a fresh network download)
- `.finalOnlyFallback(reason:)` → "Final-only fallback — Whisper", with a detail line of
  "Nemotron model not installed", "Speech Recognition permission required", or "No
  streaming provider available" depending on which specific condition applies
- `.liveTranscriptionOff` → "Live Transcription is off"

Rendered in `LiveTranscriptionStatusView` (`Sources/DexDictate/QuickSettingsView.swift`),
replacing the previous raw `"\(selectedProviderDisplayName) (\(modeName))"` composition
with this fixed vocabulary while keeping the existing green/gray status dot.

## Apple Speech explicit permission request

`Sources/DexDictateKit/Transcription/AppleSpeechTranscriptionProvider.swift` gained:

- `AuthorizationState` (`.notDetermined`/`.authorized`/`.denied`/`.restricted`) — mirrors
  `SFSpeechRecognizer.authorizationStatus()` without requiring `import Speech` at
  Settings-UI call sites.
- `static func requestAuthorization(completion:)` — explicitly triggers the macOS
  permission prompt (unlike the pre-existing `requestAuthorizationIfNeeded()`, which
  silently no-ops once any decision, including "denied," already exists).

`LiveTranscriptionStatusView` gained an explicit, always-visible action row (only shown
when not already authorized): "Request Speech Recognition Access" when the status has
never been decided, or "Open Speech Recognition Settings" (via a new
`PermissionSettingsLinker.Permission.speechRecognition` deep link) once it's been denied
or restricted — since macOS never re-prompts for a decision that already exists, only
System Settings can change it at that point.

## Files changed

- `Sources/DexDictateKit/Transcription/TranscriptionProviderRegistry.swift`
- `Sources/DexDictateKit/TranscriptionEngine.swift`
- `Sources/DexDictateKit/Transcription/ModelSelectionActions.swift`
- `Sources/DexDictateKit/Transcription/AppleSpeechTranscriptionProvider.swift`
- `Sources/DexDictateKit/Permissions/PermissionSettingsLinker.swift`
- `Sources/DexDictate/QuickSettingsView.swift`
- `Tests/DexDictateTests/TranscriptionProviderRegistryAutoLoadTests.swift` (new)
- `Tests/DexDictateTests/LiveStreamingStatusVocabularyTests.swift` (new)
- `Tests/DexDictateTests/PermissionSettingsLinkerTests.swift`

## What did not change

- Nemotron support was not removed or disabled — this fix makes it *more* reachable.
- Final (batch Whisper) transcription, output insertion, and audio capture are untouched.
- No storage keys were renamed. No Dexter identity assets/watermarks were touched.
- Live partial text is genuine provider output (Nemotron/Apple Speech's own streaming
  recognition callbacks) — nothing here reveals final text gradually or calls batch
  Whisper "live transcription."

## Tests added

`Tests/DexDictateTests/TranscriptionProviderRegistryAutoLoadTests.swift` (4 tests, all
exercising the real provider objects against whatever model cache genuinely exists on the
machine running the suite — no mocks, since the registry hardwires concrete provider
properties rather than an injectable protocol seam):

1. `testAlreadyDownloadedNemotronBecomesAvailableWithoutManualRedownload` — the core fix;
   also asserts `lastResolution.selectedProviderID == .nemotron35ASRStreaming06B`.
2. `testNemotronIsNotAutoLoadedWhenLiveTranscriptionIsDisabled` — the settings gate holds.
3. `testAlreadyDownloadedParakeetBecomesAvailableIndependentOfLiveTranscriptionSetting`.
4. `testNoOpWhenNothingIsInstalled` — safety/no-crash check.

`Tests/DexDictateTests/LiveStreamingStatusVocabularyTests.swift` (new file):

- `LiveStreamingStatusVocabularyTests` (5 tests) — one per `LiveStreamingStatus` case,
  each `XCTSkipIf`/`XCTSkipUnless`-guarded against the real environment's actual provider
  health (this dev machine has Nemotron installed and Apple Speech unauthorized, so the
  `.readyNemotron` and `.finalOnlyFallback(.speechPermissionRequired)` branches run for
  real; the others document what they'd assert in an environment with different state).
- `AppleSpeechAuthorizationStateTests` (1 test) — `authorizationState` always resolves to
  one of the four known cases.
- `NemotronTranscriptionProviderBasicInvariantTests` (3 tests) — fresh-instance
  invariants (`isSessionActive`/`isDownloading` start false, `stopTranscription()` without
  starting is a safe no-op, the not-downloaded health-check reason text).

`Tests/DexDictateTests/PermissionSettingsLinkerTests.swift` — added
`testSpeechRecognitionURL` for the new `.speechRecognition` deep-link case.

## Validation results

- `swift build` — success.
- `swift test` — 461/461 passing across three consecutive full runs (3 environment-
  dependent skips: no Nemotron/no Parakeet cache in a hypothetical clean environment,
  none actually skipped on this dev machine since both are cached here). One transient,
  non-reproducing failure was observed in an isolated `--filter` run during development;
  three subsequent full-suite runs were clean (461/461, 0 failures) — treated as
  environmental flake from concurrent build/test processes, not a defect in the new
  tests, since it did not recur.
- `./build.sh` — success; release built, codesigned, installed to
  `/Applications/DexDictate.app`.
- `git diff --check` — no whitespace errors.
- Manual GUI validation: **not performed.** This environment has no Accessibility
  permission for AppleScript/System Events UI scripting (`UI elements enabled` reports
  `false` under `osascript`), so clicking through Settings, downloading/loading Nemotron
  interactively, or capturing real partial-caption screenshots isn't possible here. See
  the final response's "Andrew validation steps" for the exact manual checks needed.

## Remaining limitations

- This fix repairs the *reload-after-restart* gap. It does not add a first-run,
  in-app-driven Nemotron download flow beyond what `LiveTranscriptionStatusView`'s
  existing "Download" row already provides — that UI was already present and functional;
  this session did not need to add a new download entry point, only fix why a completed
  download stopped counting as "available" every launch after the first.
- `DownloadUtils`'s richer `DownloadProgress`/`ProgressHandler` (fractional progress,
  compiling-phase reporting) exists in the vendored FluidAudio package but is not yet
  wired into `NemotronTranscriptionProvider.downloadModelsIfNeeded()` — the download
  button still shows an indeterminate spinner, not a percentage. Out of scope for this
  session's specific bug (accessibility after restart, not download UX polish).
- No visual/GUI validation was performed in this environment (see above); Andrew should
  confirm the actual on-screen appearance and that live captions genuinely stream while
  speaking with Nemotron selected.

## Ready-but-no-partials defect (follow-up repair)

### Real user symptom

After the model auto-load fix above shipped, Andrew confirmed via the real app that
Settings → Models & Accuracy correctly reports "Ready — Nemotron" — proving model loading
and provider selection were genuinely fixed. But live partial captions still never
appeared while speaking. Final (batch Whisper) transcription continued to work normally
and appeared quickly after recording stopped. This ruled out the model-availability theory
entirely: the defect was now specifically in the live streaming pipeline itself, between
"Nemotron is selected" and "partial text reaches the UI."

### Confirmed failure category

None of the`LT-1` through `LT-10` categories in the investigation checklist matched
exactly, so this is `LT-11` (another evidence-backed cause) with two compounding,
independently-verified defects in `NemotronTranscriptionProvider`:

1. **Session-activation race (a variant of LT-4/LT-5).** `isSessionActive` only flipped
   `true` after an async `Task` finished `manager.reset()` + `manager.setPartialCallback()`.
   `appendAudioBuffer(_:)` silently dropped every buffer that arrived before that flip, with
   no way to recover a dropped buffer afterward.
2. **Unordered concurrent actor access (closest to LT-7, "streaming decoder never advanced
   correctly").** Every call to `appendAudioBuffer(_:)` spawned its own independent,
   unstructured `Task`. A real utterance produces ~90+ small tap buffers; all of their
   `Task`s raced each other into `StreamingNemotronAsrManager`'s actor mailbox with no
   ordering guarantee relative to one another. RNNT streaming decode carries encoder/decoder
   cache state (`cacheChannel`, `hState`/`cState`, `melCache`, `lastToken`) forward
   chunk-to-chunk; when `appendAudio`/`processBufferedAudio` calls for different buffers
   interleave out of recording order, the model decodes a temporally scrambled
   mel-spectrogram sequence and greedily predicts blank for every frame — no error, no
   crash, just silent 100%-blank output.

### Evidence (empirical, not code-reading speculation)

Three new real-model, real-audio tests (`sample_corpus/sample.wav`, real speech, fed as
~4096-frame buffers matching `AudioRecorderService`'s actual tap buffer size) isolated this
precisely, in order:

1. `NemotronRealAudioPartialPipelineTests` (as it existed before the fix): fed real audio
   through the *unmodified* `NemotronTranscriptionProvider`, using the exact production call
   order (`startTranscription()` → assign `onPartialResult` → feed buffers). Result: **zero
   partial callbacks and zero errors** after a 30-second timeout, for an 8-second utterance
   — reproducing the reported symptom deterministically.
2. `NemotronDirectManagerDiagnosticTests.testDirectManagerOneShotProcessOnRealAudio`:
   bypassed `NemotronTranscriptionProvider` entirely and drove FluidAudio's own
   `StreamingNemotronAsrManager` directly via `process(audioBuffer:)` + `finish()` — the
   exact call shape FluidAudio's own `NemotronTranscribe` CLI reference tool uses. Result:
   **correct transcript** ("This is a longer, much more relaxed test of the benchmark
   harness to make sure Whisper doesn't immediately discard the audio as too short") —
   proving the model and the audio file are both fine.
3. `NemotronDirectManagerDiagnosticTests.testDirectManagerChunkedAppendMatchingRealTapBufferSize`:
   same direct manager, but fed the SAME small ~4096-frame buffers `NemotronTranscriptionProvider`
   would receive, via repeated `appendAudio()` + `processBufferedAudio()` calls, in a
   *sequential, awaited* loop (no concurrent Tasks). Result: **also correct** — proving the
   defect was not the small-buffer chunking itself, only the *unordered concurrency* around it.

This chain of evidence pinpointed the defect to `NemotronTranscriptionProvider`'s own
one-Task-per-buffer concurrency pattern, not FluidAudio, not the audio format, and not the
model.

### Fix

`Sources/DexDictateKit/Transcription/NemotronTranscriptionProvider.swift`:

- `isSessionActive = true` is now set **synchronously** inside `startTranscription()`,
  before the async `reset()`/`setPartialCallback()` work even begins — no more window where
  a real microphone buffer arrives before the provider considers itself ready.
- Replaced the per-buffer independent `Task { ... }` with a single property,
  `pendingSessionTask: Task<Void, Never>?`, that forms a strict FIFO chain: `startTranscription()`'s
  `reset()`/`setPartialCallback()` setup is the first link; every `appendAudioBuffer(_:)`
  call captures the current tail, creates a new `Task` that `await`s it first, then does its
  own `appendAudio`/`processBufferedAudio`, and becomes the new tail. `stopTranscription()`
  also chains `finish()` onto this same tail, so a trailing in-flight append can't race the
  final flush either. This guarantees every buffer is appended and processed in exact
  arrival order, with zero risk of dropped audio, while `appendAudioBuffer(_:)` itself still
  never blocks the real-time audio thread that calls it (it only creates and stores a
  `Task`; it never awaits anything).

### Audio format details

Unchanged and confirmed correct throughout this investigation — `AudioConverter`
(FluidAudio's own resampler) correctly converts arbitrary input formats (any sample rate,
mono/stereo, float/int16) to the 16kHz mono Float32 the model requires, verified by the
direct-manager tests succeeding with both native-rate (48kHz) small buffers and a whole-file
buffer at `AVAudioFile.processingFormat`. The defect was never a format/conversion problem.

### Session ordering (corrected)

Old (broken): `startTranscription()` returns immediately → async setup Task runs
independently → `isSessionActive` flips true whenever that Task happens to finish → each
`appendAudioBuffer(_:)` call independently races every other call into the actor.

New (fixed): `startTranscription()` sets `isSessionActive = true` synchronously and starts
the FIFO chain's first link → every subsequent `appendAudioBuffer(_:)` call joins the same
chain, guaranteed to run strictly after every earlier buffer's work has fully completed →
`stopTranscription()` joins the same chain for `finish()`.

### Tests added

`Tests/DexDictateTests/NemotronRealAudioPartialPipelineTests.swift` (new file, real model +
real audio, no mocks):

1. `testRealNemotronProviderEmitsPartialTranscriptForRealAudio` — the core proof: production
   call order, no artificial waits, asserts a partial containing real recognized words
   arrives, and asserts `isSessionActive` is true synchronously right after
   `startTranscription()` returns (guards directly against regressing the session-activation
   race).
2. `testSecondSessionAfterStopAlsoProducesPartials` — a stop immediately followed by a
   restart (two quick dictations back to back) must not leave `pendingSessionTask` wedged;
   both sessions must produce partials.
3. `testStartTranscriptionThrowsHonestlyWhenModelNotLoaded` — the "no error, no partials,
   just silence" failure mode must never resurface for the model-not-loaded case; a fresh
   provider must throw, not fake a session.
4. `testZeroFrameBufferDoesNotCrashOrProducePartial` — degenerate input safety.

`Tests/DexDictateTests/NemotronDirectManagerDiagnosticTests.swift` (new file, kept
permanently as a regression guard, not just a one-off diagnostic): the two isolation tests
described in "Evidence" above, pinned so a future regression in FluidAudio's own manager
(as opposed to `NemotronTranscriptionProvider`'s wrapper code) would fail these
independently of the provider-level tests.

`Package.swift`: added `FluidAudio` as an explicit dependency of the `DexDictateTests`
target (previously only transitively visible), since the direct-manager diagnostic tests
import it directly.

### Runtime validation status

- `swift build` — success (only the two pre-existing, unrelated warnings: Moonshine's
  non-Sendable `Transcriber` capture, and Nemotron's pre-existing "captured var in
  concurrently-executing code" false-positive-adjacent diagnostic on the partial-callback
  closure, both present before this session and left as-is).
- `swift test` — 467/467 passing, 3 skipped (environment-dependent), across multiple
  consecutive full runs.
- `./build.sh` — success; installed to `/Applications/DexDictate.app`.
- `git diff --check` — clean.
- Manual GUI validation: **not performed.** This environment has no Accessibility
  permission for AppleScript/System Events UI scripting (`UI elements enabled` → `false`
  under `osascript`, confirmed by direct attempt). See the final response's "Andrew
  validation command" for the exact command to confirm the fix on-device after one real
  dictation.
- Temporary diagnostic logging (`Safety.log` calls added mid-investigation to trace
  `isSessionActive` transitions, per-buffer success/failure, and accumulated-transcript
  length) was removed once the root cause was confirmed — only the two permanent test files
  above remain as evidence.

### Remaining limitation

This fix guarantees strict ordering and zero dropped buffers for Nemotron's live-streaming
path specifically. It does not add back-pressure handling for a pathological case where
CoreML inference for one chunk takes so long that many buffers queue up in the FIFO chain
faster than they can be processed — under sustained real-time audio this is bounded by
FluidAudio's own real-time factor (RTFx, documented as its own performance requirement to
stay above 1.0x), so in practice the chain should never grow unbounded, but no explicit cap
or drop-oldest policy was added since no evidence of this occurring was observed.
