import XCTest
@testable import DexDictateKit

final class MockAudioProviderTests: XCTestCase {
    
    func testInjectMockSamplesWithoutAVAudioEngine() {
        let service = AudioRecorderService()
        
        // Initially, buffer should be empty.
        let initialSamples = service.collectRecording()
        XCTAssertTrue(initialSamples.isEmpty, "Initially accumulated samples should be empty")
        
        // Inject deterministic float samples.
        let mockSamples: [Float] = [0.1, -0.2, 0.3, -0.4, 0.5]
        service.injectMockSamples(mockSamples)
        
        // Verify buffer accumulation produces expected samples and frame counts.
        let collectedSamples = service.collectRecording()
        XCTAssertEqual(collectedSamples.count, 5, "Should accumulate exactly 5 samples")
        XCTAssertEqual(collectedSamples, mockSamples, "Accumulated samples must match injected samples exactly")
    }
    
    func testCollectRecordingClearsAccumulation() {
        let service = AudioRecorderService()
        
        let mockSamples: [Float] = [0.5, 0.5, 0.5]
        service.injectMockSamples(mockSamples)
        
        // First collection should have the samples
        let firstCollection = service.collectRecording()
        XCTAssertEqual(firstCollection.count, 3)
        
        // Second immediate collection should be empty (stop/reset behavior)
        let secondCollection = service.collectRecording()
        XCTAssertTrue(secondCollection.isEmpty, "Subsequent collection without new injection must be empty")
    }
    
    func testEmptySampleInputIsHandledSafely() {
        let service = AudioRecorderService()
        
        // Inject empty buffer
        service.injectMockSamples([])
        
        let collected = service.collectRecording()
        XCTAssertTrue(collected.isEmpty, "Empty input injection should result in empty collection")
    }
    
    func testIntegrationWithAudioResampler() {
        let service = AudioRecorderService()
        
        // Proving deterministic sample rate setting and downsampling.
        // We set input rate to 48000 Hz, resample to Whisper (16000 Hz) -> should reduce count by exactly 3x.
        #if DEBUG
        service.setCapturedSampleRateForTesting(48000.0)
        #endif
        
        // Generate a 1-second sine-like wave or simple periodic pattern at 48000 Hz.
        // 48000 samples.
        let nativeCount = 48000
        var mockSamples = [Float](repeating: 0.0, count: nativeCount)
        for i in 0..<nativeCount {
            mockSamples[i] = sin(2.0 * .pi * 440.0 * Float(i) / 48000.0)
        }
        
        service.injectMockSamples(mockSamples)
        
        let collected = service.collectRecording()
        XCTAssertEqual(collected.count, nativeCount)
        
        // Let's resample
        let whisperSamples = AudioResampler.resampleToWhisper(collected, fromRate: service.capturedSampleRate)
        
        // 48000 Hz resampled to 16000 Hz should yield exactly 16000 samples.
        XCTAssertEqual(whisperSamples.count, 16000, "Resampling from 48000Hz to 16000Hz must produce exactly 16000 samples")
    }
    
    func testRepeatedInjectionsAccumulateInOrder() {
        let service = AudioRecorderService()
        
        let firstBatch: [Float] = [1.0, 2.0]
        let secondBatch: [Float] = [3.0, 4.0]
        let thirdBatch: [Float] = [5.0, 6.0]
        
        service.injectMockSamples(firstBatch)
        service.injectMockSamples(secondBatch)
        service.injectMockSamples(thirdBatch)
        
        let collected = service.collectRecording()
        XCTAssertEqual(collected.count, 6)
        XCTAssertEqual(collected, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], "Buffers must accumulate strictly in chronological order")
    }
    
    func testLargeMockBufferAccumulatesAndDownsamples() {
        let service = AudioRecorderService()
        
        #if DEBUG
        service.setCapturedSampleRateForTesting(44100.0)
        #endif
        
        // 5 seconds at 44.1 kHz = 220,500 samples.
        // Fast to generate and run, yet large enough to verify chunk boundaries.
        let nativeRate = 44100.0
        let targetRate = 16000.0
        let seconds = 5.0
        let nativeCount = Int(nativeRate * seconds)
        
        var mockSamples = [Float](repeating: 0.0, count: nativeCount)
        for i in 0..<nativeCount {
            mockSamples[i] = sin(2.0 * .pi * 220.0 * Float(i) / Float(nativeRate))
        }
        
        service.injectMockSamples(mockSamples)
        
        let collected = service.collectRecording()
        XCTAssertEqual(collected.count, nativeCount)
        
        let whisperSamples = AudioResampler.resampleToWhisper(collected, fromRate: service.capturedSampleRate)
        
        let expectedCount = Int(targetRate * seconds)
        // Allow a small mathematical tolerance of 5 frames due to linear conversion alignment.
        let difference = abs(whisperSamples.count - expectedCount)
        XCTAssertLessThanOrEqual(difference, 5, "Large downsampling output should match 16kHz within standard margins")
    }
    
    func testZeroAndExtremeAmplitudeMockSamples() {
        let service = AudioRecorderService()
        
        #if DEBUG
        service.setCapturedSampleRateForTesting(44100.0)
        #endif
        
        // Feed zeros, system limit extremes, and slight overflows.
        let extremes: [Float] = [0.0, -1.0, 1.0, -2.0, 2.0, -0.0]
        service.injectMockSamples(extremes)
        
        let collected = service.collectRecording()
        XCTAssertEqual(collected, extremes)
        
        // Ensure resampling handles mathematical limits without crashing or producing non-finite values.
        let whisperSamples = AudioResampler.resampleToWhisper(collected, fromRate: service.capturedSampleRate)
        XCTAssertFalse(whisperSamples.isEmpty)
        for val in whisperSamples {
            XCTAssertTrue(val.isFinite, "Resampled extreme amplitudes must remain mathematically finite")
        }
    }
}
