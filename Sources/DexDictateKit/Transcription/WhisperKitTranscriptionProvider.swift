import Foundation

/// Wraps the existing, unchanged `WhisperService` batch pipeline behind `TranscriptionProvider`
/// so it can be reported on and selected by the registry like every other engine.
///
/// This does NOT take over how `TranscriptionEngine` drives live dictation — that flow still
/// calls `WhisperService` directly, exactly as before this architecture existed, so the
/// tuned batch/retry/warm-up behavior is untouched. `startTranscription()`/`stopTranscription()`
/// here exist for registry/diagnostics completeness and for callers that want a uniform
/// provider API (e.g. future command-mode or benchmark tooling).
@MainActor
public final class WhisperKitTranscriptionProvider: TranscriptionProvider {
    public let id: TranscriptionProviderID = .whisperKit
    public let displayName = "Whisper (SwiftWhisper, local)"
    public let userFacingModeName = "Compatibility"
    public let mode: TranscriptionMode = .compatibility
    public let locality: TranscriptionProviderLocality = .local

    public let supportsStreaming = false
    public let supportsPartialResults = false
    public let supportsPunctuation = true
    public let supportsCommands = true

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private let whisperService: WhisperService

    public var modelInstallStatus: TranscriptionModelInstallStatus {
        WhisperModelCatalog.shared.activeDescriptor() != nil ? .installed : .notInstalled
    }

    public init(whisperService: WhisperService) {
        self.whisperService = whisperService
    }

    public func healthCheck() -> TranscriptionProviderHealth {
        guard WhisperModelCatalog.shared.activeDescriptor() != nil else {
            return .unavailable("No Whisper model is installed. Add a model file to the Models folder.")
        }
        return .available()
    }

    public func startTranscription() throws {
        guard healthCheck().isAvailable else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Whisper is unavailable.")
        }
        // No-op: live dictation drives WhisperService directly via TranscriptionEngine.
    }

    public func stopTranscription() {
        whisperService.cancelTranscription()
    }
}
