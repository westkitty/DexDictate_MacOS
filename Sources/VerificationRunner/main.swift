import Foundation
import DexDictateKit

private struct Metrics {
    var checks = 0
    var failures = 0
}

private var metrics = Metrics()

private func pass(_ path: String, _ message: String) {
    metrics.checks += 1
    print("PASS [\(path)] \(message)")
}

private func fail(_ path: String, _ message: String) {
    metrics.checks += 1
    metrics.failures += 1
    print("FAIL [\(path)] \(message)")
}

private func check(_ path: String, _ condition: @autoclosure () -> Bool, _ message: String) {
    condition() ? pass(path, message) : fail(path, message)
}

private func checkEqual<T: Equatable>(_ path: String, _ actual: @autoclosure () -> T, _ expected: @autoclosure () -> T, _ message: String) {
    let a = actual()
    let e = expected()
    a == e ? pass(path, message) : fail(path, "\(message) (expected: \(e), got: \(a))")
}

private func section(_ title: String) {
    print("\n=== \(title) ===")
}

private func readSource(_ relativePath: String) -> String {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = cwd.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return content
}

private struct LCG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
    mutating func nextInt(_ upperBound: Int) -> Int {
        Int(next() % UInt64(max(1, upperBound)))
    }
}

@MainActor
private func runGreenPath() {
    let path = "green"
    section("Green Path")

    let settings = AppSettings.shared
    settings.restoreDefaults()
    settings.hasCompletedOnboarding = false
    settings.selectedEngine = .whisper

    check(path, settings.hasCompletedOnboarding == false, "onboarding starts incomplete")
    settings.hasCompletedOnboarding = true
    check(path, settings.hasCompletedOnboarding, "onboarding completion persists")
    checkEqual(path, settings.selectedEngine, .whisper, "engine remains local Whisper")

    let vocab = VocabularyManager()
    vocab.items = []
    vocab.add(original: "brb", replacement: "Be Right Back")
    let vocabResult = vocab.apply(to: "I will brb shortly")
    checkEqual(path, vocabResult, "I will Be Right Back shortly", "vocabulary substitution works")

    let cp = CommandProcessor()
    let (nlText, nlCommand) = cp.process("hello new line world")
    check(path, nlText.contains("\n"), "new line command emits newline")
    checkEqual(path, nlCommand, .newLine, "new line command flag set")

    let history = TranscriptionHistory()
    history.add("First")
    history.add("Second")
    checkEqual(path, history.items.first?.text ?? "", "Second", "history keeps most-recent first")
}

@MainActor
private func runGoldPath() {
    let path = "gold"
    section("Gold Path")

    let packageFile = readSource("Package.swift")
    check(path, packageFile.contains("deb1cb6a27256c7b01f5d3d2e7dc1dcc330b5d01"), "SwiftWhisper fast revision is pinned")

    let whisperService = readSource("Sources/DexDictateKit/Services/WhisperService.swift")
    check(path, whisperService.contains("params.greedy.best_of = 1"), "single-pass greedy decode is enabled")
    check(path, whisperService.contains("params.speed_up = true"), "phase-vocoder speed-up is enabled")
    check(path, whisperService.contains("params.temperature_inc = 0.0"), "fallback retries are disabled")
    check(path, whisperService.contains("params.max_tokens = 128"), "runaway decode is capped")
    check(path, whisperService.contains("params.suppress_non_speech_tokens = true"), "non-speech suppression is enabled")

    let profanity = ProfanityFilter.filter("damn")
    check(path, !profanity.isEmpty, "profanity filter remains functional")
}

@MainActor
private func runRedPath() {
    let path = "red"
    section("Red Path")

    let cp = CommandProcessor()
    let (emptyText, emptyCmd) = cp.process("")
    checkEqual(path, emptyText, "", "empty input returns empty output")
    checkEqual(path, emptyCmd, .none, "empty input has no command")

    let (spaceText, spaceCmd) = cp.process("   ")
    checkEqual(path, spaceText, "   ", "whitespace input remains unchanged")
    checkEqual(path, spaceCmd, .none, "whitespace input has no command")

    let (capsText, capsCmd) = cp.process("all caps")
    checkEqual(path, capsText, "", "command-only all-caps strips content")
    checkEqual(path, capsCmd, .none, "all-caps command returns none action after transform")

    let vocab = VocabularyManager()
    vocab.items = []
    vocab.add(original: "Hello (World)", replacement: "Hi Earth")
    let regexResult = vocab.apply(to: "I say Hello (World) to you")
    checkEqual(path, regexResult, "I say Hi Earth to you", "special characters are escaped safely")

    let history = TranscriptionHistory()
    history.add("")
    check(path, history.items.isEmpty, "empty history entries are ignored")
}

