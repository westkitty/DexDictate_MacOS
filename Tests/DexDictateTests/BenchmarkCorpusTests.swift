import XCTest
@testable import DexDictateKit

final class BenchmarkCorpusTests: XCTestCase {
    func testStrictCorpusHasExpectedShape() {
        let prompts = BenchmarkCorpus.strictPrompts
        XCTAssertEqual(prompts.count, 30)
        XCTAssertEqual(Set(prompts.map(\.fileName)).count, prompts.count)
        XCTAssertEqual(Set(prompts.map(\.id)).count, prompts.count)
        XCTAssertTrue(prompts.contains(where: { $0.id == "A1" && $0.referenceText == "DexDictate should transcribe this sentence exactly once." }))
        XCTAssertTrue(prompts.contains(where: { $0.id == "N2A1" && $0.referenceText == "Anchor one DexDictate should get this right the first time." }))
        XCTAssertFalse(prompts.contains(where: { ($0.instructionText ?? "").localizedCaseInsensitiveContains("fan") }))
        XCTAssertFalse(prompts.contains(where: { ($0.instructionText ?? "").localizedCaseInsensitiveContains("keyboard") }))
        XCTAssertFalse(prompts.contains(where: { $0.referenceText.localizedCaseInsensitiveContains("WestKitty") }))
    }

    func testTranscriptMapMatchesCorpusCount() {
        let map = BenchmarkCorpus.strictTranscriptMap
        XCTAssertEqual(map.count, BenchmarkCorpus.strictPrompts.count)
        XCTAssertEqual(map["A1.wav"], "DexDictate should transcribe this sentence exactly once.")
        XCTAssertEqual(map["C3.wav"], "scratch that")
        XCTAssertEqual(map["D3.wav"], "Dexter DexGPT DexDictate")
        XCTAssertEqual(map["N2A5.wav"], "Anchor five accuracy is the minimum, not an achievement.")
    }
}
