import AVFoundation
import Foundation
import Darwin

public enum BenchmarkWAVWriter {
    public enum WriteError: Error {
        case invalidFormat
        case invalidBuffer
        case noChannelData
    }

    public static func writeFloatMono(samples: [Float], sampleRate: Double, to url: URL) throws {
        guard !samples.isEmpty else { throw WriteError.invalidBuffer }
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw WriteError.invalidFormat
        }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WriteError.invalidBuffer
        }

        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else {
            throw WriteError.noChannelData
        }

        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            memcpy(channelData, baseAddress, samples.count * MemoryLayout<Float>.size)
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)
    }
}
