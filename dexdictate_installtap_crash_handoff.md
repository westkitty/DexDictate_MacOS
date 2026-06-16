# DexDictate 1.5.3 Crash Handoff — installTap NSException SIGABRT

## Crash

- **Crash ID:** `48CE6BEE-99AE-41EC-8D5B-EA70BE5D4932`
- **Version:** DexDictate 1.5.3
- **OS:** macOS 26.5.1, Apple Silicon
- **Exception:** `EXC_CRASH (SIGABRT)` — `abort() called`, uncaught Objective-C exception
- **Triggered by:** Thread 11, dispatch queue `com.dexdictate.audioEngine`
- **Fatal stack:**
  - `AVAudioEngineImpl::InstallTapOnNode`
  - `-[AVAudioNode installTapOnBus:bufferSize:format:block:]`
  - `AudioRecorderService.performStartAttempt(...)` (installTap call)
  - `AudioRecorderRecoveryPlanner.execute(preferredUID:reason:)`
  - `AudioRecorderService.startRecordingInternal(...)`
  - `AudioRecorderService.startRecordingAsync(...)`

## Root cause class

**NSException from `AVAudioEngine` tap installation during start/recovery.**

`-[AVAudioNode installTapOnBus:...]` raises an Objective-C `NSException` (not an
`NSError`) when an internal precondition fails. With `format: nil` it re-reads the
input node's hardware bus format *at install time*; a hardware route change in the
TOCTOU window between the Swift-side format-validation guard and the install call
makes that format invalid (0 Hz / 0 channels) and AVFoundation raises. Swift
`do/catch` cannot intercept an Objective-C `NSException`, so it reached the uncaught
exception handler and called `abort()`.

The pre-existing Swift guards (`isTapInstalled`, `isHandlingConfigChange`,
post-`prepare()` format validation) lower the probability but cannot eliminate it,
because the exception originates inside AVFoundation after the last Swift-observable
check. Only an Objective-C `@try/@catch` bridge prevents the abort.

## Fix

1. **Objective-C exception bridge.** New target `DexDictateObjCSupport` with
   `DDAudioTapInstaller`, wrapping `installTapOnBus:` and `removeTapOnBus:` in
   `@try/@catch`. A caught `NSException` becomes an `NSError`
   (domain `com.dexdictate.audioTapInstaller`, exception name in `userInfo`),
   surfaced to Swift as a throwing function.
2. **Safe install path.** `AudioRecorderService.performStartAttempt` installs via
   `installInputTapSafely(...)`. On caught failure it logs a structured `audio`
   diagnostic (reason, attempt index, preserveBufferedAudio, selected UID, active
   UID, deviceID, input format, sample rate, channel count, `engine.isRunning`,
   `tapWasBelievedInstalled`), tears down and resets the engine, then throws a
   `DictationError` through the existing planner/completion/recovery path.
3. **Idempotent tap state.** Any existing tap is removed (via the bridge) before a
   new install; stop/recovery/sleep/teardown clear `isTapInstalled`;
   `teardownEngineUnsafe` removes through the bridge.
4. **Reentrancy guard.** `isStartInProgress` + `beginStartAttempt()/endStartAttempt()`
   reject overlapping start/recovery attempts, complementing `isHandlingConfigChange`.

## Files changed

- `Package.swift`
- `Sources/DexDictateObjCSupport/include/AudioTapInstaller.h` (new)
- `Sources/DexDictateObjCSupport/AudioTapInstaller.m` (new)
- `Sources/DexDictateKit/Services/AudioRecorderService.swift`
- `Tests/DexDictateTests/AudioTapInstallerTests.swift` (new)
- `Tests/DexDictateTests/AudioRecorderTapStateTests.swift` (new)
- `docs/DEXDICTATE_BIBLE.md` (Section 23 addendum)

## Validation performed

- `swift test` — 343 tests, 0 failures (7 new). `testDoubleInstallThrowsInsteadOfCrashing`
  forces the real AVFoundation `NSException` and asserts a thrown error; reaching the
  assertion proves no abort.
- `./build.sh --user` — production-config build + codesign + install succeeded.
- `scripts/validate_release.sh .build/DexDictate.app` — 0 failures, 1 warning
  (Gatekeeper, expected for a locally dev-signed build).

## Remaining risks

- The bridge prevents the abort but does not make a broken device usable — a genuinely
  invalid hardware format still fails, now as a recoverable error driving the existing
  bounded recovery / system-default fallback.
- Other AVFoundation calls that can raise `NSException` (`attach`/`connect` in unusual
  states) are not bridged; this fix targets the tap path proven by the crash.
  `engine.start()` already bridges as Swift `throws`.
- True hardware reproduction (physical route change mid-install) was not staged; the
  fix is verified by forcing the same `NSException` class through the bridge in tests.
