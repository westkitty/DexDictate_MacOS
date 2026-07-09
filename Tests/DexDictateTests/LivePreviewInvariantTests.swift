import XCTest
import AVFoundation
@testable import DexDictateKit

/// Permanent regression guard for Packet 14's core promise: `LivePreviewController`'s mere
/// existence and subscription to the engine cannot change the committed (batch Whisper)
/// transcript for the same audio buffer. Uses the exact same load → resample → transcribe
/// technique `VerificationRunner.runBenchmark` already uses in production — no new test
/// seam was added to any forbidden file; this only calls already-public APIs
/// (`WhisperService.loadModel`/`.transcribe`, `AudioResampler.resampleToWhisper`).
///
/// This stays even if Live Preview itself is ever reverted (per this packet's own rollback
/// note) — it is a permanent guard on the two-channel architecture, not a feature test.
@MainActor
final class LivePreviewInvariantTests: XCTestCase {

    private func loadSampleWhisperFrames() throws -> [Float] {
        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sampleURL = projectRoot.appendingPathComponent("sample_corpus/sample.wav")
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            throw XCTSkip("sample_corpus/sample.wav not found at \(sampleURL.path)")
        }
        let file = try AVAudioFile(forReading: sampleURL)
        let frameCount = AVAudioFrameCount(file.length)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw XCTSkip("Could not allocate PCM buffer for sample.wav")
        }
        buffer.frameLength = frameCount
        try file.read(into: buffer)
        guard let floatData = buffer.floatChannelData?[0] else {
            throw XCTSkip("No float channel data in sample.wav")
        }
        let nativeSamples = Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
        return AudioResampler.resampleToWhisper(nativeSamples, fromRate: file.fileFormat.sampleRate)
    }

    private func loadedTinyModelWhisperService() async throws -> WhisperService {
        guard let modelURL = Safety.resourceBundle.url(forResource: "tiny.en", withExtension: "bin") else {
            throw XCTSkip("Embedded tiny.en model not found — cannot run the invariant test in this environment.")
        }
        let service = WhisperService()
        service.loadModel(url: modelURL)
        guard service.isModelLoaded else {
            throw XCTSkip("tiny.en model failed to load in this environment.")
        }
        // Must wait for the model's own internal silent warm-up inference to finish before
        // issuing a real transcribe() call — matches VerificationRunner.runBenchmark's own
        // established pattern. Skipping this races the warm-up's completion against the
        // real call's continuation (observed: a double-resume crash in this test's first draft).
        guard await service.waitUntilIdle() else {
            throw XCTSkip("Whisper warm-up did not finish before test timeout.")
        }
        return service
    }

    private func transcribe(_ service: WhisperService, frames: [Float]) async -> String {
        await withCheckedContinuation { continuation in
            service.ontranscriptionComplete = { text in
                continuation.resume(returning: text)
            }
            _ = service.transcribe(audioFrames: frames)
        }
    }

    /// The core invariant: attaching a live, subscribed `LivePreviewController` to a real
    /// `TranscriptionEngine` instance — the same one whose `.liveTranscript`/`.inputLevel`
    /// it observes — produces byte-identical WhisperService output for the same audio
    /// buffer as running with no `LivePreviewController` involved at all. The controller
    /// has no call path into `WhisperService`/`OutputCoordinator` whatsoever; this proves
    /// that by construction, via the real production classes, not a mock.
    func testCommittedTranscriptIsByteIdenticalWithPreviewControllerAttachedOrNot() async throws {
        let frames = try loadSampleWhisperFrames()

        // Run A: no LivePreviewController exists at all.
        let serviceA = try await loadedTinyModelWhisperService()
        let resultA = await transcribe(serviceA, frames: frames)

        // Run B: a real LivePreviewController is attached to a real TranscriptionEngine and
        // actively subscribed (simulating "preview enabled" + a live session), running
        // concurrently with the transcription call.
        let engine = TranscriptionEngine()
        let previewController = LivePreviewController(settings: AppSettings.shared)
        previewController.start(engine: engine)
        engine.state = .listening
        engine.liveTranscript = "some provisional caption the preview channel is showing"
        engine.inputLevel = 0.42

        let serviceB = try await loadedTinyModelWhisperService()
        let resultB = await transcribe(serviceB, frames: frames)

        XCTAssertEqual(resultA, resultB, "LivePreviewController's presence/subscription must never change the committed transcript")
        XCTAssertFalse(resultA.isEmpty, "sanity check — the sample audio should produce non-empty text")

        // Preview controller must still be attached and unkilled — proves it didn't crash
        // or interfere with the concurrent transcription.
        XCTAssertFalse(previewController.isKilledForSession)
    }

    /// Toggle OFF (default): the controller must not touch `caption`/`micLevel` at all,
    /// even if the engine transitions through `.listening` — confirming zero preview
    /// activity when the Settings toggle is off, matching the acceptance criterion.
    func testPreviewStaysInertWhenSettingIsOff() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = false
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        engine.liveTranscript = "should never appear"
        engine.inputLevel = 0.9

        XCTAssertEqual(controller.caption, "")
        XCTAssertEqual(controller.micLevel, 0)
    }
}
