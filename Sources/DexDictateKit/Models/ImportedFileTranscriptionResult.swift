import Foundation

public struct ImportedFileTranscriptionResult: Identifiable, Equatable {
    public let id: UUID
    public let fileName: String
    public let transcript: String
    public let createdAt: Date
    public let wasModified: Bool

    public init(
        id: UUID = UUID(),
        fileName: String,
        transcript: String,
        createdAt: Date = Date(),
        wasModified: Bool
    ) {
        self.id = id
        self.fileName = fileName
        self.transcript = transcript
        self.createdAt = createdAt
        self.wasModified = wasModified
    }
}
