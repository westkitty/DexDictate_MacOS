import XCTest
import AVFoundation
@testable import DexDictateKit

/// Empirical proof (not code-reading speculation) of whether the real, cached Nemotron
/// model — loaded exactly the way `TranscriptionEngine` loads it — actually emits partial
/// transcripts when fed real audio through the exact same `startTranscription()` →
/// `onPartialResult` assignment → `appendAudioBuffer(_:)` call sequence
/// `TranscriptionEngine.startLiveProviderSessionIfNeeded()` uses in production.
///
/// Feeds `sample_corpus/sample.wav` (real speech, 48kHz mono, ~8s — long enough to span
/// several of Nemotron's 2240ms chunks) as a sequence of ~4096-frame `AVAudioPCMBuffer`s at
/// the file's native 48kHz rate, matching `AudioRecorderService`'s real tap buffer size
/// (`installTap(..., bufferSize: 4096, ...)`) and its `format: nil` behavior (native
/// hardware rate, not pre-resampled to 16kHz — that conversion is Nemotron's own
/// responsibility via `AudioConverter`, exercised for real here, not mocked).
@MainActor
final class NemotronRealAudioPartialPipelineTests: XCTestCase {

    private func realSampleBuffers(bufferSize: AVAudioFrameCount = 4096) throws -> [AVAudioPCMBuffer] {
        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sampleURL = projectRoot.appendingPathComponent("sample_corpus/sample.wav")
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            throw XCTSkip("sample_corpus/sample.wav not found at \(sampleURL.path)")
        }
        let file = try AVAudioFile(forReading: sampleURL)
        // Native rate, mono, Float32 non-interleaved — same shape AVAudioEngine's tap
        // delivers with `format: nil` (hardware format passthrough), not a pre-resampled
        // 16kHz buffer. This is the same "derive the real format" approach
        // `LivePreviewInvariantTests.loadSampleWhisperFrames()` already uses.
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false
        ) else {
            throw XCTSkip("Could not construct a Float32 mono format for sample.wav's native rate.")
        }
        let frameCount = AVAudioFrameCount(file.length)
        guard let fullBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw XCTSkip("Could not allocate PCM buffer for sample.wav")
        }
        fullBuffer.frameLength = frameCount
        try file.read(into: fullBuffer)
        guard let src = fullBuffer.floatChannelData?[0] else {
            throw XCTSkip("No float channel data in sample.wav")
        }

        var chunks: [AVAudioPCMBuffer] = []
        var offset: AVAudioFrameCount = 0
        while offset < frameCount {
            let thisChunkLength = min(bufferSize, frameCount - offset)
            guard let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisChunkLength) else { break }
            chunk.frameLength = thisChunkLength
            if let dst = chunk.floatChannelData?[0] {
                dst.update(from: src.advanced(by: Int(offset)), count: Int(thisChunkLength))
            }
            chunks.append(chunk)
            offset += thisChunkLength
        }
        return chunks
    }

    /// THE core empirical proof this task demands: real model, real (not faked) audio,
    /// production call ordering, and a direct wait-for-partial with a generous timeout
    /// (CoreML/ANE inference per chunk is compute-heavy, especially cold).
    func testRealNemotronProviderEmitsPartialTranscriptForRealAudio() async throws {
        let provider = NemotronTranscriptionProvider()
        try XCTSkipUnless(
            provider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — cannot exercise the real pipeline."
        )
        await provider.downloadModelsIfNeeded()
        try XCTSkipUnless(
            provider.healthCheck().isAvailable,
            "Nemotron model did not become available in this environment."
        )

        let buffers = try realSampleBuffers()
        try XCTSkipIf(buffers.isEmpty, "sample.wav produced no buffers to feed.")

        final class Box: @unchecked Sendable {
            var partials: [String] = []
            var errors: [String] = []
        }
        let box = Box()

        // Exact production ordering from `TranscriptionEngine.startLiveProviderSessionIfNeeded()`:
        // startTranscription() first, THEN assign onPartialResult/onError, THEN feed audio —
        // with NO artificial delay in between. `isSessionActive` must already be true the
        // instant `startTranscription()` returns (the fix for the reported defect); this test
        // deliberately does not wait for it, since waiting would mask a regression back to the
        // old async-flip behavior where every buffer fed this immediately after start would be
        // silently dropped.
        try provider.startTranscription()
        provider.onPartialResult = { text in box.partials.append(text) }
        provider.onError = { error in box.errors.append(error.localizedDescription) }
        XCTAssertTrue(provider.isSessionActive, "isSessionActive must be true synchronously once startTranscription() returns — no window where real audio buffers get silently dropped")

        for buffer in buffers {
            provider.appendAudioBuffer(buffer)
        }

        // Poll rather than a fixed sleep — CoreML first-run compilation/inference latency
        // is highly variable. 30s ceiling comfortably covers ~8s of real audio at real ANE
        // inference speed (RTFx >> 1x per FluidAudio's own performance requirements).
        let deadline = Date().addingTimeInterval(30)
        while box.partials.isEmpty && box.errors.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        provider.stopTranscription()

        if !box.errors.isEmpty {
            XCTFail("Nemotron reported error(s) instead of partial results: \(box.errors)")
        }
        XCTAssertFalse(
            box.partials.isEmpty,
            "Real Nemotron model + real audio produced zero partial callbacks within 30s — this is the reported defect."
        )
        // Not just "non-empty" — must contain real recognized words from the known sample
        // content ("This is a longer, much more relaxed test..."), guarding against a
        // regression that reintroduces out-of-order actor access (garbled/wrong text) while
        // still technically firing a non-empty callback. Checks the FIRST partial (one
        // 2240ms chunk's worth) rather than assuming the poll loop waited for the whole
        // utterance — it exits as soon as any partial arrives.
        let firstPartial = box.partials.first ?? ""
        XCTAssertTrue(
            firstPartial.localizedCaseInsensitiveContains("longer") || firstPartial.localizedCaseInsensitiveContains("relaxed"),
            "Expected recognizable words from sample.wav's known content ('This is a longer, much more relaxed...'), got: '\(firstPartial)'"
        )
    }

    /// A session that is stopped and immediately restarted (e.g. two quick dictations back
    /// to back) must not leave the FIFO task chain (`pendingSessionTask`) wedged in a state
    /// that silently drops the second session's audio — a plausible regression shape for the
    /// fix above, since `stopTranscription()` now also chains `finish()` onto that same
    /// property. Real model, real audio, twice in a row.
    func testSecondSessionAfterStopAlsoProducesPartials() async throws {
        let provider = NemotronTranscriptionProvider()
        try XCTSkipUnless(
            provider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — cannot exercise the real pipeline."
        )
        await provider.downloadModelsIfNeeded()
        try XCTSkipUnless(provider.healthCheck().isAvailable, "Nemotron model did not become available in this environment.")

        let buffers = try realSampleBuffers()
        try XCTSkipIf(buffers.isEmpty, "sample.wav produced no buffers to feed.")

        final class Box: @unchecked Sendable { var partials: [String] = [] }

        func runOneSession() async throws -> Box {
            let box = Box()
            try provider.startTranscription()
            provider.onPartialResult = { text in box.partials.append(text) }
            for buffer in buffers { provider.appendAudioBuffer(buffer) }
            let deadline = Date().addingTimeInterval(30)
            while box.partials.isEmpty && Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            provider.stopTranscription()
            return box
        }

        let firstSession = try await runOneSession()
        XCTAssertFalse(firstSession.partials.isEmpty, "First session produced no partials.")

        let secondSession = try await runOneSession()
        XCTAssertFalse(
            secondSession.partials.isEmpty,
            "Second session (after a stop+restart) produced no partials — the FIFO chain may be wedged from the first session."
        )
    }

    /// `startTranscription()` must throw (and never fake a session) when the model isn't
    /// loaded — the "no error, no partials, just silence" failure mode this whole
    /// investigation was about must never be reintroduced for the model-not-loaded case.
    func testStartTranscriptionThrowsHonestlyWhenModelNotLoaded() {
        let provider = NemotronTranscriptionProvider()
        // Fresh instance — downloadModelsIfNeeded() was never called, so isModelLoaded is
        // false regardless of what's cached on disk.
        XCTAssertThrowsError(try provider.startTranscription())
        XCTAssertFalse(provider.isSessionActive, "must not report a session as active when startTranscription() threw")
    }

    /// A zero-frame buffer (degenerate input) must not crash or spuriously fire a partial —
    /// `Self.copyBuffer` and the FIFO chain must handle it as a safe no-op-ish pass-through.
    func testZeroFrameBufferDoesNotCrashOrProducePartial() async throws {
        let provider = NemotronTranscriptionProvider()
        try XCTSkipUnless(provider.modelInstallStatus == .installed, "No Nemotron model cached on this machine.")
        await provider.downloadModelsIfNeeded()
        try XCTSkipUnless(provider.healthCheck().isAvailable, "Nemotron model did not become available.")

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false),
              let emptyBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0) else {
            throw XCTSkip("Could not construct a zero-frame buffer.")
        }
        emptyBuffer.frameLength = 0

        final class Box: @unchecked Sendable { var partials = 0 }
        let box = Box()

        try provider.startTranscription()
        provider.onPartialResult = { _ in box.partials += 1 }
        provider.appendAudioBuffer(emptyBuffer)

        // Give any spawned Task a moment to run; reaching this line without a crash/hang is
        // itself part of the assertion.
        try await Task.sleep(nanoseconds: 200_000_000)
        provider.stopTranscription()

        XCTAssertEqual(box.partials, 0, "a zero-frame buffer must never itself trigger a partial callback")
    }
}
