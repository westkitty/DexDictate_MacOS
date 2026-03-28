import XCTest
@testable import DexDictateKit

final class BenchmarkPromotionPolicyTests: XCTestCase {
    func testPromotionRequiresMeaningfulWERGainWithinLatencyBudget() {
        let thresholds = BenchmarkGateThresholds(
            maxAverageWER: 0.08,
            maxP95LatencyMs: 2200,
            minImprovementWERRatio: 0.2,
            maxP95LatencyRegressionRatio: 0.35
        )

        let current = ModelBenchmarkResult(
            hardwareFingerprint: "hw",
            appVersion: "dev",
            modelID: "tiny.en",
            modelIdentity: "tiny",
            decodeProfile: "accuracy",
            utteranceEndPreset: "Stable",
            processedFiles: 1,
            averageWER: 0.10,
            averageLatencyMs: 1000,
            p95LatencyMs: 1000,
            completedAt: Date()
        )

        let candidate = ModelBenchmarkResult(
            hardwareFingerprint: "hw",
            appVersion: "dev",
            modelID: "base.en",
            modelIdentity: "base",
            decodeProfile: "accuracy",
            utteranceEndPreset: "Stable",
            processedFiles: 1,
            averageWER: 0.07,
            averageLatencyMs: 1200,
            p95LatencyMs: 1300,
            completedAt: Date()
        )

        let decision = BenchmarkPromotionPolicy.shouldPromote(
            candidate: candidate,
            current: current,
            thresholds: thresholds
        )

        XCTAssertTrue(decision.shouldPromote)
    }

    func testPromotionRejectsExcessiveLatencyRegression() {
        let thresholds = BenchmarkGateThresholds(
            maxAverageWER: 0.08,
            maxP95LatencyMs: 2200,
            minImprovementWERRatio: 0.2,
            maxP95LatencyRegressionRatio: 0.35
        )

        let current = ModelBenchmarkResult(
            hardwareFingerprint: "hw",
            appVersion: "dev",
            modelID: "tiny.en",
            modelIdentity: "tiny",
            decodeProfile: "accuracy",
            utteranceEndPreset: "Stable",
            processedFiles: 1,
            averageWER: 0.10,
            averageLatencyMs: 1000,
            p95LatencyMs: 1000,
            completedAt: Date()
        )

        let candidate = ModelBenchmarkResult(
            hardwareFingerprint: "hw",
            appVersion: "dev",
            modelID: "base.en",
            modelIdentity: "base",
            decodeProfile: "accuracy",
            utteranceEndPreset: "Stable",
            processedFiles: 1,
            averageWER: 0.06,
            averageLatencyMs: 1600,
            p95LatencyMs: 1500,
            completedAt: Date()
        )

        let decision = BenchmarkPromotionPolicy.shouldPromote(
            candidate: candidate,
            current: current,
            thresholds: thresholds
        )

        XCTAssertFalse(decision.shouldPromote)
    }
}
