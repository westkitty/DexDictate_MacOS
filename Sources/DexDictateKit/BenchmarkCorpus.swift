import Foundation

public struct BenchmarkPrompt: Identifiable, Codable, Equatable {
    public let id: String
    public let section: String
    public let instructionText: String?
    public let spokenPrompt: String
    public let referenceText: String
    public let fileName: String

    public init(
        id: String,
        section: String,
        instructionText: String? = nil,
        spokenPrompt: String,
        referenceText: String,
        fileName: String
    ) {
        self.id = id
        self.section = section
        self.instructionText = instructionText
        self.spokenPrompt = spokenPrompt
        self.referenceText = referenceText
        self.fileName = fileName
    }
}

public enum BenchmarkCorpus {
    public static let strictPrompts: [BenchmarkPrompt] = [
        BenchmarkPrompt(
            id: "A1",
            section: "General",
            spokenPrompt: "DexDictate should transcribe this sentence exactly once.",
            referenceText: "DexDictate should transcribe this sentence exactly once.",
            fileName: "A1.wav"
        ),
        BenchmarkPrompt(
            id: "A2",
            section: "General",
            spokenPrompt: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            referenceText: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            fileName: "A2.wav"
        ),
        BenchmarkPrompt(
            id: "A3",
            section: "General",
            spokenPrompt: "I need the quarterly revenue report by end of day.",
            referenceText: "I need the quarterly revenue report by end of day.",
            fileName: "A3.wav"
        ),
        BenchmarkPrompt(
            id: "A4",
            section: "General",
            spokenPrompt: "The architecture uses event taps and local inference only.",
            referenceText: "The architecture uses event taps and local inference only.",
            fileName: "A4.wav"
        ),
        BenchmarkPrompt(
            id: "A5",
            section: "General",
            spokenPrompt: "Do not send data to any external service.",
            referenceText: "Do not send data to any external service.",
            fileName: "A5.wav"
        ),
        BenchmarkPrompt(
            id: "B1",
            section: "Punctuation",
            spokenPrompt: "This is sentence one period",
            referenceText: "This is sentence one period",
            fileName: "B1.wav"
        ),
        BenchmarkPrompt(
            id: "B2",
            section: "Punctuation",
            spokenPrompt: "This is sentence two period",
            referenceText: "This is sentence two period",
            fileName: "B2.wav"
        ),
        BenchmarkPrompt(
            id: "B3",
            section: "Punctuation",
            spokenPrompt: "Add a comma after this phrase comma then continue.",
            referenceText: "Add a comma after this phrase comma then continue.",
            fileName: "B3.wav"
        ),
        BenchmarkPrompt(
            id: "B4",
            section: "Punctuation",
            spokenPrompt: "Question mark test question mark",
            referenceText: "Question mark test question mark",
            fileName: "B4.wav"
        ),
        BenchmarkPrompt(
            id: "B5",
            section: "Punctuation",
            spokenPrompt: "End this line with a period.",
            referenceText: "End this line with a period.",
            fileName: "B5.wav"
        ),
        BenchmarkPrompt(
            id: "C1",
            section: "Commands",
            spokenPrompt: "new line this should be on a new line",
            referenceText: "new line this should be on a new line",
            fileName: "C1.wav"
        ),
        BenchmarkPrompt(
            id: "C2",
            section: "Commands",
            spokenPrompt: "next line this should also break line",
            referenceText: "next line this should also break line",
            fileName: "C2.wav"
        ),
        BenchmarkPrompt(
            id: "C3",
            section: "Commands",
            spokenPrompt: "scratch that",
            referenceText: "scratch that",
            fileName: "C3.wav"
        ),
        BenchmarkPrompt(
            id: "C4",
            section: "Commands",
            spokenPrompt: "this line all caps",
            referenceText: "this line all caps",
            fileName: "C4.wav"
        ),
        BenchmarkPrompt(
            id: "C5",
            section: "Commands",
            spokenPrompt: "hello world scratch that",
            referenceText: "hello world scratch that",
            fileName: "C5.wav"
        ),
        BenchmarkPrompt(
            id: "D1",
            section: "Hard Words",
            spokenPrompt: "Kubernetes Istio Prometheus Grafana",
            referenceText: "Kubernetes Istio Prometheus Grafana",
            fileName: "D1.wav"
        ),
        BenchmarkPrompt(
            id: "D2",
            section: "Hard Words",
            spokenPrompt: "PostgreSQL Redis SQLite Cassandra",
            referenceText: "PostgreSQL Redis SQLite Cassandra",
            fileName: "D2.wav"
        ),
        BenchmarkPrompt(
            id: "D3",
            section: "Hard Words",
            spokenPrompt: "Dexter WestKitty DexDictate",
            referenceText: "Dexter WestKitty DexDictate",
            fileName: "D3.wav"
        ),
        BenchmarkPrompt(
            id: "D4",
            section: "Hard Words",
            spokenPrompt: "ane transformer core ml encoder",
            referenceText: "ane transformer core ml encoder",
            fileName: "D4.wav"
        ),
        BenchmarkPrompt(
            id: "D5",
            section: "Hard Words",
            spokenPrompt: "whisper cpp swift whisper",
            referenceText: "whisper cpp swift whisper",
            fileName: "D5.wav"
        ),
        BenchmarkPrompt(
            id: "N1A1",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "DexDictate should transcribe this sentence exactly once.",
            referenceText: "DexDictate should transcribe this sentence exactly once.",
            fileName: "N1A1.wav"
        ),
        BenchmarkPrompt(
            id: "N1A2",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            referenceText: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            fileName: "N1A2.wav"
        ),
        BenchmarkPrompt(
            id: "N1A3",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "I need the quarterly revenue report by end of day.",
            referenceText: "I need the quarterly revenue report by end of day.",
            fileName: "N1A3.wav"
        ),
        BenchmarkPrompt(
            id: "N1A4",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "The architecture uses event taps and local inference only.",
            referenceText: "The architecture uses event taps and local inference only.",
            fileName: "N1A4.wav"
        ),
        BenchmarkPrompt(
            id: "N1A5",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "Do not send data to any external service.",
            referenceText: "Do not send data to any external service.",
            fileName: "N1A5.wav"
        ),
        BenchmarkPrompt(
            id: "N2A1",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "DexDictate should transcribe this sentence exactly once.",
            referenceText: "DexDictate should transcribe this sentence exactly once.",
            fileName: "N2A1.wav"
        ),
        BenchmarkPrompt(
            id: "N2A2",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            referenceText: "Please book a meeting for Tuesday at 3 PM with Dexter.",
            fileName: "N2A2.wav"
        ),
        BenchmarkPrompt(
            id: "N2A3",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "I need the quarterly revenue report by end of day.",
            referenceText: "I need the quarterly revenue report by end of day.",
            fileName: "N2A3.wav"
        ),
        BenchmarkPrompt(
            id: "N2A4",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "The architecture uses event taps and local inference only.",
            referenceText: "The architecture uses event taps and local inference only.",
            fileName: "N2A4.wav"
        ),
        BenchmarkPrompt(
            id: "N2A5",
            section: "Quiet Room Stability",
            instructionText: "Quiet room pass",
            spokenPrompt: "Do not send data to any external service.",
            referenceText: "Do not send data to any external service.",
            fileName: "N2A5.wav"
        )
    ]

    public static var strictTranscriptMap: [String: String] {
        Dictionary(uniqueKeysWithValues: strictPrompts.map { ($0.fileName, $0.referenceText) })
    }

    public static func fileNames(for prompts: [BenchmarkPrompt] = strictPrompts) -> [String] {
        prompts.map(\.fileName)
    }

    public static func createCaptureSessionName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return "benchmark-capture-\(formatter.string(from: date))"
    }
}
