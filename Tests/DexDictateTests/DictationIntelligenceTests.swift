import XCTest
@testable import DexDictateKit

final class DictationIntelligenceTests: XCTestCase {
    func testAutomaticDomainBiasMapsCodingApps() {
        let domain = DictationDomainBias.resolvedDomain(
            mode: .automatic,
            bundleIdentifier: "com.apple.dt.Xcode"
        )

        XCTAssertEqual(domain, .coding)
    }

    func testAutomaticDomainBiasMapsChatApps() {
        let domain = DictationDomainBias.resolvedDomain(
            mode: .automatic,
            bundleIdentifier: "us.zoom.xos"
        )

        XCTAssertEqual(domain, .chat)
    }

    func testAdaptiveTailDelayIncreasesForLongLooseUtterances() {
        let delay = AdaptiveTailDelayHeuristic.resolvedDelayMs(
            baseDelayMs: 250,
            recordingDurationMs: 5_000,
            recentOutputs: ["need to keep going", "still not done", "one more clause"]
        )

        XCTAssertGreaterThan(delay, 250)
    }

    func testAdaptiveTailDelayShrinksForShortCleanUtterances() {
        let delay = AdaptiveTailDelayHeuristic.resolvedDelayMs(
            baseDelayMs: 250,
            recordingDurationMs: 900,
            recentOutputs: ["Done.", "Looks good!", "Ship it."]
        )

        XCTAssertLessThan(delay, 250)
    }

    func testSuspiciousTranscriptionHeuristicFlagsSingleWordLongUtterance() {
        let reason = SuspiciousTranscriptionHeuristic.reason(
            for: "hello",
            audioDurationSeconds: 2.8
        )

        XCTAssertEqual(reason, "single-word-for-long-utterance")
    }

    func testCodingVocabularyBiasAddsExpectedReplacements() {
        let manager = VocabularyManager()
        let text = manager.applyEffective(
            to: "swift ui in x code talks to git hub over api",
            additionalItems: DictationDomainBias.vocabularyItems(for: .coding)
        )

        XCTAssertEqual(text, "SwiftUI in Xcode talks to GitHub over API")
    }
}
