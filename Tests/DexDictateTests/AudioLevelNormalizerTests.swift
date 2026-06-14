import XCTest
@testable import DexDictateKit

final class AudioLevelNormalizerTests: XCTestCase {

    // MARK: - Edge cases: zero and below-floor amplitudes

    func testZeroAmplitudeReturnsZero() {
        let result = AudioLevelNormalizer.normalize(0.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Zero amplitude should return 0.0 (silence)")
    }

    func testNegativeAmplitudeReturnsZero() {
        // Negative amplitude is physically meaningless — should clamp to 0.0.
        let result = AudioLevelNormalizer.normalize(-1.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Negative amplitude should return 0.0")
    }

    func testTinyAmplitudeReturnsNearZero() {
        // 1e-8 is about -160 dB — well below the -80 dB floor.
        let result = AudioLevelNormalizer.normalize(1e-8)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Amplitude far below floor should return 0.0")
    }

    // MARK: - Floor boundary

    func testAmplitudeAtFloorReturnsApproxZero() {
        // -80 dB floor corresponds to amplitude 10^(-80/20) = 10^(-4) = 0.0001.
        let floorAmplitude = pow(10.0, AudioLevelNormalizer.floorDB / 20.0)
        let result = AudioLevelNormalizer.normalize(floorAmplitude)
        XCTAssertEqual(result, 0.0, accuracy: 1e-9, "Amplitude at floor dB should return ~0.0")
    }

    func testAmplitudeJustAboveFloorReturnsSmallPositive() {
        // Slightly above the floor (floor + 0.5 dB) — should be a small but positive value.
        let justAboveFloor = pow(10.0, (AudioLevelNormalizer.floorDB + 0.5) / 20.0)
        let result = AudioLevelNormalizer.normalize(justAboveFloor)
        XCTAssertGreaterThan(result, 0.0, "Amplitude just above floor should return small positive value")
        XCTAssertLessThan(result, 0.02, "Amplitude just above floor should still be very small")
    }

    // MARK: - Normal speech range

    func testLowSpeechAmplitudeIsInRange() {
        // 0.01 ≈ -40 dB — quiet speech. With -80 dB floor and 80 dB range: (-40+80)/80 = 0.5
        let result = AudioLevelNormalizer.normalize(0.01)
        XCTAssertGreaterThanOrEqual(result, 0.0)
        XCTAssertLessThanOrEqual(result, 1.0)
        let expected = (20.0 * log10(0.01) - AudioLevelNormalizer.floorDB) / AudioLevelNormalizer.rangeDB
        XCTAssertEqual(result, expected, accuracy: 1e-9)
    }

    func testMidSpeechAmplitudeIsInRange() {
        // 0.1 ≈ -20 dB — normal conversational speech. With -80 dB floor: (-20+80)/80 = 0.75
        let result = AudioLevelNormalizer.normalize(0.1)
        XCTAssertGreaterThanOrEqual(result, 0.0)
        XCTAssertLessThanOrEqual(result, 1.0)
        let expected = (20.0 * log10(0.1) - AudioLevelNormalizer.floorDB) / AudioLevelNormalizer.rangeDB
        XCTAssertEqual(result, expected, accuracy: 1e-9)
    }

    func testHighSpeechAmplitudeIsInRange() {
        // 0.5 ≈ -6 dB — loud speech.
        let result = AudioLevelNormalizer.normalize(0.5)
        XCTAssertGreaterThanOrEqual(result, 0.0)
        XCTAssertLessThanOrEqual(result, 1.0)
        let expected = (20.0 * log10(0.5) - AudioLevelNormalizer.floorDB) / AudioLevelNormalizer.rangeDB
        XCTAssertEqual(result, expected, accuracy: 1e-9)
    }

    // MARK: - Ceiling and above

    func testFullScaleAmplitudeReturnsOne() {
        // 1.0 = 0 dB — exactly full scale
        let result = AudioLevelNormalizer.normalize(1.0)
        XCTAssertEqual(result, 1.0, accuracy: 1e-9, "Full-scale amplitude (0 dB) should return 1.0")
    }

    func testAboveFullScaleClampsToOne() {
        // 2.0 = +6 dB — above ceiling, must clamp to 1.0
        let result = AudioLevelNormalizer.normalize(2.0)
        XCTAssertEqual(result, 1.0, accuracy: 1e-9, "Amplitude above 1.0 (above 0 dB) should clamp to 1.0")
    }

    func testVeryLargeAmplitudeClampsToOne() {
        let result = AudioLevelNormalizer.normalize(1000.0)
        XCTAssertEqual(result, 1.0, accuracy: 1e-9, "Very large amplitude should clamp to 1.0")
    }

    // MARK: - NaN and infinity safety sweep

    func testNoNaNOrInfinityAcrossInputRange() {
        // Sweep from below floor to above ceiling using logarithmic steps.
        let amplitudes: [Double] = [
            0.0, 1e-10, 1e-8, 1e-6, 1e-4, 1e-3, 0.01, 0.05,
            0.1, 0.2, 0.5, 0.707, 1.0, 1.5, 2.0, 10.0, 100.0
        ]
        for amplitude in amplitudes {
            let result = AudioLevelNormalizer.normalize(amplitude)
            XCTAssertFalse(result.isNaN, "normalize(\(amplitude)) returned NaN")
            XCTAssertFalse(result.isInfinite, "normalize(\(amplitude)) returned infinity")
            XCTAssertGreaterThanOrEqual(result, 0.0, "normalize(\(amplitude)) < 0.0")
            XCTAssertLessThanOrEqual(result, 1.0, "normalize(\(amplitude)) > 1.0")
        }
    }

    func testNaNInputReturnsSafeValue() {
        // NaN fails isFinite, so it maps to minimumAmplitude → 0.0.
        let result = AudioLevelNormalizer.normalize(Double.nan)
        XCTAssertFalse(result.isNaN, "NaN input should not produce NaN output")
        XCTAssertFalse(result.isInfinite, "NaN input should not produce infinity")
    }

    func testInfinityInputReturnsSafeValue() {
        // +infinity fails isFinite — treated as silence (0.0) rather than full-scale
        XCTAssertEqual(AudioLevelNormalizer.normalize(Double.infinity), 0.0, accuracy: 1e-9)
        XCTAssertEqual(AudioLevelNormalizer.normalize(-Double.infinity), 0.0, accuracy: 1e-9)
    }

    // MARK: - Monotonicity

    func testOutputIsMonotonicallyIncreasing() {
        // Larger amplitude should always produce a larger or equal normalized value.
        let amplitudes = [0.001, 0.01, 0.1, 0.5, 1.0]
        var previous = AudioLevelNormalizer.normalize(amplitudes[0])
        for amplitude in amplitudes.dropFirst() {
            let current = AudioLevelNormalizer.normalize(amplitude)
            XCTAssertGreaterThanOrEqual(current, previous, "normalize is not monotonically increasing at amplitude \(amplitude)")
            previous = current
        }
    }
}
