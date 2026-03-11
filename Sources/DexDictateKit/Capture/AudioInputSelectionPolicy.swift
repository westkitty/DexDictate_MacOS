import Foundation

public struct AudioInputSelectionDecision: Equatable {
    public let normalizedUID: String
    public let recoveryNotice: String?

    public var fellBackToSystemDefault: Bool {
        normalizedUID.isEmpty && recoveryNotice != nil
    }

    public init(normalizedUID: String, recoveryNotice: String?) {
        self.normalizedUID = normalizedUID
        self.recoveryNotice = recoveryNotice
    }
}

public enum AudioInputSelectionPolicy {
    public static func resolve(preferredUID: String, availableDevices: [AudioInputDevice]) -> AudioInputSelectionDecision {
        guard !preferredUID.isEmpty else {
            return AudioInputSelectionDecision(normalizedUID: "", recoveryNotice: nil)
        }

        if availableDevices.contains(where: { $0.uid == preferredUID }) {
            return AudioInputSelectionDecision(normalizedUID: preferredUID, recoveryNotice: nil)
        }

        return AudioInputSelectionDecision(
            normalizedUID: "",
            recoveryNotice: "Selected microphone is unavailable. DexDictate will use System Default until you choose another device."
        )
    }
}
