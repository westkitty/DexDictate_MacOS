import XCTest
@testable import DexDictateKit

final class AudioFileImporterTests: XCTestCase {
    func testBundledSampleAudioLoadsIntoPCM() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("Sources/DexDictateKit/Resources/BundledBenchmarkCorpus/sample.wav")

        let result = try AudioFileImporter.loadSamples(from: url)

        XCTAssertFalse(result.samples.isEmpty)
        XCTAssertGreaterThan(result.sampleRate, 0)
    }

    func testDownmixToMonoAveragesStereoChannels() {
        let samples = AudioFileImporter.downmixToMono(channelCount: 2, frameLength: 4) { channel, _ in
            channel == 0 ? 1 : -1
        }

        XCTAssertEqual(samples.count, 4)
        XCTAssertTrue(samples.allSatisfy { abs($0) < 0.0001 })
    }
}
