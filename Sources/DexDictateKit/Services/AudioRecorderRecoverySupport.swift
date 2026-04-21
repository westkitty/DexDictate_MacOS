import CoreAudio
import Foundation

enum AudioRecorderStartReason: String, Equatable {
    case initialStart
    case routeRecovery
}

enum AudioRecorderSelectedInput: Equatable {
    case systemDefault
    case preferred(AudioInputDeviceMatch)
}

struct AudioRecorderStartedInput: Equatable {
    let uid: String
    let deviceID: AudioDeviceID?
}

public struct AudioRecorderStartReport: Equatable {
    let reason: AudioRecorderStartReason
    let requestedPreferredUID: String
    let activeInputUID: String
    let activeInputDeviceID: AudioDeviceID?
    let preferredInputDeviceID: AudioDeviceID?
    let usedSystemDefault: Bool
    let retryCount: Int
    let recoveryNotice: String?
    let shouldClearStoredPreferredUID: Bool

    var finalDecisionDescription: String {
        if usedSystemDefault {
            return "systemDefault"
        }
        return activeInputUID.isEmpty ? "unknownPreferred" : "preferred:\(activeInputUID)"
    }
}

public struct AudioRecorderRecoveryFailure: Error, LocalizedError {
    let reason: AudioRecorderStartReason
    let requestedPreferredUID: String
    let preferredInputDeviceID: AudioDeviceID?
    let retryCount: Int
    let recoveryNotice: String?
    let shouldClearStoredPreferredUID: Bool
    let underlyingError: Error

    public var errorDescription: String? {
        if let recoveryNotice, !recoveryNotice.isEmpty {
            return recoveryNotice
        }

        switch reason {
        case .initialStart:
            return "DexDictate could not open the selected microphone. Try again."
        case .routeRecovery:
            return "DexDictate could not recover audio after the route changed. Ready to record again."
        }
    }
}

struct AudioRecorderRecoveryPlanner {
    let retryDelays: [TimeInterval]
    let sleep: (TimeInterval) -> Void
    let log: (String) -> Void
    let resolvePreferredInput: (String) -> AudioInputDeviceResolution
    let startAttempt: (AudioRecorderSelectedInput, AudioRecorderStartReason, Int) throws -> AudioRecorderStartedInput

    func execute(preferredUID: String, reason: AudioRecorderStartReason) throws -> AudioRecorderStartReport {
        let effectiveRetryDelays = retryDelays.isEmpty ? [0] : retryDelays
        var lastResolution: AudioInputDeviceResolution = .systemDefault
        var lastPreferredStartError: Error?
        var lastPreferredDeviceID: AudioDeviceID?
        var preferredAttemptCount = 0

        preferredLoop: if !preferredUID.isEmpty {
            for (index, delay) in effectiveRetryDelays.enumerated() {
                preferredAttemptCount = index + 1
                if index > 0 && delay > 0 {
                    log("audio recovery — sleeping \(Int(delay * 1000))ms before preferred retry \(index + 1) for uid=\(preferredUID)")
                    sleep(delay)
                }

                let resolution = resolvePreferredInput(preferredUID)
                lastResolution = resolution

                switch resolution {
                case .systemDefault:
                    log("audio recovery — empty preferred UID; skipping preferred-device recovery")
                    break preferredLoop
                case .available(let match):
                    lastPreferredDeviceID = match.deviceID
                    log("audio recovery — preferred uid=\(match.uid) resolved to deviceID=\(match.deviceID), hasInputChannels=\(match.hasInputChannels), attempt=\(index + 1)")
                    do {
                        let startedInput = try startAttempt(.preferred(match), reason, index)
                        return AudioRecorderStartReport(
                            reason: reason,
                            requestedPreferredUID: preferredUID,
                            activeInputUID: startedInput.uid,
                            activeInputDeviceID: startedInput.deviceID,
                            preferredInputDeviceID: match.deviceID,
                            usedSystemDefault: false,
                            retryCount: index,
                            recoveryNotice: nil,
                            shouldClearStoredPreferredUID: false
                        )
                    } catch {
                        lastPreferredStartError = error
                        log("audio recovery — preferred start failed for uid=\(preferredUID), deviceID=\(match.deviceID), attempt=\(index + 1): \(error)")
                    }
                case .missing(let uid):
                    log("audio recovery — preferred uid=\(uid) is missing on attempt \(index + 1)")
                case .unavailableAsInput(let uid, let deviceID):
                    lastPreferredDeviceID = deviceID
                    log("audio recovery — preferred uid=\(uid) resolved to deviceID=\(String(describing: deviceID)) but hasInputChannels=false; falling back")
                    break preferredLoop
                }
            }
        }

        let fallbackNotice = Self.fallbackNotice(
            preferredUID: preferredUID,
            lastResolution: lastResolution,
            lastPreferredStartError: lastPreferredStartError,
            reason: reason
        )
        let shouldClearStoredPreferredUID = Self.shouldClearStoredPreferredUID(
            preferredUID: preferredUID,
            lastResolution: lastResolution
        )

        do {
            let startedInput = try startAttempt(.systemDefault, reason, 0)
            return AudioRecorderStartReport(
                reason: reason,
                requestedPreferredUID: preferredUID,
                activeInputUID: startedInput.uid,
                activeInputDeviceID: startedInput.deviceID,
                preferredInputDeviceID: lastPreferredDeviceID,
                usedSystemDefault: true,
                retryCount: max(preferredAttemptCount - 1, 0),
                recoveryNotice: fallbackNotice,
                shouldClearStoredPreferredUID: shouldClearStoredPreferredUID
            )
        } catch {
            throw AudioRecorderRecoveryFailure(
                reason: reason,
                requestedPreferredUID: preferredUID,
                preferredInputDeviceID: lastPreferredDeviceID,
                retryCount: max(preferredAttemptCount - 1, 0),
                recoveryNotice: fallbackNotice,
                shouldClearStoredPreferredUID: shouldClearStoredPreferredUID,
                underlyingError: error
            )
        }
    }

    private static func shouldClearStoredPreferredUID(
        preferredUID: String,
        lastResolution: AudioInputDeviceResolution
    ) -> Bool {
        guard !preferredUID.isEmpty else { return false }

        switch lastResolution {
        case .missing, .unavailableAsInput:
            return true
        case .systemDefault, .available:
            return false
        }
    }

    private static func fallbackNotice(
        preferredUID: String,
        lastResolution: AudioInputDeviceResolution,
        lastPreferredStartError: Error?,
        reason: AudioRecorderStartReason
    ) -> String? {
        guard !preferredUID.isEmpty else { return nil }

        let prefix = reason == .routeRecovery
            ? "Preferred microphone could not be restored after the audio route changed."
            : "Preferred microphone could not be opened."

        switch lastResolution {
        case .systemDefault:
            return nil
        case .missing:
            return "Selected microphone is unavailable. DexDictate switched to System Default input."
        case .unavailableAsInput:
            return "Selected device is not usable as an input. DexDictate switched to System Default input."
        case .available:
            _ = lastPreferredStartError
            return "\(prefix) DexDictate switched to System Default input."
        }
    }
}
