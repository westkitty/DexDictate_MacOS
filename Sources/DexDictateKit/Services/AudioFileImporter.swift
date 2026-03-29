import Foundation
import AVFoundation

/// Reads an audio file from disk and returns PCM samples ready for Whisper processing.
public enum AudioFileImporter {

    public enum ImportError: LocalizedError {
        case unreadableFile
        case unsupportedFormat
        case bufferCreationFailed
        case noAudioData

        public var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return "Could not open the audio file."
            case .unsupportedFormat:
                return "Unsupported audio format."
            case .bufferCreationFailed:
                return "Could not allocate audio buffer."
            case .noAudioData:
                return "The audio file contains no audio data."
            }
        }
    }

    /// Reads an audio file and returns its samples as a `[Float]` array at the file's native sample rate.
    ///
    /// The returned samples are downmixed to mono float PCM.
    /// Pass the result directly to `AudioResampler.resampleToWhisper(_:fromRate:)`.
    public static func loadSamples(from url: URL) throws -> (samples: [Float], sampleRate: Double) {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(
                forReading: url,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw ImportError.unreadableFile
        }

        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0 else {
            throw ImportError.noAudioData
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ImportError.bufferCreationFailed
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            throw ImportError.unreadableFile
        }

        guard let floatData = buffer.floatChannelData else {
            throw ImportError.unsupportedFormat
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        guard frameLength > 0, channelCount > 0 else {
            throw ImportError.noAudioData
        }

        let samples = downmixToMono(channelCount: channelCount, frameLength: frameLength) { channel, index in
            floatData[channel][index]
        }

        return (samples, format.sampleRate)
    }

    static func downmixToMono(
        channelCount: Int,
        frameLength: Int,
        sampleAt: (Int, Int) -> Float
    ) -> [Float] {
        guard frameLength > 0, channelCount > 0 else {
            return []
        }

        if channelCount == 1 {
            return (0..<frameLength).map { sampleAt(0, $0) }
        }

        var mixed = [Float](repeating: 0, count: frameLength)
        let scale = 1 / Float(channelCount)

        for channel in 0..<channelCount {
            for index in 0..<frameLength {
                mixed[index] += sampleAt(channel, index) * scale
            }
        }

        return mixed
    }
}
