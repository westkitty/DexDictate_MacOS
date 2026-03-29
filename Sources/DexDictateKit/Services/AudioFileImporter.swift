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
    /// The returned samples are already downmixed to mono (channel 0 only).
    /// Pass the result directly to `AudioResampler.resampleToWhisper(_:fromRate:)`.
    public static func loadSamples(from url: URL) throws -> (samples: [Float], sampleRate: Double) {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
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

        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
        return (samples, format.sampleRate)
    }
}
