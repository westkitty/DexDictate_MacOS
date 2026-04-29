import Foundation

public struct TranscriptionQualityPair: Equatable {
    public let reference: String
    public let hypothesis: String

    public init(reference: String, hypothesis: String) {
        self.reference = reference
        self.hypothesis = hypothesis
    }
}

public struct PunctuationQualityMetrics: Equatable {
    public let terminalPunctuationExpected: Int
    public let terminalPunctuationMatches: Int
    public let questionMarkExpected: Int
    public let questionMarkMatches: Int
    public let commaExpected: Int
    public let commaMatches: Int
    public let spokenPunctuationExpected: Int
    public let spokenPunctuationMatches: Int
    public let punctuationAwareWER: Double
    public let punctuationStrippedWER: Double

    public init(
        terminalPunctuationExpected: Int,
        terminalPunctuationMatches: Int,
        questionMarkExpected: Int,
        questionMarkMatches: Int,
        commaExpected: Int,
        commaMatches: Int,
        spokenPunctuationExpected: Int,
        spokenPunctuationMatches: Int,
        punctuationAwareWER: Double,
        punctuationStrippedWER: Double
    ) {
        self.terminalPunctuationExpected = terminalPunctuationExpected
        self.terminalPunctuationMatches = terminalPunctuationMatches
        self.questionMarkExpected = questionMarkExpected
        self.questionMarkMatches = questionMarkMatches
        self.commaExpected = commaExpected
        self.commaMatches = commaMatches
        self.spokenPunctuationExpected = spokenPunctuationExpected
        self.spokenPunctuationMatches = spokenPunctuationMatches
        self.punctuationAwareWER = punctuationAwareWER
        self.punctuationStrippedWER = punctuationStrippedWER
    }
}

public struct CommandRecognitionMetrics: Equatable {
    public let expectedCommandCount: Int
    public let builtInFalseNegatives: Int
    public let builtInFalsePositives: Int
    public let customDexFalseNegatives: Int
    public let customDexFalsePositives: Int
    public let commandOnlyExpectedCount: Int
    public let commandOnlyPreservedCount: Int

    public init(
        expectedCommandCount: Int,
        builtInFalseNegatives: Int,
        builtInFalsePositives: Int,
        customDexFalseNegatives: Int,
        customDexFalsePositives: Int,
        commandOnlyExpectedCount: Int,
        commandOnlyPreservedCount: Int
    ) {
        self.expectedCommandCount = expectedCommandCount
        self.builtInFalseNegatives = builtInFalseNegatives
        self.builtInFalsePositives = builtInFalsePositives
        self.customDexFalseNegatives = customDexFalseNegatives
        self.customDexFalsePositives = customDexFalsePositives
        self.commandOnlyExpectedCount = commandOnlyExpectedCount
        self.commandOnlyPreservedCount = commandOnlyPreservedCount
    }
}

public struct ClippingProxyMetrics: Equatable {
    public let expectedNonEmptyCount: Int
    public let emptyWhenExpectedCount: Int
    public let missingFirstWordCount: Int
    public let missingLastWordCount: Int
    public let suspiciouslyShortCount: Int
    public let finalWordTruncationProxyCount: Int

    public init(
        expectedNonEmptyCount: Int,
        emptyWhenExpectedCount: Int,
        missingFirstWordCount: Int,
        missingLastWordCount: Int,
        suspiciouslyShortCount: Int,
        finalWordTruncationProxyCount: Int
    ) {
        self.expectedNonEmptyCount = expectedNonEmptyCount
        self.emptyWhenExpectedCount = emptyWhenExpectedCount
        self.missingFirstWordCount = missingFirstWordCount
        self.missingLastWordCount = missingLastWordCount
        self.suspiciouslyShortCount = suspiciouslyShortCount
        self.finalWordTruncationProxyCount = finalWordTruncationProxyCount
    }
}

public enum RetryWinner: Equatable {
    case original
    case retry
    case tie
}

public struct RetrySelectionEvaluation: Equatable {
    public let winner: RetryWinner
    public let reason: String
    public let originalSuspiciousReason: String?
    public let retrySuspiciousReason: String?

    public init(
        winner: RetryWinner,
        reason: String,
        originalSuspiciousReason: String?,
        retrySuspiciousReason: String?
    ) {
        self.winner = winner
        self.reason = reason
        self.originalSuspiciousReason = originalSuspiciousReason
        self.retrySuspiciousReason = retrySuspiciousReason
    }
}

