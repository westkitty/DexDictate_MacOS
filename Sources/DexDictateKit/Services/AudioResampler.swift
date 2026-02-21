import Foundation
import AVFoundation

public struct AudioResampler {
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
