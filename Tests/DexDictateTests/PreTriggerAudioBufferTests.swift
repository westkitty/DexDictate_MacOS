import XCTest
@testable import DexDictateKit

final class PreTriggerAudioBufferTests: XCTestCase {

    // MARK: - Append and snapshot ordering

    func testAppendAndSnapshotReturnsCorrectOrder() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3], sampleRate: 8)
        buf.append([4, 5], sampleRate: 8)
        XCTAssertEqual(buf.snapshot(), [1, 2, 3, 4, 5])
    }

    func testEmptyBufferSnapshotIsEmpty() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        XCTAssertEqual(buf.snapshot(), [])
    }

    func testSingleSampleAppend() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([42.0], sampleRate: 8)
        XCTAssertEqual(buf.snapshot(), [42.0])
    }

    // MARK: - Wraparound / capacity enforcement

    func testWraparoundDropsOldest() {
        // Capacity = ceil(1.0 * 4) = 4 samples
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 4)
        buf.append([1, 2, 3, 4], sampleRate: 4)  // exactly fills buffer
        buf.append([5, 6], sampleRate: 4)          // overwrites oldest two
        XCTAssertEqual(buf.snapshot(), [3, 4, 5, 6])
    }

    func testOverfillBySingleChunkKeepsNewest() {
        // Capacity = 4; append 6 in one shot — keeps last 4
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 4)
        buf.append([10, 20, 30, 40, 50, 60], sampleRate: 4)
        XCTAssertEqual(buf.snapshot(), [30, 40, 50, 60])
    }

    func testPartialFillThenWrap() {
        // Capacity = 4
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 4)
        buf.append([1, 2], sampleRate: 4)
        buf.append([3, 4], sampleRate: 4)  // fills
        buf.append([5], sampleRate: 4)     // wraps
        XCTAssertEqual(buf.snapshot(), [2, 3, 4, 5])
    }

    func testExactCapacityFillThenOneMore() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 3)
        // capacity = 3
        buf.append([1, 2, 3], sampleRate: 3)
        XCTAssertEqual(buf.snapshot(), [1, 2, 3])
        buf.append([4], sampleRate: 3)
        XCTAssertEqual(buf.snapshot(), [2, 3, 4])
    }

    // MARK: - Clear

    func testClearResetsBuffer() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3], sampleRate: 8)
        buf.clear()
        XCTAssertEqual(buf.snapshot(), [])
    }

    func testClearThenAppend() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3], sampleRate: 8)
        buf.clear()
        buf.append([9, 8], sampleRate: 8)
        XCTAssertEqual(buf.snapshot(), [9, 8])
    }

    // MARK: - Capacity / duration

    func testCapacityMatchesDuration() {
        // 750ms at 48000 Hz → 36000 samples
        let buf = PreTriggerAudioBuffer(durationSeconds: 0.75, sampleRate: 48000)
        let samples = [Float](repeating: 1.0, count: 36001)
        buf.append(samples, sampleRate: 48000)
        // Buffer should hold exactly 36000 samples (drops the oldest 1)
        XCTAssertEqual(buf.snapshot().count, 36000)
    }

    func testCapacityIsAtLeastOne() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 0.000001, sampleRate: 1)
        buf.append([7.0], sampleRate: 1)
        XCTAssertEqual(buf.snapshot(), [7.0])
    }

    // MARK: - Format change (reset)

    func testResetWithNewSampleRate() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3], sampleRate: 8)
        buf.reset(sampleRate: 4)   // new rate — clears and resizes
        XCTAssertEqual(buf.snapshot(), [])
    }

    func testResetThenAppendWithNewRate() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3, 4, 5, 6, 7, 8], sampleRate: 8)
        buf.reset(sampleRate: 4)  // capacity becomes 4
        buf.append([10, 20, 30], sampleRate: 4)
        XCTAssertEqual(buf.snapshot(), [10, 20, 30])
    }

    func testResetSameSampleRateStillClears() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([1, 2, 3], sampleRate: 8)
        buf.reset(sampleRate: 8)  // same rate — should still clear
        XCTAssertEqual(buf.snapshot(), [])
    }

    // MARK: - Prepend ordering (snapshot used as pre-trigger data)

    func testPrependedSnapshotIsChronologicallyFirst() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 8)
        buf.append([10, 20, 30], sampleRate: 8)

        let preTrigger = buf.snapshot()  // [10, 20, 30]
        buf.clear()

        // Simulate what AudioRecorderService does: prepend then append live audio
        let liveAudio: [Float] = [40, 50, 60]
        let combined = preTrigger + liveAudio

        XCTAssertEqual(combined, [10, 20, 30, 40, 50, 60], "Pre-trigger must come before live audio")
    }

    func testSnapshotAfterWrapIsStillChronological() {
        // capacity = 4
        let buf = PreTriggerAudioBuffer(durationSeconds: 1.0, sampleRate: 4)
        buf.append([1, 2, 3, 4, 5, 6], sampleRate: 4) // wraps; keeps [3,4,5,6]
        let snap = buf.snapshot()
        // Verify ascending order (all inputs are strictly increasing)
        for i in 1 ..< snap.count {
            XCTAssertGreaterThan(snap[i], snap[i - 1], "snapshot must be in chronological (oldest-first) order")
        }
    }

    // MARK: - Thread safety smoke test

    // Run with -sanitize=thread for meaningful race detection; this only verifies no crash.
    func testConcurrentWritesDoNotCrash() {
        let buf = PreTriggerAudioBuffer(durationSeconds: 0.1, sampleRate: 1000)
        let iterations = 500
        let group = DispatchGroup()

        for i in 0 ..< iterations {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                buf.append([Float(i), Float(i + 1)], sampleRate: 1000)
                group.leave()
            }
        }

        // One reader racing with writers
        for _ in 0 ..< 50 {
            group.enter()
            DispatchQueue.global(qos: .background).async {
                _ = buf.snapshot()
                group.leave()
            }
        }

        group.wait()
        // If we got here without crashing / EXC_BAD_ACCESS, the test passes.
        XCTAssertTrue(buf.snapshot().count <= 100, "buffer never exceeds capacity")
    }
}