public struct RetryQualityMetrics: Equatable {
    public let originalBetterCount: Int
    public let retryBetterCount: Int
    public let ties: Int
    public let retryEmptyOriginalUsableCount: Int
    public let originalEmptyRetryUsableCount: Int
    public let commandPreservedByOriginalCount: Int
    public let commandRecoveredByRetryCount: Int
    public let repeatedTokenHallucinationCount: Int
    public let suspiciousTextCaseCount: Int

    public init(
        originalBetterCount: Int,
        retryBetterCount: Int,
        ties: Int,
        retryEmptyOriginalUsableCount: Int,
        originalEmptyRetryUsableCount: Int,
        commandPreservedByOriginalCount: Int,
        commandRecoveredByRetryCount: Int,
        repeatedTokenHallucinationCount: Int,
        suspiciousTextCaseCount: Int
    ) {
        self.originalBetterCount = originalBetterCount
        self.retryBetterCount = retryBetterCount
        self.ties = ties
        self.retryEmptyOriginalUsableCount = retryEmptyOriginalUsableCount
        self.originalEmptyRetryUsableCount = originalEmptyRetryUsableCount
        self.commandPreservedByOriginalCount = commandPreservedByOriginalCount
        self.commandRecoveredByRetryCount = commandRecoveredByRetryCount
        self.repeatedTokenHallucinationCount = repeatedTokenHallucinationCount
        self.suspiciousTextCaseCount = suspiciousTextCaseCount
    }
}

public enum VocabularyTermCategory: String, CaseIterable, Codable {
    case properNoun
    case acronym
    case codingTerm
    case frameworkAPI
    case userVocabulary
    case domainVocabulary
}

public struct VocabularyTerm: Equatable {
    public let phrase: String
    public let category: VocabularyTermCategory

    public init(phrase: String, category: VocabularyTermCategory) {
        self.phrase = phrase
        self.category = category
    }
}

public struct VocabularyCategoryScore: Equatable {
    public let expected: Int
    public let matched: Int

    public init(expected: Int, matched: Int) {
        self.expected = expected
        self.matched = matched
    }

    public var accuracy: Double {
        guard expected > 0 else { return 1.0 }
        return Double(matched) / Double(expected)
    }
}

public struct VocabularyAccuracyMetrics: Equatable {
    public let overallExpected: Int
    public let overallMatched: Int
    public let perCategory: [VocabularyTermCategory: VocabularyCategoryScore]

    public init(
        overallExpected: Int,
        overallMatched: Int,
        perCategory: [VocabularyTermCategory: VocabularyCategoryScore]
    ) {
        self.overallExpected = overallExpected
        self.overallMatched = overallMatched
        self.perCategory = perCategory
    }

    public var overallAccuracy: Double {
        guard overallExpected > 0 else { return 1.0 }
        return Double(overallMatched) / Double(overallExpected)
    }
}

public struct LatencyObservation: Equatable {
    public let transcriptionOnlyMs: Double
    public let endToEndMs: Double?
    public let retryOverheadMs: Double?

    public init(
        transcriptionOnlyMs: Double,
        endToEndMs: Double? = nil,
        retryOverheadMs: Double? = nil
    ) {
        self.transcriptionOnlyMs = transcriptionOnlyMs
        self.endToEndMs = endToEndMs
        self.retryOverheadMs = retryOverheadMs
    }
}

public struct LatencySummary: Equatable {
    public let count: Int
    public let averageMs: Double
    public let p95Ms: Double

    public init(count: Int, averageMs: Double, p95Ms: Double) {
        self.count = count
        self.averageMs = averageMs
        self.p95Ms = p95Ms
    }
}

public struct LatencyMetricsReport: Equatable {
    public let transcriptionOnly: LatencySummary
    public let endToEnd: LatencySummary?
    public let retryOverhead: LatencySummary?

    public init(
        transcriptionOnly: LatencySummary,
        endToEnd: LatencySummary?,
        retryOverhead: LatencySummary?
    ) {
        self.transcriptionOnly = transcriptionOnly
        self.endToEnd = endToEnd
        self.retryOverhead = retryOverhead
    }
}

