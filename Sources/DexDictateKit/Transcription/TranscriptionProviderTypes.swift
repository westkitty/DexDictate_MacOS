import Foundation

/// Stable identifiers for every transcription provider DexDictate knows about, real or stubbed.
public enum TranscriptionProviderID: String, CaseIterable, Codable {
    case parakeetTDT06Bv3
    case nemotron35ASRStreaming06B
    /// Historical naming carried over from the original architecture spec. The production
    /// engine behind this ID is SwiftWhisper (whisper.cpp), not Apple's WhisperKit package —
    /// see `WhisperKitTranscriptionProvider` for the real implementation this ID wraps.
    case whisperKit
    case moonshineV2
    case appleSpeech
}

/// The user-facing dictation mode a provider serves. One provider maps to one mode.
public enum TranscriptionMode: String, CaseIterable, Codable {
    case fastLocal
    case liveStreaming
    case compatibility
    case command
    case appleSpeech

    public var displayName: String {
        switch self {
        case .fastLocal: return "Fast Local"
        case .liveStreaming: return "Live Streaming"
        case .compatibility: return "Compatibility"
        case .command: return "Command"
        case .appleSpeech: return "Apple Speech"
        }
    }
}

/// Where a provider's inference actually runs. DexDictate only ships `.local` and `.native`
/// providers by default; `.cloud` exists so a future opt-in provider can declare itself
/// honestly, but the registry never selects a `.cloud` provider unless the user explicitly
/// enables it (no such provider exists yet).
public enum TranscriptionProviderLocality: String, Codable {
    case local
    case native
    case cloud
}

/// Whether a provider's model/runtime is present on disk, and how we know.
public enum TranscriptionModelInstallStatus: Equatable, Codable {
    case builtIn
    case installed
    case notInstalled
    case unknown
}

/// Result of asking a provider whether it can actually run right now. `isAvailable` is the
/// only thing callers should branch on; `reason` is always populated when unavailable so the
/// UI can show an honest explanation instead of a silent failure.
public struct TranscriptionProviderHealth: Equatable {
    public let isAvailable: Bool
    public let reason: String?
    public let checkedAt: Date

    public init(isAvailable: Bool, reason: String?, checkedAt: Date = Date()) {
        self.isAvailable = isAvailable
        self.reason = reason
        self.checkedAt = checkedAt
    }

    public static func available() -> TranscriptionProviderHealth {
        TranscriptionProviderHealth(isAvailable: true, reason: nil)
    }

    public static func unavailable(_ reason: String) -> TranscriptionProviderHealth {
        TranscriptionProviderHealth(isAvailable: false, reason: reason)
    }
}

/// Errors a provider can throw from `startTranscription()`. Providers must never crash or
/// silently no-op; an unavailable provider throws `.unavailable` with a human-readable reason.
public enum TranscriptionProviderError: Error, LocalizedError {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        }
    }
}
