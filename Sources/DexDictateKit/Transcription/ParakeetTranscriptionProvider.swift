import Foundation
import AVFoundation
import FluidAudio

/// Real Parakeet TDT 0.6B v3 provider, backed by FluidAudio's `AsrManager`
/// (native Swift/CoreML, Apple Neural Engine). Batch (fast local) transcription —
/// not streaming; this is the "fast local normal dictation" mode from the provider spec.
///
/// This provider is real and selectable via diagnostics/health-check, but is not wired as
/// the engine that drives the main dictation trigger in this pass — Whisper remains the
/// engine `TranscriptionEngine` calls for the committed/pasted transcript, preserving
/// existing behavior. Wiring Parakeet in as an alternate *default* dictation engine is a
/// larger, separate change (see report).
///
/// Model weights are NOT downloaded automatically — `healthCheck()` reports unavailable
/// until `downloadModelsIfNeeded()` has been explicitly triggered.
@MainActor
public final class ParakeetTranscriptionProvider: TranscriptionProvider {
    public let id: TranscriptionProviderID = .parakeetTDT06Bv3
    public let displayName = "Parakeet TDT 0.6B v3"
    public let userFacingModeName = "Fast Local"
    public let mode: TranscriptionMode = .fastLocal
    public let locality: TranscriptionProviderLocality = .local

    public let supportsStreaming = false
    public let supportsPartialResults = false
    public let supportsPunctuation = true
    public let supportsCommands = false

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private static let version: AsrModelVersion = .v3

    private var manager: AsrManager?
    public private(set) var isDownloading = false
    public private(set) var lastDownloadError: String?

    public init() {}

    public var modelInstallStatus: TranscriptionModelInstallStatus {
        manager != nil ? .installed : (modelsExistOnDisk() ? .installed : .notInstalled)
    }

    public func healthCheck() -> TranscriptionProviderHealth {
        guard SystemInfo.isAppleSilicon else {
            return .unavailable("Parakeet requires Apple Silicon (Neural Engine).")
        }
        if manager != nil {
            return .available()
        }
        if isDownloading {
            return .unavailable("Parakeet models are still downloading.")
        }
        if let lastDownloadError {
            return .unavailable("Parakeet model download failed: \(lastDownloadError)")
        }
        guard modelsExistOnDisk() else {
            return .unavailable("Parakeet models aren't downloaded yet. Download them from Live Transcription diagnostics.")
        }
        return .unavailable("Parakeet models are downloaded but not loaded yet.")
    }

    private func modelsExistOnDisk() -> Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: Self.version), version: Self.version)
    }

    /// Explicit, user-triggered model download + load. Never called automatically.
    public func downloadModelsIfNeeded() async {
        guard manager == nil, !isDownloading else { return }
        isDownloading = true
        lastDownloadError = nil
        do {
            let models = try await AsrModels.downloadAndLoad(version: Self.version)
            manager = AsrManager(models: models)
        } catch {
            lastDownloadError = error.localizedDescription
            Safety.log("Parakeet model download/load failed: \(error.localizedDescription)", category: .transcription)
        }
        isDownloading = false
    }

    public func startTranscription() throws {
        guard manager != nil else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Parakeet is unavailable.")
        }
        // Batch provider: transcription happens per-call via transcribeBatch(_:), not a
        // long-lived session. No-op here for protocol conformance/diagnostics parity.
    }

    public func stopTranscription() {}

    /// Batch transcription entry point — takes 16kHz mono float samples (the same format
    /// Whisper already consumes via `AudioResampler.resampleToWhisper`).
    ///
    /// Creates a fresh `TdtDecoderState` per call rather than persisting one across calls:
    /// each dictation utterance is independent (silence before and after), and FluidAudio's
    /// own reference implementation (`SlidingWindowAsrManager`) likewise creates a new
    /// decoder state at the start of every session — reusing one across separate utterances
    /// would leak LSTM/decoder context from one utterance into the next, matching why
    /// Whisper's live-dictation params set `no_context = true`.
    public func transcribeBatch(samples: [Float]) async throws -> String {
        guard let manager else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Parakeet is unavailable.")
        }
        var state = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &state)
        return result.text
    }
}
