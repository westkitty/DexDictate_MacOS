import Foundation

public enum DictationDomain: String, CaseIterable, Identifiable {
    case general = "General"
    case coding = "Coding"
    case email = "Email"
    case chat = "Chat"

    public var id: String { rawValue }
}

enum DictationDomainBias {
    static func resolvedDomain(
        mode: AppSettings.DictationDomainMode,
        bundleIdentifier: String?
    ) -> DictationDomain {
        switch mode {
        case .automatic:
            return automaticDomain(for: bundleIdentifier)
        case .general:
            return .general
        case .coding:
            return .coding
        case .email:
            return .email
        case .chat:
            return .chat
        }
    }

    static func vocabularyItems(for domain: DictationDomain) -> [VocabularyItem] {
        switch domain {
        case .general:
            return []
        case .coding:
            return [
                VocabularyItem(original: "swift ui", replacement: "SwiftUI"),
                VocabularyItem(original: "x code", replacement: "Xcode"),
                VocabularyItem(original: "vs code", replacement: "VS Code"),
                VocabularyItem(original: "git hub", replacement: "GitHub"),
                VocabularyItem(original: "type script", replacement: "TypeScript"),
                VocabularyItem(original: "java script", replacement: "JavaScript"),
                VocabularyItem(original: "swift package manager", replacement: "Swift Package Manager"),
                VocabularyItem(original: "pull request", replacement: "pull request"),
                VocabularyItem(original: "command v", replacement: "Command-V"),
                VocabularyItem(original: "api", replacement: "API"),
                VocabularyItem(original: "json", replacement: "JSON"),
                VocabularyItem(original: "mac os", replacement: "macOS"),
                VocabularyItem(original: "core ml", replacement: "Core ML"),
                VocabularyItem(original: "ui", replacement: "UI"),
                VocabularyItem(original: "ux", replacement: "UX")
            ]
        case .email:
            return [
                VocabularyItem(original: "best regards", replacement: "Best regards,"),
                VocabularyItem(original: "let me know", replacement: "let me know"),
                VocabularyItem(original: "follow up", replacement: "follow up"),
                VocabularyItem(original: "subject line", replacement: "subject line"),
                VocabularyItem(original: "thanks again", replacement: "Thanks again,"),
                VocabularyItem(original: "sincerely", replacement: "Sincerely,")
            ]
        case .chat:
            return [
                VocabularyItem(original: "slack", replacement: "Slack"),
                VocabularyItem(original: "discord", replacement: "Discord"),
                VocabularyItem(original: "dm", replacement: "DM"),
                VocabularyItem(original: "ping me", replacement: "ping me"),
                VocabularyItem(original: "fyi", replacement: "FYI"),
                VocabularyItem(original: "lmk", replacement: "LMK")
            ]
        }
    }

    static func initialPrompt(for domain: DictationDomain) -> String? {
        switch domain {
        case .general:
            return nil
        case .coding:
            return "This is local dictation for software development. Prefer technical terms, code editor vocabulary, APIs, file names, frameworks, and programming language names."
        case .email:
            return "This is local dictation for email writing. Prefer polished sentence structure, sign-offs, and common email phrasing."
        case .chat:
            return "This is local dictation for chat messages. Prefer concise informal phrasing, app names, and short message style."
        }
    }

    private static func automaticDomain(for bundleIdentifier: String?) -> DictationDomain {
        guard let bundleIdentifier = bundleIdentifier?.lowercased(), !bundleIdentifier.isEmpty else {
            return .general
        }

        let codingPrefixes = [
            "com.apple.dt.xcode",
            "com.microsoft.vscode",
            "com.jetbrains.",
            "com.apple.terminal",
            "com.googlecode.iterm2",
            "dev.zed."
        ]
        if codingPrefixes.contains(where: { bundleIdentifier.hasPrefix($0) }) {
            return .coding
        }

        let emailPrefixes = [
            "com.apple.mail",
            "com.microsoft.outlook",
            "com.readdle.spark",
            "com.superhuman.superhuman"
        ]
        if emailPrefixes.contains(where: { bundleIdentifier.hasPrefix($0) }) {
            return .email
        }

        let chatPrefixes = [
            "com.tinyspeck.slackmacgap",
            "com.hnc.discord",
            "com.apple.mobilesms",
            "com.hnc.discordapp",
            "us.zoom.xos"
        ]
        if chatPrefixes.contains(where: { bundleIdentifier.hasPrefix($0) }) {
            return .chat
        }

        return .general
    }
}

enum AdaptiveTailDelayHeuristic {
    static func resolvedDelayMs(
        baseDelayMs: UInt64,
        recordingDurationMs: Int?,
        recentOutputs: [String]
    ) -> UInt64 {
        var adjusted = Int(baseDelayMs)

        if let recordingDurationMs {
            switch recordingDurationMs {
            case 4_800...:
                adjusted += 80
            case 2_800...:
                adjusted += 40
            case ..<1_200:
                adjusted -= 20
            default:
                break
            }
        }

        let recent = recentOutputs
            .suffix(4)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let punctuatedCount = recent.filter(\.hasTerminalPunctuation).count
        if punctuatedCount == recent.count && !recent.isEmpty {
            adjusted -= 25
        } else if punctuatedCount == 0 && !recent.isEmpty {
            adjusted += 35
        }

        return UInt64(max(140, min(520, adjusted)))
    }
}

enum SuspiciousTranscriptionHeuristic {
    static func reason(for text: String, audioDurationSeconds: Double) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty-result" }

        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let lowercaseWords = words.map { $0.lowercased() }
        let punctuationCount = trimmed.unicodeScalars.filter(CharacterSet.punctuationCharacters.contains).count
        let punctuationRatio = trimmed.isEmpty ? 0 : Double(punctuationCount) / Double(trimmed.count)
        let letters = trimmed.unicodeScalars.filter(CharacterSet.letters.contains)
        let vowels = letters.filter { "aeiouAEIOU".unicodeScalars.contains($0) }

        if lowercaseWords.contains(where: { ["[music]", "[inaudible]", "(music)"].contains($0) }) {
            return "contained a non-speech marker"
        }

        if hasRepeatedTokenRun(words: lowercaseWords, minimumRunLength: 3) {
            return "contained a repeated token run"
        }

        if audioDurationSeconds >= 2.0 && words.count <= 1 {
            return "single-word-for-long-utterance"
        }

        if audioDurationSeconds >= 3.2 && trimmed.count <= 8 {
            return "very-short-for-long-utterance"
        }

        if letters.count >= 5 && vowels.isEmpty {
            return "no-vowels-in-letter-output"
        }

        if audioDurationSeconds >= 1.5 && words.count <= 4 && punctuationRatio > 0.35 {
            return "symbol-heavy-output"
        }

        return nil
    }

    private static func hasRepeatedTokenRun(words: [String], minimumRunLength: Int) -> Bool {
        guard !words.isEmpty else { return false }

        var currentWord = words[0]
        var currentRun = 1

        for word in words.dropFirst() {
            if word == currentWord {
                currentRun += 1
                if currentRun >= minimumRunLength {
                    return true
                }
            } else {
                currentWord = word
                currentRun = 1
            }
        }

        return false
    }
}

private extension String {
    var hasTerminalPunctuation: Bool {
        guard let last = trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return [".", "!", "?"].contains(last)
    }
}
