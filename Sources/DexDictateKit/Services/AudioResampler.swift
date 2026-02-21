import Foundation
import AVFoundation

public struct AudioResampler {

    // MARK: - Energy-Based Silence Trimmer

    /// Trims leading and trailing silence from a PCM buffer using RMS energy detection.
    ///
    /// The algorithm:
    /// 1. Divides the buffer into overlapping 100 ms analysis *frames*.
    /// 2. Computes RMS energy for each frame.
    /// 3. Walks inward from each end; the first frame whose RMS exceeds `threshold`
    ///    marks the speech boundary.
    /// 4. Clamps with a ±`padMs` guard to avoid clipping onset/offset consonants.
    ///
    /// - Parameters:
    ///   - samples:   PCM samples at `sampleRate`.
    ///   - sampleRate: Rate of the incoming samples (native device rate).
    ///   - threshold:  RMS threshold below which a frame is considered silent (0.0–1.0).
    ///   - padMs:      Extra milliseconds to keep beyond the detected boundaries.
    /// - Returns: The trimmed sub-array, or the original if speech fills the whole buffer
    ///            or if the buffer is too short to analyse.
    public static func trimSilenceFast(
        _ samples: [Float],
        sampleRate: Double = 44100,
        threshold: Float = 0.005,
        padMs: Int = 80
    ) -> [Float] {
        let frameSizeSamples = Int(sampleRate * 0.1)   // 100 ms per frame
        let padSamples       = Int(sampleRate * Double(padMs) / 1000.0)
        let minSamples       = frameSizeSamples * 3    // don't bother trimming tiny clips

        guard samples.count > minSamples else { return samples }

        // --- forward scan: find first active frame ---
        var speechStart = 0
        var foundStart  = false
        var i = 0
        while i + frameSizeSamples <= samples.count {
            let rms = rmsEnergy(samples, from: i, count: frameSizeSamples)
            if rms > threshold {
                speechStart = max(0, i - padSamples)
                foundStart  = true
                break
            }
            i += frameSizeSamples
        }
        guard foundStart else { return samples }  // all silence → return original

        // --- backward scan: find last active frame ---
        var speechEnd = samples.count
        var j = samples.count - frameSizeSamples
        while j >= speechStart {
            let rms = rmsEnergy(samples, from: j, count: frameSizeSamples)
            if rms > threshold {
                speechEnd = min(samples.count, j + frameSizeSamples + padSamples)
                break
            }
            j -= frameSizeSamples
        }

        guard speechStart < speechEnd else { return samples }
        return Array(samples[speechStart..<speechEnd])
    }

    // MARK: - Private helpers

    @inline(__always)
    private static func rmsEnergy(_ buf: [Float], from: Int, count: Int) -> Float {
        var sum: Float = 0
        for k in from..<(from + count) { sum += buf[k] * buf[k] }
        return (sum / Float(count)).squareRoot()
    }


    /// Resamples to 16 kHz (Whisper's required sample rate).
    public static func resampleToWhisper(_ samples: [Float], fromRate: Double) -> [Float] {
        let targetRate: Double = 16000
        guard fromRate != targetRate, !samples.isEmpty else { return samples }
        
        if ExperimentFlags.resampleMethod == .avAudioConverter {
            let frameCount = AVAudioFrameCount(samples.count)
            guard let formatIn = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: fromRate, channels: 1, interleaved: false),
                  let formatOut = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetRate, channels: 1, interleaved: false),
                  let converter = AVAudioConverter(from: formatIn, to: formatOut) else {
                return resampleToWhisperLinear(samples, fromRate: fromRate, targetRate: targetRate)
            }
            converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue

            guard let bufferIn = AVAudioPCMBuffer(pcmFormat: formatIn, frameCapacity: frameCount) else { return samples }
            bufferIn.frameLength = frameCount
            if let data = bufferIn.floatChannelData?[0] {
                data.initialize(from: samples, count: samples.count)
            }
            
            let targetFrameCount = AVAudioFrameCount(Double(samples.count) * targetRate / fromRate) + 4096
            guard let bufferOut = AVAudioPCMBuffer(pcmFormat: formatOut, frameCapacity: targetFrameCount) else { return samples }
            
            var provided = false
            var error: NSError?
            let status = converter.convert(to: bufferOut, error: &error) { packetCount, outStatus in
                if provided {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                provided = true
                outStatus.pointee = .haveData
                return bufferIn
            }
            
            if status == .error {
                Safety.log("AVAudioConverter error: \(error?.localizedDescription ?? "unknown")")
                return resampleToWhisperLinear(samples, fromRate: fromRate, targetRate: targetRate)
            }
            
            if let outData = bufferOut.floatChannelData?[0] {
                return Array(UnsafeBufferPointer(start: outData, count: Int(bufferOut.frameLength)))
            }
            return resampleToWhisperLinear(samples, fromRate: fromRate, targetRate: targetRate)
        } else {
            return resampleToWhisperLinear(samples, fromRate: fromRate, targetRate: targetRate)
        }
    }

    private static func resampleToWhisperLinear(_ samples: [Float], fromRate: Double, targetRate: Double) -> [Float] {
        let ratio = fromRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)
        var output = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let srcPos = Double(i) * ratio
            let srcIdx = Int(srcPos)
            let frac = Float(srcPos - Double(srcIdx))
            let a = samples[srcIdx]
            let b = srcIdx + 1 < samples.count ? samples[srcIdx + 1] : a
            output[i] = a + frac * (b - a)
        }
        return output
    }
}
