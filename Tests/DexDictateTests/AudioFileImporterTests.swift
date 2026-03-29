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
}