public enum TranscriptionQualityMetrics {
    public static func punctuationMetrics(for pairs: [TranscriptionQualityPair]) -> PunctuationQualityMetrics {
        var terminalExpected = 0
        var terminalMatches = 0
        var questionExpected = 0
        var questionMatches = 0
        var commaExpected = 0
        var commaMatches = 0
        var spokenExpected = 0
        var spokenMatches = 0
        var awareWERValues: [Double] = []
        var strippedWERValues: [Double] = []

        for pair in pairs {
            let reference = pair.reference
            let hypothesis = pair.hypothesis

            if let expectedTerminal = terminalPunctuation(in: reference) {
                terminalExpected += 1
                if terminalPunctuation(in: hypothesis) == expectedTerminal {
                    terminalMatches += 1
                }
            }

            if terminalPunctuation(in: reference) == "?" {
                questionExpected += 1
                if terminalPunctuation(in: hypothesis) == "?" {
                    questionMatches += 1
                }
            }

            let expectedCommas = reference.filter { $0 == "," }.count
            let actualCommas = hypothesis.filter { $0 == "," }.count
            commaExpected += expectedCommas
            commaMatches += min(expectedCommas, actualCommas)

            let expectedSpoken = spokenPunctuationExpectationCount(in: reference)
            let actualSpoken = spokenPunctuationExpectationCount(in: hypothesis)
            spokenExpected += expectedSpoken
            spokenMatches += min(expectedSpoken, actualSpoken)

            awareWERValues.append(
                wordErrorRate(
                    reference: tokenize(reference, includePunctuation: true),
                    hypothesis: tokenize(hypothesis, includePunctuation: true)
                )
            )
            strippedWERValues.append(
                wordErrorRate(
                    reference: tokenize(reference, includePunctuation: false),
                    hypothesis: tokenize(hypothesis, includePunctuation: false)
                )
            )
        }

        return PunctuationQualityMetrics(
            terminalPunctuationExpected: terminalExpected,
            terminalPunctuationMatches: terminalMatches,
            questionMarkExpected: questionExpected,
            questionMarkMatches: questionMatches,
            commaExpected: commaExpected,
            commaMatches: commaMatches,
            spokenPunctuationExpected: spokenExpected,
            spokenPunctuationMatches: spokenMatches,
            punctuationAwareWER: average(awareWERValues),
            punctuationStrippedWER: average(strippedWERValues)
        )
    }

    public static func commandRecognitionMetrics(
        for pairs: [TranscriptionQualityPair],
        customCommands: [CustomCommand] = []
    ) -> CommandRecognitionMetrics {
        let processor = CommandProcessor()
        var expectedCommandCount = 0
        var builtInFalseNegatives = 0
        var builtInFalsePositives = 0
        var customFalseNegatives = 0
        var customFalsePositives = 0
        var commandOnlyExpected = 0
        var commandOnlyPreserved = 0

        for pair in pairs {
            let expected = classifyCommandSignals(pair.reference, processor: processor, customCommands: customCommands)
            let actual = classifyCommandSignals(pair.hypothesis, processor: processor, customCommands: customCommands)

            if expected.builtIn != .none || expected.customDexTriggered {
                expectedCommandCount += 1
            }

            if expected.builtIn != .none && actual.builtIn == .none {
                builtInFalseNegatives += 1
            }
            if expected.builtIn == .none && actual.builtIn != .none {
                builtInFalsePositives += 1
            }

            if expected.customDexTriggered && !actual.customDexTriggered {
                customFalseNegatives += 1
            }
            if !expected.customDexTriggered && actual.customDexTriggered {
                customFalsePositives += 1
            }

            if expected.commandOnly {
                commandOnlyExpected += 1
                if actual.commandOnly {
                    commandOnlyPreserved += 1
                }
            }
        }

        return CommandRecognitionMetrics(
            expectedCommandCount: expectedCommandCount,
            builtInFalseNegatives: builtInFalseNegatives,
            builtInFalsePositives: builtInFalsePositives,
            customDexFalseNegatives: customFalseNegatives,
            customDexFalsePositives: customFalsePositives,
            commandOnlyExpectedCount: commandOnlyExpected,
            commandOnlyPreservedCount: commandOnlyPreserved
        )
    }

