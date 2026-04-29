import XCTest
@testable import DexDictateKit

final class TranscriptionQualityMetricsTests: XCTestCase {
    func testPunctuationMetricsTrackTerminalQuestionCommaAndDualWerModes() {
        let pairs = [
            TranscriptionQualityPair(
                reference: "Hello, world?",
                hypothesis: "Hello world."
            )
        ]

        let metrics = TranscriptionQualityMetrics.punctuationMetrics(for: pairs)

        XCTAssertEqual(metrics.terminalPunctuationExpected, 1)
        XCTAssertEqual(metrics.terminalPunctuationMatches, 0)
        XCTAssertEqual(metrics.questionMarkExpected, 1)
        XCTAssertEqual(metrics.questionMarkMatches, 0)
        XCTAssertEqual(metrics.commaExpected, 1)
        XCTAssertEqual(metrics.commaMatches, 0)
        XCTAssertGreaterThanOrEqual(metrics.punctuationAwareWER, metrics.punctuationStrippedWER)
    }

    func testCommandRecognitionMetricsCaptureBuiltInAndCustomDexErrors() {
        let commands = [CustomCommand(keyword: "comma", insertText: ",")]
        let pairs = [
            TranscriptionQualityPair(reference: "scratch that", hypothesis: "scratch that please"),
            TranscriptionQualityPair(reference: "normal text", hypothesis: "scratch that"),
            TranscriptionQualityPair(reference: "Dex comma", hypothesis: "Dex unknown"),
            TranscriptionQualityPair(reference: "hello world", hypothesis: "Dex comma"),
            TranscriptionQualityPair(reference: "scratch that", hypothesis: "scratch that"),
        ]

        let metrics = TranscriptionQualityMetrics.commandRecognitionMetrics(
            for: pairs,
            customCommands: commands
        )

        XCTAssertEqual(metrics.builtInFalseNegatives, 1)
        XCTAssertEqual(metrics.builtInFalsePositives, 1)
        XCTAssertEqual(metrics.customDexFalseNegatives, 1)
        XCTAssertEqual(metrics.customDexFalsePositives, 1)
        XCTAssertGreaterThanOrEqual(metrics.commandOnlyExpectedCount, 2)
        XCTAssertGreaterThanOrEqual(metrics.commandOnlyPreservedCount, 1)
    }

    func testClippingProxyMetricsDetectEmptyMissingWordsAndTruncationSignals() {
        let pairs = [
            TranscriptionQualityPair(reference: "hello brave world", hypothesis: "wor"),
            TranscriptionQualityPair(reference: "keep this text", hypothesis: ""),
        ]

        let metrics = TranscriptionQualityMetrics.clippingProxyMetrics(for: pairs)

        XCTAssertEqual(metrics.expectedNonEmptyCount, 2)
        XCTAssertEqual(metrics.emptyWhenExpectedCount, 1)
        XCTAssertEqual(metrics.missingFirstWordCount, 1)
        XCTAssertEqual(metrics.missingLastWordCount, 1)
        XCTAssertEqual(metrics.suspiciouslyShortCount, 1)
        XCTAssertEqual(metrics.finalWordTruncationProxyCount, 1)
    }

