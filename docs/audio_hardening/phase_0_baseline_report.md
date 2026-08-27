# Phase 0 Baseline Report

- Timestamp: 2026-08-27T11:16:47Z
- Host: MacBook-Air.local
- macOS: 26.6.2
- Architecture: arm64
- Swift: Apple Swift version 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
- Repository root: /Users/andrew/DexDictate_MacOS.nosync
- Work branch HEAD: cba14314e443f9ddc33c601a988f3a78233c0c7a
- origin/main: 7cb739208ea11af6e20beccd9907affbe4500444
- Working tree before tests: clean
- Dependency pins: match

## Build
- swift build: PASS

## Full suite
- swift test: PASS
- Executed: 707
- Failures: 0
- Skips: 11

## Focused regressions
- AudioDeviceManagerTests: PASS
- AudioInputSelectionPolicyTests: PASS
- AudioRecorderRecoveryPlannerTests: PASS
- AudioRecorderRecoveryFailureTests: PASS
- EngineLifecycleStateMachineTests: PASS
- AudioTapInstallerTests: PASS
- AudioRecorderTapStateTests: PASS
- LivePreviewInvariantTests: PASS

## VerificationRunner
- Result: FAIL
- Checks: 62
- Failures: 1
- Earliest failure: FAIL [black] no online networking APIs detected in Sources

## Evidence boundary
- Installed DexDictate app replaced: NO
- Real microphone tested: NO
- Bluetooth/Zoom route churn tested: NO
- TCC changed: NO
- User DexDictate preferences intentionally changed: NO