    public static func clippingProxyMetrics(
        for pairs: [TranscriptionQualityPair],
        shortOutputRatioThreshold: Double = 0.6
    ) -> ClippingProxyMetrics {
        var expectedNonEmpty = 0
        var emptyWhenExpected = 0
        var missingFirstWord = 0
        var missingLastWord = 0
        var suspiciouslyShort = 0
        var finalWordTruncation = 0

        for pair in pairs {
            let expectedWords = tokenize(pair.reference, includePunctuation: false)
            let actualWords = tokenize(pair.hypothesis, includePunctuation: false)
            guard !expectedWords.isEmpty else { continue }

            expectedNonEmpty += 1
            if actualWords.isEmpty {
                emptyWhenExpected += 1
                continue
            }

            if expectedWords.first != actualWords.first {
                missingFirstWord += 1
            }
            if expectedWords.last != actualWords.last {
                missingLastWord += 1
            }
            if Double(actualWords.count) < Double(expectedWords.count) * shortOutputRatioThreshold {
                suspiciouslyShort += 1
            }

            if let expectedLast = expectedWords.last,
               let actualLast = actualWords.last,
               expectedLast != actualLast,
               expectedLast.hasPrefix(actualLast),
               actualLast.count >= 2 {
                finalWordTruncation += 1
            }
        }

        return ClippingProxyMetrics(
            expectedNonEmptyCount: expectedNonEmpty,
            emptyWhenExpectedCount: emptyWhenExpected,
            missingFirstWordCount: missingFirstWord,
            missingLastWordCount: missingLastWord,
            suspiciouslyShortCount: suspiciouslyShort,
            finalWordTruncationProxyCount: finalWordTruncation
        )
    }

