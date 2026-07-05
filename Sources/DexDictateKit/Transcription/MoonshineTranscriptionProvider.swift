import Foundation
import MoonshineVoice

/// Real Moonshine v2 provider, backed by the first-party `moonshine-ai/moonshine-swift`
/// package (native Swift + ONNX Runtime). Command mode — batch transcription of short
/// utterances via `transcribeWithoutStreaming`, matching the "low-latency short command
/// recognition" purpose from the provider spec.
///
/// Model weights are NOT bundled and NOT downloaded automatically. `healthCheck()` reports
/// unavailable until `downloadModelsIfNeeded()` has been explicitly triggered, mirroring
/// Parakeet/Nemotron. Downloads hit `download.moonshine.ai` directly (component list and URL
/// shape verified against the upstream Python downloader) — no Python dependency required.
@MainActor
public final class MoonshineTranscriptionProvider: TranscriptionProvider {
    public let id: TranscriptionProviderID = .moonshineV2
    public let displayName = "Moonshine v2 (Tiny Streaming, English)"
    public let userFacingModeName = "Command"
    public let mode: TranscriptionMode = .command
    public let locality: TranscriptionProviderLocality = .local

    public let supportsStreaming = true
    public let supportsPartialResults = false
    public let supportsPunctuation = false
    public let supportsCommands = true

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private static let modelArch: ModelArch = .tinyStreaming
    private static let downloadURLString = "https://download.moonshine.ai/model/tiny-streaming-en/quantized"
    private static let components = [
        "adapter.ort", "cross_kv.ort", "decoder_kv.ort", "encoder.ort", "frontend.ort",
        "streaming_config.json", "tokenizer.bin", "decoder_kv_with_attention.ort",
    ]

    private var transcriber: Transcriber?
    public private(set) var isDownloading = false
    public private(set) var lastDownloadError: String?

    public init() {}

    private var modelDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("DexDictate", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Moonshine", isDirectory: true)
            .appendingPathComponent("tiny-streaming-en", isDirectory: true)
    }

    public var modelInstallStatus: TranscriptionModelInstallStatus {
        transcriber != nil ? .installed : (modelsExistOnDisk() ? .installed : .notInstalled)
    }

    public func healthCheck() -> TranscriptionProviderHealth {
        if transcriber != nil {
            return .available()
        }
        if isDownloading {
            return .unavailable("Moonshine models are still downloading.")
        }
        if let lastDownloadError {
            return .unavailable("Moonshine model download failed: \(lastDownloadError)")
        }
        guard modelsExistOnDisk() else {
            return .unavailable("Moonshine models aren't downloaded yet. Download them from Live Transcription diagnostics.")
        }
        return .unavailable("Moonshine models are downloaded but not loaded yet.")
    }

    private func modelsExistOnDisk() -> Bool {
        let fm = FileManager.default
        return Self.components.allSatisfy { fm.fileExists(atPath: modelDirectory.appendingPathComponent($0).path) }
    }

    /// Explicit, user-triggered model download + load. Never called automatically.
    public func downloadModelsIfNeeded() async {
        guard transcriber == nil, !isDownloading else { return }
        isDownloading = true
        lastDownloadError = nil
        do {
            if !modelsExistOnDisk() {
                try await downloadComponents()
            }
            transcriber = try Transcriber(modelPath: modelDirectory.path, modelArch: Self.modelArch)
        } catch {
            lastDownloadError = error.localizedDescription
            Safety.log("Moonshine model download/load failed: \(error.localizedDescription)", category: .transcription)
        }
        isDownloading = false
    }

    private func downloadComponents() async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        guard let baseURL = URL(string: Self.downloadURLString) else {
            throw TranscriptionProviderError.unavailable("Invalid Moonshine model download URL.")
        }
        for component in Self.components {
            let remoteURL = baseURL.appendingPathComponent(component)
            let destinationURL = modelDirectory.appendingPathComponent(component)
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                try? fm.removeItem(at: tempURL)
                throw TranscriptionProviderError.unavailable("Failed to download \(component) (unexpected server response).")
            }
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: tempURL, to: destinationURL)
        }
    }

    public func startTranscription() throws {
        guard transcriber != nil else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Moonshine is unavailable.")
        }
        // Batch provider: transcription happens per-call via transcribeBatch(_:), not a
        // long-lived session. No-op here for protocol conformance/diagnostics parity.
    }

    public func stopTranscription() {}

    /// Batch transcription entry point for short command phrases — takes 16kHz mono float
    /// samples (the same format Whisper already consumes).
    ///
    /// `Transcriber.transcribeWithoutStreaming` is a synchronous, blocking ONNX Runtime call.
    /// Since this provider type is `@MainActor`, calling it directly would block the UI thread
    /// for the duration of inference — so the actual call is offloaded to a detached task.
    public func transcribeBatch(samples: [Float]) async throws -> String {
        guard let transcriber else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Moonshine is unavailable.")
        }
        return try await Task.detached(priority: .userInitiated) {
            let transcript = try transcriber.transcribeWithoutStreaming(audioData: samples, sampleRate: 16000)
            return transcript.lines.map { $0.text }.joined(separator: " ")
        }.value
    }
}
