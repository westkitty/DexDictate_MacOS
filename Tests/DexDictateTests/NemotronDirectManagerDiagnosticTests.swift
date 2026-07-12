import XCTest
import AVFoundation
import FluidAudio
@testable import DexDictateKit

/// Permanent regression guard, kept from the investigation that found the "Nemotron Ready
/// but zero partials" root cause: bypasses `NemotronTranscriptionProvider` entirely and
/// drives FluidAudio's `StreamingNemotronAsrManager` directly, using the exact same
/// one-shot `process(audioBuffer:)` + `finish()` call shape FluidAudio's own
/// `NemotronTranscribe` CLI command uses (a known-working reference path, since it's the
/// tool the framework's own README/CLI ships for verifying a model install). These two
/// tests are what isolated the defect to `NemotronTranscriptionProvider`'s own
/// one-Task-per-buffer concurrency bug (fixed by the `pendingSessionTask` FIFO chain) rather
/// than FluidAudio's model/pipeline itself — keeping them pins that isolation permanently:
/// if a future change to either FluidAudio's usage or the model cache ever breaks the
/// *underlying* manager, these fail independently of `NemotronTranscriptionProvider`.
@MainActor
final class NemotronDirectManagerDiagnosticTests: XCTestCase {

    private func cacheDir() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FluidAudio", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("nemotron-streaming/2240ms", isDirectory: true)
    }

    func testDirectManagerOneShotProcessOnRealAudio() async throws {
        let dir = cacheDir()
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("encoder").path),
            "No Nemotron model cached on this machine."
        )

        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sampleURL = projectRoot.appendingPathComponent("sample_corpus/sample.wav")
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            throw XCTSkip("sample_corpus/sample.wav not found at \(sampleURL.path)")
        }

        let manager = StreamingNemotronAsrManager()
        try await manager.loadModels(from: dir)

        // Exact shape used by FluidAudioCLI's NemotronTranscribe.run(): read the whole file
        // into ONE buffer at its own processingFormat, feed it in one process() call, then
        // finish(). This is the framework's own reference/known-good call pattern.
        let audioFile = try AVAudioFile(forReading: sampleURL)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw XCTSkip("Failed to create audio buffer")
        }
        try audioFile.read(into: buffer)

        _ = try await manager.process(audioBuffer: buffer)
        let transcript = try await manager.finish()

        print("DIAG direct-manager one-shot transcript: '\(transcript)'")
        XCTAssertFalse(
            transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "FluidAudio's own reference call pattern (process()+finish() in one shot) produced an empty transcript for real speech audio — points to a model/audio issue, not DexDictate's chunked-append plumbing."
        )
    }

    /// Isolates whether the defect is specifically in repeatedly calling
    /// `appendAudio(_:)` + `processBufferedAudio()` with MANY SMALL buffers (exactly what
    /// `NemotronTranscriptionProvider.appendAudioBuffer` does per real-time tap callback),
    /// as opposed to `NemotronTranscriptionProvider`'s own wrapper logic (session-activation
    /// guard, generation checks, etc. — already fixed above). Same manager, same audio,
    /// same small-buffer chunking as the real pipeline — but calling FluidAudio's actor
    /// directly, with none of DexDictate's own code in between.
    func testDirectManagerChunkedAppendMatchingRealTapBufferSize() async throws {
        let dir = cacheDir()
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("encoder").path),
            "No Nemotron model cached on this machine."
        )

        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sampleURL = projectRoot.appendingPathComponent("sample_corpus/sample.wav")
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            throw XCTSkip("sample_corpus/sample.wav not found at \(sampleURL.path)")
        }

        let manager = StreamingNemotronAsrManager()
        try await manager.loadModels(from: dir)
        await manager.reset()

        let file = try AVAudioFile(forReading: sampleURL)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false
        ) else {
            throw XCTSkip("Could not construct format")
        }
        let frameCount = AVAudioFrameCount(file.length)
        guard let fullBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw XCTSkip("Could not allocate buffer")
        }
        fullBuffer.frameLength = frameCount
        try file.read(into: fullBuffer)
        guard let src = fullBuffer.floatChannelData?[0] else {
            throw XCTSkip("No float channel data")
        }

        let bufferSize: AVAudioFrameCount = 4096
        var offset: AVAudioFrameCount = 0
        var chunkCount = 0
        while offset < frameCount {
            let thisLength = min(bufferSize, frameCount - offset)
            guard let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisLength) else { break }
            chunk.frameLength = thisLength
            if let dst = chunk.floatChannelData?[0] {
                dst.update(from: src.advanced(by: Int(offset)), count: Int(thisLength))
            }
            try await manager.appendAudio(chunk)
            try await manager.processBufferedAudio()
            chunkCount += 1
            offset += thisLength
        }

        let partialBeforeFinish = await manager.getPartialTranscript()
        let final = try await manager.finish()
        print("DIAG chunked-append (\(chunkCount) buffers of \(bufferSize) frames) partial='\(partialBeforeFinish)' final='\(final)'")

        XCTAssertFalse(
            (partialBeforeFinish + final).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Feeding the SAME manager the SAME audio via repeated small appendAudio()+processBufferedAudio() calls (matching real tap buffer size) produced no text, while the one-shot process()+finish() call on the same audio succeeded — isolates the defect to the chunked-append path itself, not to NemotronTranscriptionProvider's own wrapper logic."
        )
    }
}