    public static func evaluateRetrySelection(
        original: String,
        retry: String,
        audioDurationSeconds: Double,
        customCommands: [CustomCommand] = []
    ) -> RetrySelectionEvaluation {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRetry = retry.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedOriginal.isEmpty && !trimmedRetry.isEmpty {
            return RetrySelectionEvaluation(
                winner: .retry,
                reason: "original-empty-retry-usable",
                originalSuspiciousReason: nil,
                retrySuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedRetry, audioDurationSeconds: audioDurationSeconds)
            )
        }
        if !trimmedOriginal.isEmpty && trimmedRetry.isEmpty {
            return RetrySelectionEvaluation(
                winner: .original,
                reason: "retry-empty-original-usable",
                originalSuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedOriginal, audioDurationSeconds: audioDurationSeconds),
                retrySuspiciousReason: nil
            )
        }
        if trimmedOriginal.isEmpty && trimmedRetry.isEmpty {
            return RetrySelectionEvaluation(
                winner: .tie,
                reason: "both-empty",
                originalSuspiciousReason: nil,
                retrySuspiciousReason: nil
            )
        }

        let processor = CommandProcessor()
        let originalSignal = classifyCommandSignals(trimmedOriginal, processor: processor, customCommands: customCommands)
        let retrySignal = classifyCommandSignals(trimmedRetry, processor: processor, customCommands: customCommands)

        if originalSignal.hasAnyCommand && !retrySignal.hasAnyCommand {
            return RetrySelectionEvaluation(
                winner: .original,
                reason: "command-preserved-by-original",
                originalSuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedOriginal, audioDurationSeconds: audioDurationSeconds),
                retrySuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedRetry, audioDurationSeconds: audioDurationSeconds)
            )
        }
        if !originalSignal.hasAnyCommand && retrySignal.hasAnyCommand {
            return RetrySelectionEvaluation(
                winner: .retry,
                reason: "command-recovered-by-retry",
                originalSuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedOriginal, audioDurationSeconds: audioDurationSeconds),
                retrySuspiciousReason: SuspiciousTranscriptionHeuristic.reason(for: trimmedRetry, audioDurationSeconds: audioDurationSeconds)
            )
        }

        let originalSuspicious = SuspiciousTranscriptionHeuristic.reason(for: trimmedOriginal, audioDurationSeconds: audioDurationSeconds)
        let retrySuspicious = SuspiciousTranscriptionHeuristic.reason(for: trimmedRetry, audioDurationSeconds: audioDurationSeconds)

        if originalSuspicious == nil && retrySuspicious != nil {
            return RetrySelectionEvaluation(
                winner: .original,
                reason: "retry-suspicious-original-clean",
                originalSuspiciousReason: originalSuspicious,
                retrySuspiciousReason: retrySuspicious
            )
        }
        if originalSuspicious != nil && retrySuspicious == nil {
            return RetrySelectionEvaluation(
                winner: .retry,
                reason: "original-suspicious-retry-clean",
                originalSuspiciousReason: originalSuspicious,
                retrySuspiciousReason: retrySuspicious
            )
        }

        let originalWordCount = tokenize(trimmedOriginal, includePunctuation: false).count
        let retryWordCount = tokenize(trimmedRetry, includePunctuation: false).count
        if retryWordCount > originalWordCount {
            return RetrySelectionEvaluation(
                winner: .retry,
                reason: "retry-richer-word-coverage",
                originalSuspiciousReason: originalSuspicious,
                retrySuspiciousReason: retrySuspicious
            )
        }
        if originalWordCount > retryWordCount {
            return RetrySelectionEvaluation(
                winner: .original,
                reason: "original-richer-word-coverage",
                originalSuspiciousReason: originalSuspicious,
                retrySuspiciousReason: retrySuspicious
            )
        }

        return RetrySelectionEvaluation(
            winner: .tie,
            reason: "comparable-quality",
            originalSuspiciousReason: originalSuspicious,
            retrySuspiciousReason: retrySuspicious
        )
    }

    public static func retryQualityMetrics(_ evaluations: [RetrySelectionEvaluation]) -> RetryQualityMetrics {
        let originalBetter = evaluations.filter { $0.winner == .original }.count
        let retryBetter = evaluations.filter { $0.winner == .retry }.count
        let ties = evaluations.filter { $0.winner == .tie }.count

        let retryEmptyOriginalUsable = evaluations.filter { $0.reason == "retry-empty-original-usable" }.count
        let originalEmptyRetryUsable = evaluations.filter { $0.reason == "original-empty-retry-usable" }.count
        let commandPreservedByOriginal = evaluations.filter { $0.reason == "command-preserved-by-original" }.count
        let commandRecoveredByRetry = evaluations.filter { $0.reason == "command-recovered-by-retry" }.count
        let repeatedTokenCases = evaluations.filter {
            $0.originalSuspiciousReason == "contained a repeated token run" ||
            $0.retrySuspiciousReason == "contained a repeated token run"
        }.count
        let suspiciousCases = evaluations.filter {
            $0.originalSuspiciousReason != nil || $0.retrySuspiciousReason != nil
        }.count

        return RetryQualityMetrics(
            originalBetterCount: originalBetter,
            retryBetterCount: retryBetter,
            ties: ties,
            retryEmptyOriginalUsableCount: retryEmptyOriginalUsable,
            originalEmptyRetryUsableCount: originalEmptyRetryUsable,
            commandPreservedByOriginalCount: commandPreservedByOriginal,
            commandRecoveredByRetryCount: commandRecoveredByRetry,
            repeatedTokenHallucinationCount: repeatedTokenCases,
            suspiciousTextCaseCount: suspiciousCases
        )
    }

    public static func vocabularyAccuracyMetrics(
        reference: String,
        hypothesis: String,
        trackedTerms: [VocabularyTerm]
    ) -> VocabularyAccuracyMetrics {
        var expectedByCategory: [VocabularyTermCategory: Int] = [:]
        var matchedByCategory: [VocabularyTermCategory: Int] = [:]

        for term in trackedTerms {
            guard containsPhrase(term.phrase, in: reference) else { continue }
            expectedByCategory[term.category, default: 0] += 1
            if containsPhrase(term.phrase, in: hypothesis) {
                matchedByCategory[term.category, default: 0] += 1
            }
        }

        let allCategories = Set(expectedByCategory.keys).union(matchedByCategory.keys)
        var perCategory: [VocabularyTermCategory: VocabularyCategoryScore] = [:]
        for category in allCategories {
            let expected = expectedByCategory[category, default: 0]
            let matched = matchedByCategory[category, default: 0]
            perCategory[category] = VocabularyCategoryScore(expected: expected, matched: matched)
        }

        return VocabularyAccuracyMetrics(
            overallExpected: expectedByCategory.values.reduce(0, +),
            overallMatched: matchedByCategory.values.reduce(0, +),
            perCategory: perCategory
        )
    }

    public static func latencyMetricsReport(_ observations: [LatencyObservation]) -> LatencyMetricsReport {
        let transcriptionValues = observations.map(\.transcriptionOnlyMs)
        let endToEndValues = observations.compactMap(\.endToEndMs)
        let retryOverheadValues = observations.compactMap(\.retryOverheadMs)

        return LatencyMetricsReport(
            transcriptionOnly: summarize(transcriptionValues),
            endToEnd: endToEndValues.isEmpty ? nil : summarize(endToEndValues),
            retryOverhead: retryOverheadValues.isEmpty ? nil : summarize(retryOverheadValues)
        )
    }

    private struct CommandSignals {
        let builtIn: DictationCommand
        let customDexTriggered: Bool
        let commandOnly: Bool

        var hasAnyCommand: Bool {
            builtIn != .none || customDexTriggered
        }
    }

    private static func classifyCommandSignals(
        _ text: String,
        processor: CommandProcessor,
        customCommands: [CustomCommand]
    ) -> CommandSignals {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let (processed, builtIn) = processor.process(trimmed, customCommands: customCommands)
        let customDex = customDexCommandMatched(trimmed, customCommands: customCommands)
        let commandOnly = !trimmed.isEmpty && processed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return CommandSignals(builtIn: builtIn, customDexTriggered: customDex, commandOnly: commandOnly)
    }

    private static func customDexCommandMatched(_ text: String, customCommands: [CustomCommand]) -> Bool {
        guard !customCommands.isEmpty else { return false }
        let pattern = #"(?i)^dex\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let keywordRange = Range(match.range(at: 1), in: text) else {
            return false
        }
        let keyword = String(text[keywordRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return customCommands.contains { $0.keyword.lowercased() == keyword }
    }

    private static func tokenize(_ text: String, includePunctuation: Bool) -> [String] {
        let normalized = text.lowercased()
        if includePunctuation {
            guard let regex = try? NSRegularExpression(pattern: #"[a-z0-9_]+|[.,!?;:()"']"#) else { return [] }
            let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            return regex.matches(in: normalized, range: nsRange).compactMap {
                Range($0.range, in: normalized).map { String(normalized[$0]) }
            }
        }

        return normalized
            .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private static func wordErrorRate(reference: [String], hypothesis: [String]) -> Double {
        if reference.isEmpty {
            return hypothesis.isEmpty ? 0 : Double.infinity
        }

        var matrix = Array(
            repeating: Array(repeating: 0, count: hypothesis.count + 1),
            count: reference.count + 1
        )
        for i in 0...reference.count { matrix[i][0] = i }
        for j in 0...hypothesis.count { matrix[0][j] = j }

        if !reference.isEmpty && !hypothesis.isEmpty {
            for i in 1...reference.count {
                for j in 1...hypothesis.count {
                    let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j - 1] + cost
                    )
                }
            }
        }

        return Double(matrix[reference.count][hypothesis.count]) / Double(reference.count)
    }

    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = #"(?i)(?<![a-zA-Z0-9_])\#(escaped)(?![a-zA-Z0-9_])"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func terminalPunctuation(in text: String) -> Character? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, [".", "!", "?"].contains(last) else { return nil }
        return last
    }

    private static func spokenPunctuationExpectationCount(in text: String) -> Int {
        let lowered = text.lowercased()
        let tokens = [
            "question mark",
            "comma",
            "period",
            "full stop",
            "open parenthesis",
            "close parenthesis",
            "quote",
        ]
        return tokens.reduce(0) { partial, token in
            partial + occurrences(of: token, in: lowered)
        }
    }

    private static func occurrences(of token: String, in text: String) -> Int {
        guard !token.isEmpty else { return 0 }
        guard let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: token), options: .caseInsensitive) else {
            return 0
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.numberOfMatches(in: text, options: [], range: range)
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func summarize(_ values: [Double]) -> LatencySummary {
        guard !values.isEmpty else { return LatencySummary(count: 0, averageMs: 0, p95Ms: 0) }
        let sorted = values.sorted()
        let p95Index = Int(ceil((0.95 * Double(sorted.count)) - 1))
        let safeP95Index = max(0, min(sorted.count - 1, p95Index))
        return LatencySummary(
            count: sorted.count,
            averageMs: sorted.reduce(0, +) / Double(sorted.count),
            p95Ms: sorted[safeP95Index]
        )
    }
}
