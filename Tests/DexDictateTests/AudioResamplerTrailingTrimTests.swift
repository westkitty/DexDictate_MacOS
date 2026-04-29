import XCTest
@testable import DexDictateKit

final class AudioResamplerTrailingTrimTests: XCTestCase {
    func testTrailingTrimRemovesLongTrailingSilenceWithoutTouchingLeadingSpeech() {
        let sampleRate = 1000.0
        let leadingSpeech = Array(repeating: Float(0.5), count: 120)
        let middleSpeech = Array(repeating: Float(0.35), count: 120)
        let trailingSilence = Array(repeating: Float(0.0), count: 600)
        let samples = leadingSpeech + middleSpeech + trailingSilence

        let trimmed = AudioResampler.trimTrailingSilenceCalibrated(
            samples,
            sampleRate: sampleRate,
            minimumSilenceMs: 220,
            padMs: 80
        )

        XCTAssertFalse(trimmed.isEmpty)
        XCTAssertLessThan(trimmed.count, samples.count)
        XCTAssertEqual(Array(trimmed.prefix(leadingSpeech.count)), leadingSpeech)
        XCTAssertEqual(Array(trimmed.dropFirst(leadingSpeech.count).prefix(middleSpeech.count)), middleSpeech)
    }

    func testTrailingTrimDoesNotIncreaseSampleCountAndPreservesNonEmptySpeech() {
        let sampleRate = 1000.0
        let speechOnly = Array(repeating: Float(0.42), count: 180)

        let trimmed = AudioResampler.trimTrailingSilenceCalibrated(
            speechOnly,
            sampleRate: sampleRate,
            minimumSilenceMs: 220,
            padMs: 80
        )

        XCTAssertFalse(trimmed.isEmpty)
        XCTAssertLessThanOrEqual(trimmed.count, speechOnly.count)
        XCTAssertEqual(trimmed, speechOnly)
    }

    func testTrailingTrimHandlesShortAndEmptyInputSafely() {
        let sampleRate = 1000.0
        let shortInput = [Float](repeating: 0.0, count: 10)
        let emptyInput: [Float] = []

        let trimmedShort = AudioResampler.trimTrailingSilenceCalibrated(
            shortInput,
            sampleRate: sampleRate,
            minimumSilenceMs: 220,
            padMs: 80
        )
        let trimmedEmpty = AudioResampler.trimTrailingSilenceCalibrated(
            emptyInput,
            sampleRate: sampleRate,
            minimumSilenceMs: 220,
            padMs: 80
        )

        XCTAssertEqual(trimmedShort, shortInput)
        XCTAssertEqual(trimmedEmpty, emptyInput)
    }
}
