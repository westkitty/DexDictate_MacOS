# Audio Route Recovery Verification

This verification pass is for the failure class DexDictate is currently chasing:

- Bluetooth output device active
- Built-in Mac microphone selected as DexDictate's preferred input
- Another audio app such as Zoom active at the same time
- Route churn during an active DexDictate recording

## Why this exists

The repository already had good isolated coverage for recovery policy:

- `AudioDeviceManagerTests`
- `AudioInputSelectionPolicyTests`
- `AudioRecorderRecoveryPlannerTests`
- `AudioRecorderRecoveryFailureTests`
- `EngineLifecycleStateMachineTests`

What it did not have was a reproducible repo-local pass for the live macOS behavior where Bluetooth output churn and another app's Core Audio activity interact with DexDictate's preferred-input recovery.

## Exact command

```bash
./scripts/verify_audio_route_recovery.sh
```

For a filtered live log stream in a second terminal:

```bash
./scripts/verify_audio_route_recovery.sh --tail
```

## What the script does

1. Archives the existing DexDictate debug log if one exists
2. Resets `~/Library/Application Support/DexDictate/debug.log`
3. Runs the targeted automated tests listed above
4. Prints the live route-churn checklist and the exact log lines to inspect

## Live procedure

1. If needed, build and install a fresh app with `./build.sh --user`
2. Launch DexDictate
3. Set DexDictate's preferred input to the built-in Mac microphone
4. Set macOS output to a Bluetooth headset or speaker
5. Start Zoom and keep it actively holding the audio route using a meeting, mic test, or settings preview
6. Start a DexDictate recording
7. While DexDictate is listening, cause output-route churn:
   - power the Bluetooth output device off and back on, or
   - switch macOS output away from Bluetooth and back, or
   - disconnect and reconnect the Bluetooth output device
8. Stop the recording
9. Inspect DexDictate behavior and the filtered recovery logs

## Expected behavior

For this exact scenario, the preferred built-in microphone should usually remain present and usable. The expected result is therefore preferred-path recovery, not a silent fallback.

Success signals in logs:

- `AVAudioEngineConfigurationChange — hardware route changed, scheduling recovery`
- `handleEngineConfigurationChange() — attempting recovery for preferredUID='...'`
- `audio recovery — preferred uid=... resolved to deviceID=..., hasInputChannels=true, attempt=...`
- `performStartAttempt() — reason=routeRecovery ...`
- `TranscriptionEngine — route recovery succeeded; ... usedSystemDefault=false`

## Acceptable fallback behavior

Fallback to System Default input is acceptable only when the preferred input is genuinely unavailable or no longer usable as an input.

Expected fallback notices:

- `Selected microphone is unavailable. DexDictate switched to System Default input.`
- `Selected device is not usable as an input. DexDictate switched to System Default input.`

If the preferred device still resolves and advertises input channels, but DexDictate still falls back, that is a degraded recovery. It may still keep the session alive, but it is not the preferred outcome for this failure class.

## What to inspect when recovery fails

Inspect these log shapes in order:

1. Route-change trigger reached the recorder:
   - `AVAudioEngineConfigurationChange — hardware route changed, scheduling recovery`
2. DexDictate attempted recovery for the expected device:
   - `handleEngineConfigurationChange() — attempting recovery for preferredUID='...'`
3. Preferred-device retries happened:
   - `audio recovery — preferred uid=... resolved to deviceID=..., hasInputChannels=..., attempt=...`
4. Start failures were wrapped and classified:
   - `wrapAudioStartError() — stage=route-recovery preferred start ...`
5. Final failure reached the engine/UI boundary:
   - `handleEngineConfigurationChange() — recovery FAILED ...`
   - `TranscriptionEngine — route recovery failed ...`

## Interpreting common bad outcomes

- Preferred UID resolves, input channels are present, but repeated starts fail:
  This is the brittle reopen path the current work is supposed to harden.
- `-10868` or `kAudioOutputUnitErr_InvalidDevice` appears:
  This points at Core Audio route contention or a broken `coreaudiod` state, not merely wrong device selection.
- No `AVAudioEngineConfigurationChange` line appears:
  The route churn did not reach DexDictate's recorder path, so the run is not useful evidence.

## Primary log file

```text
~/Library/Application Support/DexDictate/debug.log
```
