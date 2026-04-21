import Foundation

public enum AudioInputSelectionStatus: Equatable {
    case systemDefault
    case preferredAvailable
    case preferredTemporarilyUnavailable
    case fellBackToSystemDefault
}

public struct AudioInputSelectionDecision: Equatable {
    public let normalizedUID: String
    public let recoveryNotice: String?
    public let status: AudioInputSelectionStatus
    public let shouldScheduleRecheck: Bool

    public var fellBackToSystemDefault: Bool {
        status == .fellBackToSystemDefault
    }

    public init(
        normalizedUID: String,
        recoveryNotice: String?,
        status: AudioInputSelectionStatus,
        shouldScheduleRecheck: Bool
    ) {
        self.normalizedUID = normalizedUID
        self.recoveryNotice = recoveryNotice
        self.status = status
        self.shouldScheduleRecheck = shouldScheduleRecheck
    }
}

public enum AudioInputSelectionPolicy {
    public static func resolve(
        preferredUID: String,
        availableDevices: [AudioInputDevice],
        missingPreferredGraceExpired: Bool = true
    ) -> AudioInputSelectionDecision {
        guard !preferredUID.isEmpty else {
            return AudioInputSelectionDecision(
                normalizedUID: "",
                recoveryNotice: nil,
                status: .systemDefault,
                shouldScheduleRecheck: false
            )
        }

        if availableDevices.contains(where: { $0.uid == preferredUID }) {
            return AudioInputSelectionDecision(
                normalizedUID: preferredUID,
                recoveryNotice: nil,
                status: .preferredAvailable,
                shouldScheduleRecheck: false
            )
        }

        if !missingPreferredGraceExpired {
            return AudioInputSelectionDecision(
                normalizedUID: preferredUID,
                recoveryNotice: "Selected microphone is temporarily unavailable. DexDictate will keep trying it before falling back to System Default.",
                status: .preferredTemporarilyUnavailable,
                shouldScheduleRecheck: true
            )
        }

        return AudioInputSelectionDecision(
            normalizedUID: "",
            recoveryNotice: "Selected microphone is unavailable. DexDictate will use System Default until you choose another device.",
            status: .fellBackToSystemDefault,
            shouldScheduleRecheck: false
        )
    }
}
