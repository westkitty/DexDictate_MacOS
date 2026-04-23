#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)"
LOG_DIR="$HOME/Library/Application Support/DexDictate"
LOG_FILE="$LOG_DIR/debug.log"
DOC_PATH="$ROOT_DIR/docs/AUDIO_ROUTE_RECOVERY_VERIFICATION.md"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
ARCHIVE_LOG="$LOG_DIR/debug.pre-audio-route-verification-$TIMESTAMP.log"

run_tests=1
tail_only=0

usage() {
    cat <<EOF
Usage: ./scripts/verify_audio_route_recovery.sh [--tail] [--skip-tests]

  --tail        Stream only the recovery-related log lines from DexDictate's debug log
  --skip-tests  Skip the targeted automated test pass and print the live checklist only
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tail)
            tail_only=1
            ;;
        --skip-tests)
            run_tests=0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

if [ "$tail_only" -eq 1 ]; then
    echo "[audio-route] streaming recovery log lines from $LOG_FILE"
    tail -n 0 -f "$LOG_FILE" | \
        rg --line-buffered \
            "AVAudioEngineConfigurationChange|handleEngineConfigurationChange|audio recovery —|startRecordingInternal\\(\\) — reason=routeRecovery|performStartAttempt\\(\\) — reason=routeRecovery|wrapAudioStartError\\(\\)|TranscriptionEngine — route recovery"
    exit 0
fi

if [ -s "$LOG_FILE" ]; then
    cp "$LOG_FILE" "$ARCHIVE_LOG"
    echo "[audio-route] archived existing log to $ARCHIVE_LOG"
fi

: > "$LOG_FILE"
echo "[audio-route] reset log file at $LOG_FILE"

cd "$ROOT_DIR"

if [ "$run_tests" -eq 1 ]; then
    echo "[audio-route] running targeted recovery tests"
    swift test --filter AudioDeviceManagerTests
    swift test --filter AudioInputSelectionPolicyTests
    swift test --filter AudioRecorderRecoveryPlannerTests
    swift test --filter AudioRecorderRecoveryFailureTests
    swift test --filter EngineLifecycleStateMachineTests
fi

cat <<EOF

[audio-route] live verification checklist

Scenario under test
- Bluetooth output active
- Built-in Mac microphone selected in DexDictate
- Another audio app such as Zoom is active
- Route churn occurs during an active DexDictate recording

Recommended procedure
1. If you need a fresh app build, run: ./build.sh --user
2. In a second terminal, stream the recovery logs:
   ./scripts/verify_audio_route_recovery.sh --tail
3. Launch the DexDictate build you want to verify.
4. In DexDictate, set the preferred input to the built-in Mac microphone.
5. In macOS Sound settings, set output to a Bluetooth headset or speaker.
6. Start Zoom and keep it holding the audio route open using a meeting, mic test, or audio settings preview.
7. Start a DexDictate recording.
8. While DexDictate is still listening, force route churn:
   - turn the Bluetooth output device off and back on, or
   - switch macOS output away from Bluetooth and back, or
   - disconnect and reconnect the Bluetooth output device
9. Stop the recording and inspect DexDictate behavior plus the filtered log stream.

Expected result for this failure class
- DexDictate should stay on the built-in microphone when that preferred input still exists.
- The strongest success signal is:
  TranscriptionEngine — route recovery succeeded; ... usedSystemDefault=false
- A successful preferred-path recovery should also show:
  audio recovery — preferred uid=... resolved ...
  performStartAttempt() — reason=routeRecovery ...

Acceptable fallback
- If the preferred microphone is actually missing or no longer usable as an input, DexDictate may fall back to System Default input.
- Logs should show one of these notices:
  Selected microphone is unavailable. DexDictate switched to System Default input.
  Selected device is not usable as an input. DexDictate switched to System Default input.
- If the preferred device still exists but could not reopen, fallback is still possible, but the stored preference should not be cleared.

What to inspect when recovery fails
- Confirm the route-change trigger exists:
  AVAudioEngineConfigurationChange — hardware route changed, scheduling recovery
- Confirm DexDictate attempted recovery for the expected preferred UID:
  handleEngineConfigurationChange() — attempting recovery for preferredUID='...'
- Inspect each preferred retry:
  audio recovery — preferred uid=... resolved to deviceID=..., hasInputChannels=..., attempt=...
- Inspect startup failures:
  wrapAudioStartError() — stage=route-recovery preferred start ...
- Inspect terminal failure:
  handleEngineConfigurationChange() — recovery FAILED ...
  TranscriptionEngine — route recovery failed ...

Failure interpretation
- If the preferred UID resolves and has input channels but repeated starts fail, this is the exact brittle path we are chasing.
- If logs include -10868 or kAudioOutputUnitErr_InvalidDevice, suspect Core Audio route contention or a sick coreaudiod, not just selection-policy drift.
- If no AVAudioEngineConfigurationChange log appears, the churn did not hit DexDictate's recorder path, so the run does not prove recovery.

Full log file
- $LOG_FILE

Reference doc
- $DOC_PATH

Post-run grep
- rg -n "AVAudioEngineConfigurationChange|handleEngineConfigurationChange|audio recovery —|startRecordingInternal\\(\\) — reason=routeRecovery|performStartAttempt\\(\\) — reason=routeRecovery|wrapAudioStartError\\(\\)|TranscriptionEngine — route recovery" "$LOG_FILE"
EOF
