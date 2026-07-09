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

public enum AudioErrorClassifier {
    public static func isCoreAudioDeviceStall(_ error: Error) -> Bool {
        let nsError = error as NSError

        // 1. Verify code matches kAudioOutputUnitErr_InvalidDevice (-10868)
        if nsError.code == -10868 {
            let domain = nsError.domain
            // Treat as device stall if domain is a known audio or system domain
            if domain == NSOSStatusErrorDomain ||
               domain.contains("AVFoundation") ||
               domain.contains("Audio") ||
               domain.contains("coreaudio") ||
               domain.contains("avfaudio") {
                return true
            }

            // Or if domain is generic/unknown but localized description contains explicit CoreAudio evidence
            let desc = nsError.localizedDescription.lowercased()
            if desc.contains("kaudiooutputuniterr_invaliddevice") ||
               desc.contains("coreaudio") ||
               desc.contains("avfaudio") {
                return true
            }
        }

        // 2. Fallback description searches across all other errors (where code is not -10868)
        if nsError.code != -10868 {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("-10868") || desc.contains("kaudiooutputuniterr_invaliddevice") {
                return true
            }
        }

        // 3. Fallback matching for DictationError setup failures
        if let dictationError = error as? DictationError,
           case .audioEngineSetupFailed(let msg) = dictationError {
            let lowered = msg.lowercased()
            return lowered.contains("-10868") || lowered.contains("kaudiooutputuniterr_invaliddevice")
        }

        return false
    }
}

struct AudioRecorderRecoveryPlanner {
    let retryDelays: [TimeInterval]
    let sleep: (TimeInterval) -> Void
    let log: (String) -> Void
    let resolvePreferredInput: (String) -> AudioInputDeviceResolution
    let startAttempt: (AudioRecorderSelectedInput, AudioRecorderStartReason, Int) throws -> AudioRecorderStartedInput
    let markPreferredDeviceStalled: (String) -> Void

    init(
        retryDelays: [TimeInterval],
        sleep: @escaping (TimeInterval) -> Void,
        log: @escaping (String) -> Void,
        resolvePreferredInput: @escaping (String) -> AudioInputDeviceResolution,
        startAttempt: @escaping (AudioRecorderSelectedInput, AudioRecorderStartReason, Int) throws -> AudioRecorderStartedInput,
        markPreferredDeviceStalled: @escaping (String) -> Void = { _ in }
    ) {
        self.retryDelays = retryDelays
        self.sleep = sleep
        self.log = log
        self.resolvePreferredInput = resolvePreferredInput
        self.startAttempt = startAttempt
        self.markPreferredDeviceStalled = markPreferredDeviceStalled
    }

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
                        if AudioErrorClassifier.isCoreAudioDeviceStall(error) {
                            log("audio recovery — Core Audio error -10868 detected for preferred uid=\(preferredUID); falling back to System Default and starting cooldown")
                            markPreferredDeviceStalled(preferredUID)
                            break preferredLoop
                        }
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

        let isStall = lastPreferredStartError.map { AudioErrorClassifier.isCoreAudioDeviceStall($0) } ?? false
        let stallHint = isStall ? " Core Audio error -10868 detected. Use Advanced > Reset Core Audio if microphone input keeps failing." : ""

        switch lastResolution {
        case .systemDefault:
            return nil
        case .missing:
            return "Selected microphone is unavailable. DexDictate switched to System Default input.\(stallHint)"
        case .unavailableAsInput:
            return "Selected device is not usable as an input. DexDictate switched to System Default input.\(stallHint)"
        case .available:
            _ = lastPreferredStartError
            return "\(prefix) DexDictate switched to System Default Input.\(stallHint)"
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
}