    func testRetrySelectionEvaluationAndAggregateMetricsCoverKeyCases() {
        let commands = [CustomCommand(keyword: "comma", insertText: ",")]
        let evaluations = [
            TranscriptionQualityMetrics.evaluateRetrySelection(
                original: "usable original",
                retry: "",
                audioDurationSeconds: 2.5,
                customCommands: commands
            ),
            TranscriptionQualityMetrics.evaluateRetrySelection(
                original: "",
                retry: "usable retry",
                audioDurationSeconds: 2.5,
                customCommands: commands
            ),
            TranscriptionQualityMetrics.evaluateRetrySelection(
                original: "scratch that",
                retry: "scratch that please",
                audioDurationSeconds: 2.5,
                customCommands: commands
            ),
            TranscriptionQualityMetrics.evaluateRetrySelection(
                original: "Dex unknown",
                retry: "Dex comma",
                audioDurationSeconds: 2.5,
                customCommands: commands
            ),
            TranscriptionQualityMetrics.evaluateRetrySelection(
                original: "alpha alpha alpha alpha",
                retry: "alpha beta gamma delta",
                audioDurationSeconds: 3.5,
                customCommands: commands
            ),
        ]

        XCTAssertEqual(evaluations[0].winner, .original)
        XCTAssertEqual(evaluations[0].reason, "retry-empty-original-usable")
        XCTAssertEqual(evaluations[1].winner, .retry)
        XCTAssertEqual(evaluations[1].reason, "original-empty-retry-usable")
        XCTAssertEqual(evaluations[2].winner, .original)
        XCTAssertEqual(evaluations[2].reason, "command-preserved-by-original")
        XCTAssertEqual(evaluations[3].winner, .retry)
        XCTAssertEqual(evaluations[3].reason, "command-recovered-by-retry")
        XCTAssertEqual(evaluations[4].winner, .retry)
        XCTAssertEqual(evaluations[4].reason, "original-suspicious-retry-clean")

        let metrics = TranscriptionQualityMetrics.retryQualityMetrics(evaluations)
        XCTAssertEqual(metrics.retryEmptyOriginalUsableCount, 1)
        XCTAssertEqual(metrics.originalEmptyRetryUsableCount, 1)
        XCTAssertEqual(metrics.commandPreservedByOriginalCount, 1)
        XCTAssertEqual(metrics.commandRecoveredByRetryCount, 1)
        XCTAssertEqual(metrics.repeatedTokenHallucinationCount, 1)
        XCTAssertGreaterThanOrEqual(metrics.suspiciousTextCaseCount, 1)
    }

    func testVocabularyAccuracyMetricsTrackCategoriesAndOverallRate() {
        let reference = "DexDictate uses API and Core ML with Kubernetes and ANE."
        let hypothesis = "DexDictate uses API with Kubernetes."
        let tracked = [
            VocabularyTerm(phrase: "DexDictate", category: .domainVocabulary),
            VocabularyTerm(phrase: "API", category: .frameworkAPI),
            VocabularyTerm(phrase: "Core ML", category: .frameworkAPI),
            VocabularyTerm(phrase: "Kubernetes", category: .properNoun),
            VocabularyTerm(phrase: "ANE", category: .acronym),
        ]

        let metrics = TranscriptionQualityMetrics.vocabularyAccuracyMetrics(
            reference: reference,
            hypothesis: hypothesis,
            trackedTerms: tracked
        )

        XCTAssertEqual(metrics.overallExpected, 5)
        XCTAssertEqual(metrics.overallMatched, 3)
        XCTAssertEqual(metrics.overallAccuracy, 0.6)
        XCTAssertEqual(metrics.perCategory[.frameworkAPI], VocabularyCategoryScore(expected: 2, matched: 1))
    }

    func testLatencyMetricsReportSupportsOptionalDimensionsWithoutChangingLegacyLatency() {
        let transcriptionOnlyReport = TranscriptionQualityMetrics.latencyMetricsReport([
            LatencyObservation(transcriptionOnlyMs: 90),
            LatencyObservation(transcriptionOnlyMs: 110),
            LatencyObservation(transcriptionOnlyMs: 120),
        ])

        XCTAssertEqual(transcriptionOnlyReport.transcriptionOnly.count, 3)
        XCTAssertEqual(transcriptionOnlyReport.transcriptionOnly.averageMs, 320.0 / 3.0)
        XCTAssertEqual(transcriptionOnlyReport.transcriptionOnly.p95Ms, 120)
        XCTAssertNil(transcriptionOnlyReport.endToEnd)
        XCTAssertNil(transcriptionOnlyReport.retryOverhead)

        let extendedReport = TranscriptionQualityMetrics.latencyMetricsReport([
            LatencyObservation(transcriptionOnlyMs: 100, endToEndMs: 150, retryOverheadMs: 40),
            LatencyObservation(transcriptionOnlyMs: 120, endToEndMs: 180, retryOverheadMs: 60),
        ])

        XCTAssertEqual(extendedReport.transcriptionOnly.averageMs, 110)
        XCTAssertEqual(extendedReport.endToEnd?.averageMs, 165)
        XCTAssertEqual(extendedReport.retryOverhead?.averageMs, 50)
    }
}
