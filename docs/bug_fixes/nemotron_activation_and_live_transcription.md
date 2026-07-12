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
