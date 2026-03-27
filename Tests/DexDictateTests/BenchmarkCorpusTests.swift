import XCTest
@testable import DexDictateKit

final class BenchmarkCorpusTests: XCTestCase {
    func testStrictCorpusHasExpectedShape() {
        let prompts = BenchmarkCorpus.strictPrompts
        XCTAssertEqual(prompts.count, 30)
        XCTAssertEqual(Set(prompts.map(\.fileName)).count, prompts.count)
        XCTAssertEqual(Set(prompts.map(\.id)).count, prompts.count)
        XCTAssertTrue(prompts.contains(where: { $0.id == "A1" && $0.referenceText == "DexDictate should transcribe this sentence exactly once." }))
        XCTAssertTrue(prompts.contains(where: { $0.id == "N1A1" && $0.referenceText == "DexDictate should transcribe this sentence exactly once." }))
        XCTAssertFalse(prompts.contains(where: { ($0.instructionText ?? "").localizedCaseInsensitiveContains("fan") }))
        XCTAssertFalse(prompts.contains(where: { ($0.instructionText ?? "").localizedCaseInsensitiveContains("keyboard") }))
    }

    func testTranscriptMapMatchesCorpusCount() {
        let map = BenchmarkCorpus.strictTranscriptMap
        XCTAssertEqual(map.count, BenchmarkCorpus.strictPrompts.count)
        XCTAssertEqual(map["A1.wav"], "DexDictate should transcribe this sentence exactly once.")
        XCTAssertEqual(map["C3.wav"], "scratch that")
    }
}
