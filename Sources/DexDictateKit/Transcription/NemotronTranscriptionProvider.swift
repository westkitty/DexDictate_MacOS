import Foundation
import AVFoundation
import FluidAudio

/// Real Nemotron 3.5 ASR Streaming (0.6B) provider, backed by FluidAudio's
/// `StreamingNemotronAsrManager` (native Swift/CoreML, Apple Neural Engine).
///
/// Like `AppleSpeechTranscriptionProvider`, this drives only the live partial preview
/// (`TranscriptionEngine.liveTranscript`) while the user is talking — Whisper remains the
/// sole authority for the committed/pasted transcript in this pass. It never opens its own
/// `AVAudioEngine`/tap; it consumes buffers already captured for Whisper via
/// `appendAudioBuffer(_:)`.
///
/// Model weights (~0.6B params, CoreML int8) are NOT bundled and are NOT downloaded
/// automatically — `healthCheck()` reports unavailable with a clear reason until
/// `downloadModelsIfNeeded()` has been explicitly triggered (e.g. from a "Download Nemotron"
/// UI action) and completed. This keeps the "no automatic network calls as a default path"
/// requirement intact for a multi-hundred-MB download.
@MainActor
public final class NemotronTranscriptionProvider: TranscriptionProvider, StreamingAudioReceiving {
    public let id: TranscriptionProviderID = .nemotron35ASRStreaming06B
    public let displayName = "Nemotron 3.5 ASR Streaming 0.6B"
    public let userFacingModeName = "Live Streaming"
    public let mode: TranscriptionMode = .liveStreaming
    public let locality: TranscriptionProviderLocality = .local

    public let supportsStreaming = true
    public let supportsPartialResults = true
    public let supportsPunctuation = true
    public let supportsCommands = false

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private let manager = StreamingNemotronAsrManager()
    public private(set) var isModelLoaded = false
    public private(set) var isDownloading = false
    public private(set) var lastDownloadError: String?
    public private(set) var isSessionActive = false
    /// Bumped on every start/stop so a partial callback queued on the actor from a session
    /// that has since ended (or been superseded by a new one) is detected and dropped instead
    /// of bleeding stale captions into the next utterance's live preview. Same idiom
    /// `WhisperService` uses (`transcriptionGeneration`) for the equivalent problem.
    private var sessionGeneration = 0
    /// The tail of a strict FIFO chain: `startTranscription()`'s `reset()`/
    /// `setPartialCallback()` setup is the first link, and every subsequent
    /// `appendAudioBuffer(_:)` call appends one more link that awaits this before doing its
    /// own actor work, then replaces it with its own task. See the root-cause comment on
    /// `appendAudioBuffer(_:)` for why this chain — not one independent `Task` per buffer —
    /// is required for correctness, not just style.
    private var pendingSessionTask: Task<Void, Never>?

    public init() {}

    public var modelInstallStatus: TranscriptionModelInstallStatus {
        if isModelLoaded { return .installed }
        return modelsExistOnDisk() ? .installed : .notInstalled
    }

    public func healthCheck() -> TranscriptionProviderHealth {
        guard SystemInfo.isAppleSilicon else {
            return .unavailable("Nemotron requires Apple Silicon (Neural Engine).")
        }
        if isModelLoaded {
            return .available()
        }
        if isDownloading {
            return .unavailable("Nemotron models are still downloading.")
        }
        if let lastDownloadError {
            return .unavailable("Nemotron model download failed: \(lastDownloadError)")
        }
        guard modelsExistOnDisk() else {
            return .unavailable("Nemotron models aren't downloaded yet. Download them from Live Transcription diagnostics.")
        }
        return .unavailable("Nemotron models are downloaded but not loaded yet.")
    }

