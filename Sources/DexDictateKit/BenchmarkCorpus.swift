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
            spokenPrompt: "Schedule a meeting for Tuesday at 3 PM with Dexter, reluctantly.",
            referenceText: "Schedule a meeting for Tuesday at 3 PM with Dexter, reluctantly.",
            fileName: "A2.wav"
        ),
        BenchmarkPrompt(
            id: "A3",
            section: "General",
            spokenPrompt: "I need the quarterly revenue report by end of day, not eventually.",
            referenceText: "I need the quarterly revenue report by end of day, not eventually.",
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
            spokenPrompt: "Do not send data to any external service. Obviously.",
            referenceText: "Do not send data to any external service. Obviously.",
            fileName: "A5.wav"
        ),
        BenchmarkPrompt(
            id: "B1",
            section: "Punctuation",
            spokenPrompt: "This sentence ends with a period period",
            referenceText: "This sentence ends with a period period",
            fileName: "B1.wav"
        ),
        BenchmarkPrompt(
            id: "B2",
            section: "Punctuation",
            spokenPrompt: "Add a comma after Dexter comma then continue.",
            referenceText: "Add a comma after Dexter comma then continue.",
            fileName: "B2.wav"
        ),
        BenchmarkPrompt(
            id: "B3",
            section: "Punctuation",
            spokenPrompt: "Is this working yet question mark",
            referenceText: "Is this working yet question mark",
            fileName: "B3.wav"
        ),
        BenchmarkPrompt(
            id: "B4",
            section: "Punctuation",
            spokenPrompt: "Open parenthesis local only close parenthesis period",
            referenceText: "Open parenthesis local only close parenthesis period",
            fileName: "B4.wav"
        ),
        BenchmarkPrompt(
            id: "B5",
            section: "Punctuation",
            spokenPrompt: "Quote unimpressed but correct quote period",
            referenceText: "Quote unimpressed but correct quote period",
            fileName: "B5.wav"
        ),
        BenchmarkPrompt(
            id: "C1",
            section: "Commands",
            spokenPrompt: "new line this should move to a new line",
            referenceText: "new line this should move to a new line",
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
            spokenPrompt: "Dexter DexGPT DexDictate",
            referenceText: "Dexter DexGPT DexDictate",
            fileName: "D3.wav"
        ),
        BenchmarkPrompt(
            id: "D4",
            section: "Hard Words",
            spokenPrompt: "A N E transformer Core ML encoder",
            referenceText: "A N E transformer Core ML encoder",
            fileName: "D4.wav"
        ),
        BenchmarkPrompt(
            id: "D5",
            section: "Hard Words",
            spokenPrompt: "whisper C P P Swift Whisper",
            referenceText: "whisper C P P Swift Whisper",
            fileName: "D5.wav"
        ),
        BenchmarkPrompt(
            id: "N1A1",
            section: "Operational Tone",
            spokenPrompt: "The microphone behaved today, which feels suspicious.",
            referenceText: "The microphone behaved today, which feels suspicious.",
            fileName: "N1A1.wav"
        ),
        BenchmarkPrompt(
            id: "N1A2",
            section: "Operational Tone",
            spokenPrompt: "Low latency, clean output, and no nonsense.",
            referenceText: "Low latency, clean output, and no nonsense.",
            fileName: "N1A2.wav"
        ),
        BenchmarkPrompt(
            id: "N1A3",
            section: "Operational Tone",
            spokenPrompt: "Fix the last sentence and keep going.",
            referenceText: "Fix the last sentence and keep going.",
            fileName: "N1A3.wav"
        ),
        BenchmarkPrompt(
            id: "N1A4",
            section: "Operational Tone",
            spokenPrompt: "This transcript stays on device, as it should.",
            referenceText: "This transcript stays on device, as it should.",
            fileName: "N1A4.wav"
        ),
        BenchmarkPrompt(
            id: "N1A5",
            section: "Operational Tone",
            spokenPrompt: "Benchmark first, boast never.",
            referenceText: "Benchmark first, boast never.",
            fileName: "N1A5.wav"
        ),
        BenchmarkPrompt(
            id: "N2A1",
            section: "Fixed Anchors",
            spokenPrompt: "Anchor one DexDictate should get this right the first time.",
            referenceText: "Anchor one DexDictate should get this right the first time.",
            fileName: "N2A1.wav"
        ),
        BenchmarkPrompt(
            id: "N2A2",
            section: "Fixed Anchors",
            spokenPrompt: "Anchor two Dexter remains unimpressed by sloppy latency.",
            referenceText: "Anchor two Dexter remains unimpressed by sloppy latency.",
            fileName: "N2A2.wav"
        ),
        BenchmarkPrompt(
            id: "N2A3",
            section: "Fixed Anchors",
            spokenPrompt: "Anchor three local transcription means local, not adjacent to local.",
            referenceText: "Anchor three local transcription means local, not adjacent to local.",
            fileName: "N2A3.wav"
        ),
        BenchmarkPrompt(
            id: "N2A4",
            section: "Fixed Anchors",
            spokenPrompt: "Anchor four punctuation should work without theatrical collapse.",
            referenceText: "Anchor four punctuation should work without theatrical collapse.",
            fileName: "N2A4.wav"
        ),
        BenchmarkPrompt(
            id: "N2A5",
            section: "Fixed Anchors",
            spokenPrompt: "Anchor five accuracy is the minimum, not an achievement.",
            referenceText: "Anchor five accuracy is the minimum, not an achievement.",
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
