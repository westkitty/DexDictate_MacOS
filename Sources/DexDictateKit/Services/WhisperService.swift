import Foundation
import SwiftWhisper

@MainActor
public class WhisperService: ObservableObject {
    private var whisper: Whisper?
    @Published public var isModelLoaded: Bool = false
    @Published public var isTranscribing: Bool = false

    /// Serialises transcription calls — cancels the previous task before starting a new one,
    /// preventing concurrent access to the non-thread-safe whisper.cpp C++ object.
    private var transcriptionTask: Task<Void, Never>?

    // Callback closure to pass text back to the engine (marked Sendable for thread-safe access)
    public var ontranscriptionComplete: (@Sendable (String) -> Void)?

    public init() {}
    
    public func loadModel(url: URL) {
        do {
#if DEBUG
            Safety.log("DEBUG build detected — transcription may be slow without optimized SwiftWhisper binaries")
#endif
            // Verify model file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                Safety.log("ERROR: Model file not found at \(url.path)")
                isModelLoaded = false
                return
            }

            // Check available disk space to prevent silent failures
            let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let availableSpace = resourceValues.volumeAvailableCapacity ?? 0

            // Get model file size
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let modelSize = attrs[.size] as? UInt64 ?? 0

            // Ensure we have enough space (model size + 100MB safety margin)
            let requiredSpace = Int64(modelSize) + (100 * 1024 * 1024)
            guard availableSpace > requiredSpace else {
                Safety.log("ERROR: Insufficient disk space: need \(requiredSpace) bytes, have \(availableSpace) bytes")
                isModelLoaded = false
                return
            }

            // Build speed-optimised params before loading the model.
            let params = Self.makeFastParams()

            // whisper.cpp will auto-load "<model>-encoder.mlmodelc" when present.
            // If absent, it falls back to CPU/Accelerate (still fully offline).
            let coreMLEncoderPath = url.deletingPathExtension().path + "-encoder.mlmodelc"
            if FileManager.default.fileExists(atPath: coreMLEncoderPath) {
                Safety.log("Core ML encoder detected at \(coreMLEncoderPath)")
            } else {
                Safety.log("Core ML encoder not found; using CPU/Accelerate path")
            }

            // Now load the model
            Safety.log("Loading Whisper model from \(url.path) (\(modelSize / 1024 / 1024) MB)...")
            whisper = Whisper(fromFileURL: url, withParams: params)
            if whisper != nil {
                whisper?.delegate = self
                isModelLoaded = true
                Safety.log("Whisper model loaded successfully")
            } else {
                Safety.log("ERROR: Whisper(fromFileURL:) returned nil — model load failed")
                isModelLoaded = false
            }
        } catch {
            Safety.log("ERROR: Exception during model load: \(error)")
            isModelLoaded = false
        }
    }

    /// Returns a WhisperParams tuned for minimum latency on the tiny.en model.
    ///
    /// Key changes from defaults:
    /// - `greedy.best_of = 1`  — run the decoder exactly once (default: 2 passes). Single pass
    ///   halves CPU time for greedy decoding with no perceptible quality difference on short
    ///   dictation utterances.
    /// - `speed_up = true`     — enables the Phase Vocoder trick: audio context is halved by
    ///   merging pairs of frequency bins, so the transformer processes half as many frames.
    ///   Works well on tiny/base models; small accuracy trade-off.
    /// - `n_threads = min(4, activeProcessorCount)` — follows whisper.cpp's default thread cap;
    ///   this usually improves short-utterance latency vs over-threading tiny models.
    /// - `no_context = true`   — already default; confirmed off here to avoid ghost tokens.
    /// - `single_segment = true` — forces output into one segment, avoiding extra segmentation
    ///   overhead for short utterances.
    /// - `print_timestamps = false` and `token_timestamps = false` — skip timestamp work for
    ///   plain dictation text.
    /// - `temperature_inc = 0` — disables multi-pass fallback decoding (big win on hard/noisy
    ///   clips where retries can explode latency).
    /// - `max_tokens = 128` — caps runaway decoding on noise while keeping normal dictation
    ///   lengths intact.
    /// - `suppress_non_speech_tokens = true` — reduces non-speech hallucinations and wasted decode.
    private static func makeFastParams() -> WhisperParams {
        let params = WhisperParams(strategy: .greedy)
        // Single decode pass — biggest single speed win (~50% faster decoding).
        params.greedy.best_of = 1
        // Phase Vocoder speed-up: halves audio context frames (~30-40% faster encoding).
        params.speed_up = true
        // For tiny/base models, whisper.cpp's default cap of 4 threads is often lower latency.
        params.n_threads = Int32(max(1, min(4, ProcessInfo.processInfo.activeProcessorCount)))
        // Dictation does not need timestamps; keep timestamp features disabled.
        params.print_timestamps = false
        params.token_timestamps = false
        // Disable carry-over prompt/context between calls for independent short utterances.
        params.no_context = true
        // Avoid expensive retry passes when confidence thresholds fail.
        params.temperature_inc = 0.0
        // Prevent pathological long decodes on noisy input.
        params.max_tokens = 128
        // Helps suppress non-speech artifacts in dictation-style input.
        params.suppress_non_speech_tokens = true
        // Progress callback/UI is unused; disable extra progress work.
        params.print_progress = false
        // One segment for short utterances — avoids multi-segment tokenisation overhead.
        params.single_segment = true
        // Language already locked to English (model is tiny.en); set explicitly.
        params.language = .english
        Safety.log("WhisperParams: best_of=1 speed_up=true retries=off max_tokens=128 n_threads=\(params.n_threads) single_segment=true")
        return params
    }

    public func loadEmbeddedModel() {
        Safety.log("Looking for tiny.en.bin in resourceBundle: \(Safety.resourceBundle.bundlePath)")
        if let url = Safety.resourceBundle.url(forResource: "tiny.en", withExtension: "bin") {
            Safety.log("Found model at \(url.path)")
            loadModel(url: url)
        } else {
            Safety.log("ERROR: tiny.en.bin not found in bundle at \(Safety.resourceBundle.bundlePath)")
        }
    }
    
    public func transcribe(audioFrames: [Float]) {
        guard let whisper = whisper, isModelLoaded else {
            Safety.log("transcribe() skipped — whisper=\(self.whisper == nil ? "nil" : "ok") isModelLoaded=\(isModelLoaded)")
            return
        }
        // Cancel any in-flight transcription before starting a new one.
        // whisper.cpp is not thread-safe; concurrent calls cause undefined behaviour.
        transcriptionTask?.cancel()
        isTranscribing = true
        let startedAt = Date()
        transcriptionTask = Task {
            do {
                _ = try await whisper.transcribe(audioFrames: audioFrames)
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                Safety.log("Whisper transcribe completed in \(elapsedMs)ms")
            } catch {
                if !(error is CancellationError) {
                    Safety.log("ERROR: Whisper transcription failed: \(error)")
                }
            }
            self.isTranscribing = false
        }
    }

    /// Cancels any in-flight transcription task. Call before stopping recording.
    public func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
    }
}

extension WhisperService: WhisperDelegate {
    nonisolated public func whisper(_ whisper: Whisper, didUpdateProgress progress: Double) {
        // Optional: Update progress UI
    }
    
    nonisolated public func whisper(_ whisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {
        // Handle partial results if needed
    }
    
    nonisolated public func whisper(_ whisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        let text = segments.map { $0.text }.joined(separator: " ")
        Safety.log("Whisper output: [REDACTED — \(text.count) chars]")

        Task { @MainActor in
            self.ontranscriptionComplete?(text)
        }
    }

    nonisolated public func whisper(_ whisper: Whisper, didErrorWith error: Error) {
        Safety.log("ERROR: Whisper delegate error: \(error)")
    }
}