    /// Duplicates `StreamingNemotronAsrManager.loadModels(to:)`'s default cache path — FluidAudio
    /// doesn't expose a public synchronous "are Nemotron models cached" helper (unlike Parakeet's
    /// `AsrModels.modelsExist(at:)`, which `ParakeetTranscriptionProvider` uses directly instead
    /// of duplicating its path logic). If FluidAudio ever changes this default layout, this check
    /// needs to be updated to match.
    private func modelsExistOnDisk() -> Bool {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cacheDir = base
            .appendingPathComponent("FluidAudio", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        let encoderPath = cacheDir
            .appendingPathComponent(NemotronChunkSize.ms2240.repo.folderName)
            .appendingPathComponent("encoder")
        return FileManager.default.fileExists(atPath: encoderPath.path)
    }

    /// Explicit, user-triggered model download + load. Never called automatically.
    public func downloadModelsIfNeeded() async {
        guard !isModelLoaded, !isDownloading else { return }
        isDownloading = true
        lastDownloadError = nil
        do {
            try await manager.loadModels()
            isModelLoaded = true
        } catch {
            lastDownloadError = error.localizedDescription
            Safety.log("Nemotron model download/load failed: \(error.localizedDescription)", category: .transcription)
        }
        isDownloading = false
    }

    public func startTranscription() throws {
        guard isModelLoaded else {
            throw TranscriptionProviderError.unavailable(healthCheck().reason ?? "Nemotron is unavailable.")
        }
        sessionGeneration &+= 1
        let myGeneration = sessionGeneration
        let manager = self.manager

        // Marking active synchronously (not after an async Task completes) means no real
        // microphone buffer is ever silently dropped just because it arrived before setup
        // finished — `AudioRecorderService`'s tap can fire within milliseconds of this call
        // returning. Correctness relative to `reset()`/`setPartialCallback()` is preserved by
        // chaining this setup work as the first link of `pendingSessionTask` (see
        // `appendAudioBuffer(_:)`), not by a timing assumption.
        isSessionActive = true
        pendingSessionTask = Task { [weak self] in
            await manager.reset()
            await manager.setPartialCallback { text in
                // `self` is @MainActor-isolated; FluidAudio's `NemotronPartialCallback` is
                // `@Sendable`, so this whole chain runs on the actor's own executor until the
                // MainActorDispatch.async hop below — the weak capture and generation check only
                // happen once actually back on the main actor. The compiler still emits a
                // "captured var in concurrently-executing code" warning here (it applies to the
                // enclosing @Sendable closure as a whole, not just the un-hopped portion); it's a
                // known false-positive-adjacent diagnostic for this shape, not a real race —
                // verified by inspection, not silenced.
                MainActorDispatch.async { [weak self] in
                    guard let self, self.sessionGeneration == myGeneration else { return }
                    self.onPartialResult?(text)
                }
            }
        }
    }

    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isSessionActive else { return }
        // `buffer` is only valid for the duration of AudioRecorderService's synchronous tap
        // callback (see the comment in `processAudioBuffer` — the audio engine can reuse/
        // overwrite the underlying sample memory for a later callback). Unlike Apple Speech's
        // append(_:), which is fully synchronous, `manager.appendAudio(_:)` is an actor call —
        // it's only guaranteed to actually run at some later point, by which time the original
        // buffer's contents could already be stale. Copy synchronously, on this same real-time
        // thread, before handing off to the async Task — matching how `processAudioBuffer`
        // itself always copies into a local array before doing anything async.
        guard let bufferCopy = Self.copyBuffer(buffer) else { return }
        let manager = self.manager
        let myGeneration = sessionGeneration

        // Root-cause fix (Nemotron reports "Ready" and accepts every buffer without error,
        // but zero partial — or final — text is ever decoded): each call used to spawn its
        // OWN independent `Task`, so a real utterance's ~90+ tap buffers all raced each other
        // into `manager`'s actor mailbox with no ordering guarantee relative to one another.
        // RNNT streaming decode carries encoder/decoder cache state (`cacheChannel`,
        // `hState`/`cState`, `melCache`, `lastToken`) forward chunk-to-chunk — if
        // `appendAudio`/`processBufferedAudio` calls for different buffers interleave out of
        // recording order, the model decodes a temporally scrambled mel-spectrogram sequence
        // and greedily predicts blank for every frame: no error, no crash, just silent
        // 100%-blank output, which is exactly what was observed.
        //
        // Verified empirically: driving the SAME `StreamingNemotronAsrManager` directly
        // (bypassing this class) with the exact same ~4096-frame buffers but serialized —
        // each call awaited in order — reproduced FluidAudio's own correct reference
        // transcript; the identical buffers fed through this class's old one-Task-per-buffer
        // code produced empty output every time (see `NemotronDirectManagerDiagnosticTests`
        // and `NemotronRealAudioPartialPipelineTests`).
        //
        // Chaining each buffer's work onto `pendingSessionTask` — awaiting the previous link
        // before doing this buffer's own `appendAudio`/`processBufferedAudio` — guarantees
        // buffers are appended and processed in strict arrival order, with no buffer's work
        // starting before the previous one's has fully finished, while still returning
        // immediately to the real-time audio thread (this method itself never awaits).
        let previous = pendingSessionTask
        pendingSessionTask = Task { [weak self] in
            await previous?.value
            guard let self, self.sessionGeneration == myGeneration else { return }
            do {
                try await manager.appendAudio(bufferCopy)
                try await manager.processBufferedAudio()
            } catch {
                // Same staleness check as the partial-result callback above — without it, an
                // error from a superseded session's buffered-audio processing could still
                // surface via onError after a new session has already started.
                MainActorDispatch.async { [weak self] in
                    guard let self, self.sessionGeneration == myGeneration else { return }
                    self.onError?(error)
                }
            }
        }
    }

    public func stopTranscription() {
        // Bump the generation unconditionally — any in-flight `appendAudioBuffer` Task still
        // chained on `pendingSessionTask` (or a partial callback already queued on the actor)
        // for this session must see a stale generation and bail out once it resumes.
        sessionGeneration &+= 1
        guard isSessionActive else { return }
        isSessionActive = false
        let manager = self.manager
        // Chain finish() after whatever's still pending, same as every buffer append does —
        // otherwise a trailing in-flight appendAudio/processBufferedAudio call could still be
        // running when finish() pads and processes the remainder, reintroducing the same
        // out-of-order-actor-access defect appendAudioBuffer(_:) just fixed.
        let previous = pendingSessionTask
        pendingSessionTask = nil
        Task {
            await previous?.value
            _ = try? await manager.finish()
        }
    }

    /// Deep-copies a tap buffer's sample data into an independently-owned `AVAudioPCMBuffer`,
    /// safe to read after the originating callback returns. Called synchronously on the
    /// real-time audio thread — cheap (a bounded memcpy of one tap buffer's worth of samples,
    /// same cost class as the `[Float]` copy `AudioRecorderService.processAudioBuffer` already
    /// does on this same thread for Whisper).
    private static func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return copy }

        if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                dst[channel].update(from: src[channel], count: frameCount)
            }
        } else if let src = buffer.int16ChannelData, let dst = copy.int16ChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                dst[channel].update(from: src[channel], count: frameCount)
            }
        }
        return copy
    }
}