@MainActor
private func runBlackPath() {
    let path = "black"
    section("Black Path")

    checkEqual(path, AppSettings.TranscriptionEngineType.allCases.count, 1, "exactly one offline engine is exposed")
    checkEqual(path, AppSettings.TranscriptionEngineType.allCases.first, .whisper, "offline engine is Whisper")

    let tinyModelURL = Safety.resourceBundle.url(forResource: "tiny.en", withExtension: "bin")
    check(path, tinyModelURL != nil, "embedded tiny.en model exists in local bundle")

    let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sources = projectRoot.appendingPathComponent("Sources")
    let bannedTokens = ["URLSession", "NSURLConnection", "NWConnection", "Alamofire"]
    var bannedHits: [String] = []

    if let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift",
                  fileURL.path.contains("/Sources/VerificationRunner/") == false,
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for token in bannedTokens where content.contains(token) {
                bannedHits.append("\(fileURL.lastPathComponent):\(token)")
            }
        }
    }

    check(path, bannedHits.isEmpty, "no online networking APIs detected in Sources")
}

@MainActor
private func runSkeletonPath() {
    let path = "skeleton"
    section("Skeleton Path")

    let settings = AppSettings.shared
    settings.restoreDefaults()
    settings.showFloatingHUD = false
    settings.autoPaste = false
    settings.playStartSound = false
    settings.playStopSound = false
    settings.silenceTimeout = 0

    check(path, settings.showFloatingHUD == false, "HUD can be disabled")
    check(path, settings.autoPaste == false, "auto-paste can be disabled")
    check(path, settings.playStartSound == false && settings.playStopSound == false, "audio cues can be disabled")
    check(path, settings.silenceTimeout == 0, "silence timeout can be disabled")
}

@MainActor
private func runEdgeCasePath() {
    let path = "edge"
    section("Edge Case Path")

    let history = TranscriptionHistory()
    for i in 0..<75 {
        history.add("line-\(i)")
    }
    checkEqual(path, history.items.count, 50, "history is capped at 50 items")
    checkEqual(path, history.items.first?.text ?? "", "line-74", "history keeps newest entry after cap")
    checkEqual(path, history.items.last?.text ?? "", "line-25", "history trims oldest entry after cap")

    let vocab = VocabularyManager()
    vocab.items = []
    vocab.add(original: "test", replacement: "TEST")
    vocab.add(original: "testing", replacement: "TESTING")
    let overlap = vocab.apply(to: "testing 1 2 3")
    checkEqual(path, overlap, "TESTING 1 2 3", "overlapping vocabulary terms respect word boundaries")

    let cp = CommandProcessor()
    let (scratchedText, scratchedCmd) = cp.process("Hello world scratch that")
    checkEqual(path, scratchedText, "", "scratch-that suffix drops current segment")
    checkEqual(path, scratchedCmd, .deleteLastSentence, "scratch-that suffix sets delete command")
}

@MainActor
private func runSurprisePath() {
    let path = "surprise"
    section("Surprise Path")

    let cp = CommandProcessor()
    let vocab = VocabularyManager()
    vocab.items = [VocabularyItem(original: "foo", replacement: "bar")]
    var rng = LCG(seed: 42)
    let tokenPool = ["foo", "new", "line", "scratch", "that", "all", "caps", "x", "y", "z", "123"]

    var processedCount = 0
    for _ in 0..<200 {
        var words: [String] = []
        let count = 1 + rng.nextInt(12)
        for _ in 0..<count {
            words.append(tokenPool[rng.nextInt(tokenPool.count)])
        }
        let phrase = words.joined(separator: " ")
        let (commanded, _) = cp.process(phrase)
        let replaced = vocab.apply(to: commanded)
        if !replaced.isEmpty {
            processedCount += 1
        }
    }

    check(path, processedCount > 0, "fuzz run processed non-empty outputs without crashing")
}

@MainActor
private func runWonderPath() {
    let path = "wonder"
    section("Wonder Path")

    let appUI = readSource("Sources/DexDictate/DexDictateApp.swift")
    check(path, appUI.contains("AppIcon.appiconset/icon"), "main UI includes app icon watermark asset")
    check(path, appUI.contains("Text(\"DEXDICTATE\")"), "main UI includes visible text watermark")

    let hudUI = readSource("Sources/DexDictate/FloatingHUD.swift")
    check(path, hudUI.contains("AppIcon.appiconset/icon"), "floating HUD includes watermark asset")
    check(path, hudUI.contains("Text(\"DEX\")"), "floating HUD includes visible watermark text")

    let engineSource = readSource("Sources/DexDictateKit/TranscriptionEngine.swift")
    check(path, engineSource.contains("defer {\n            state = .ready"), "transcription state machine has ready-state defer guard")
}

@MainActor
private func runAllPaths() {
    runGreenPath()
    runGoldPath()
    runRedPath()
    runBlackPath()
    runSkeletonPath()
    runEdgeCasePath()
    runSurprisePath()
    runWonderPath()

    section("Summary")
    print("Checks: \(metrics.checks)")
    print("Failures: \(metrics.failures)")

    if metrics.failures == 0 {
        print("Result: PASS")
        exit(0)
    } else {
        print("Result: FAIL")
        exit(1)
    }
}

Task { @MainActor in
    runAllPaths()
}

dispatchMain()
