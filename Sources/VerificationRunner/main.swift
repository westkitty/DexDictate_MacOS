import Foundation
import AVFoundation
import DexDictateKit

private struct Metrics {
    var checks = 0
    var failures = 0
}

private struct BenchmarkItem {
    let fileName: String
    let fileURL: URL
    let referenceText: String
}

private struct CorpusSummary: Codable {
    let processedFiles: Int
    let averageWER: Double
    let averageLatencyMs: Double
    let p95LatencyMs: Double
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

private func computeWER(reference: String, hypothesis: String) -> Double {
    func normalize(_ text: String) -> [String] {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    let ref = normalize(reference)
    let hyp = normalize(hypothesis)

    if ref.isEmpty {
        return hyp.isEmpty ? 0 : Double.infinity
    }

    var matrix = Array(repeating: Array(repeating: 0, count: hyp.count + 1), count: ref.count + 1)
    for i in 0...ref.count { matrix[i][0] = i }
    for j in 0...hyp.count { matrix[0][j] = j }

    if !ref.isEmpty && !hyp.isEmpty {
        for i in 1...ref.count {
            for j in 1...hyp.count {
                let cost = ref[i - 1] == hyp[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
    }

    return Double(matrix[ref.count][hyp.count]) / Double(ref.count)
}

private func percentile(_ values: [Double], p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = Int(ceil((p * Double(sorted.count)) - 1))
    return sorted[max(0, min(sorted.count - 1, index))]
}

private func loadBenchmarkCorpus(from directory: URL) throws -> [BenchmarkItem] {
    let manifestURL = directory.appendingPathComponent("benchmark_manifest.json")
    let transcriptsURL = directory.appendingPathComponent("transcripts.json")

    if let data = try? Data(contentsOf: manifestURL),
       let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let prompts = manifest["prompts"] as? [[String: Any]] {
        let capturedEntries = (manifest["capturedEntries"] as? [[String: Any]]) ?? []
        let capturedNames = Set(capturedEntries.compactMap { $0["fileName"] as? String })
        let items = prompts.compactMap { prompt -> BenchmarkItem? in
            guard let fileName = prompt["fileName"] as? String,
                  let referenceText = prompt["referenceText"] as? String else {
                return nil
            }
            if !capturedNames.isEmpty && !capturedNames.contains(fileName) {
                return nil
            }
            return BenchmarkItem(
                fileName: fileName,
                fileURL: directory.appendingPathComponent(fileName),
                referenceText: referenceText
            )
        }
        if !items.isEmpty {
            return items
        }
    }

    let transcriptsData = try Data(contentsOf: transcriptsURL)
    let transcripts = try JSONDecoder().decode([String: String].self, from: transcriptsData)
    return transcripts.map {
        BenchmarkItem(
            fileName: $0.key,
            fileURL: directory.appendingPathComponent($0.key),
            referenceText: $0.value
        )
    }.sorted(by: { $0.fileName < $1.fileName })
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
    _ = history.removeMostRecent()
    check(path, history.canRestoreLastRemovedItem, "history retains undo state after deletion")
    check(path, history.restoreMostRecentRemoval(), "history undo restores the removed entry")
    checkEqual(path, history.items.first?.text ?? "", "Second", "history undo restores newest entry in place")
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
    settings.copyOnlyInSensitiveFields = false
    settings.playStartSound = false
    settings.playStopSound = false
    settings.silenceTimeout = 0

    check(path, settings.showFloatingHUD == false, "HUD can be disabled")
    check(path, settings.autoPaste == false, "auto-paste can be disabled")
    check(path, settings.copyOnlyInSensitiveFields == false, "secure-context copy-only can be disabled")
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
    check(path, appUI.contains("currentWatermarkAsset"), "main UI uses provider-driven watermark state")
    check(path, appUI.contains("Text(\"DEXDICTATE\")"), "main UI includes visible text watermark")
    check(path, appUI.contains("FlavorTickerView"), "main UI includes the flavor ticker under the title")

    let hudUI = readSource("Sources/DexDictate/FloatingHUD.swift")
    check(path, hudUI.contains("currentWatermarkAsset"), "floating HUD uses provider-driven watermark state")
    check(path, hudUI.contains("Text(\"DEX\")"), "floating HUD includes visible watermark text")

    let profileSource = readSource("Sources/DexDictateKit/Profiles/WatermarkAssetProvider.swift")
    check(path, profileSource.contains("DexDictate_onboarding__welcome__variant_a.png"), "watermark provider includes the Standard random-cycle pool")
    check(path, profileSource.contains("DexDictate_random_cycle__standing_pose__variant_c.png"), "watermark provider includes curated Standard PNG runtime assets")
    check(path, !profileSource.contains("\"dexdictate-icon-standard-11.png\""), "watermark provider no longer uses the old Standard icon pool for the standard profile")
    check(path, !profileSource.contains("dexdictate-icon-standard-sheet-01.png"), "watermark provider excludes standard sheet source files")
    check(path, profileSource.contains("dexdictate-icon-aussie-02.png"), "watermark provider includes Aussie runtime pool")

    let benchmarkCorpus = BenchmarkCorpus.strictPrompts
    checkEqual(path, benchmarkCorpus.count, 30, "strict benchmark corpus is present")
    checkEqual(path, Set(benchmarkCorpus.map(\.fileName)).count, benchmarkCorpus.count, "benchmark corpus file names are unique")
    checkEqual(path, BenchmarkCorpus.strictTranscriptMap.count, benchmarkCorpus.count, "benchmark transcript map matches corpus size")

    let engineSource = readSource("Sources/DexDictateKit/TranscriptionEngine.swift")
    let lifecycleSource = readSource("Sources/DexDictateKit/EngineLifecycle.swift")
    let settingsSource = readSource("Sources/DexDictateKit/Settings/AppSettings.swift")
    let capturePolicySource = readSource("Sources/DexDictateKit/Capture/AudioInputSelectionPolicy.swift")
    let outputCoordinatorSource = readSource("Sources/DexDictateKit/Output/OutputCoordinator.swift")
    let permissionsSource = readSource("Sources/DexDictateKit/Permissions/PermissionManager.swift")
    check(path, lifecycleSource.contains("case (.transcribing, .transcriptionCompleted):"), "explicit lifecycle maps transcription completion back to ready")
    check(path, engineSource.contains("defer {\n            _ = applyLifecycle(.transcriptionCompleted"), "transcription completion still returns the engine to ready through the lifecycle model")
    check(path, engineSource.contains("outputCoordinator.deliver("), "engine routes output through explicit output coordination")
    check(path, engineSource.contains("applyEffective(to:"), "engine applies effective layered vocabulary")
    check(path, settingsSource.contains("copyOnlyInSensitiveFields"), "settings expose secure-context copy-only control")
    check(path, settingsSource.contains("localizationMode_v1"), "settings expose persisted profile mode")
    check(path, capturePolicySource.contains("System Default"), "audio device failover preserves system-default fallback")
    check(path, !capturePolicySource.isEmpty && !outputCoordinatorSource.isEmpty && !permissionsSource.isEmpty, "DexDictateKit is split into capture, output, and permissions subdomains")
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

@MainActor
private func runBenchmark(path: String, modelName: String) async {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        print("BENCHMARK_FAIL: Audio file not found at \(path)")
        exit(1)
    }
    
    // Load audio
    // Load audio
    guard let file = try? AVAudioFile(forReading: url) else {
        print("BENCHMARK_FAIL: Could not open audio file at \(path)")
        exit(1)
    }
    
    let frameCount = AVAudioFrameCount(file.length)
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        print("BENCHMARK_FAIL: Could not instantiate PCM buffer")
        exit(1)
    }
    
    // In Swift AVFoundation, you must set frameLength to the capacity you wish to read
    // before calling read(into:), otherwise it reads 0 frames.
    buffer.frameLength = frameCount
    
    do {
        try file.read(into: buffer)
    } catch {
        print("BENCHMARK_FAIL: Read error")
        exit(1)
    }
    
    guard let floatData = buffer.floatChannelData?[0] else {
        print("BENCHMARK_FAIL: No float channel data")
        exit(1)
    }
    
    let nativeSamples = Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
    let whisperSamples = AudioResampler.resampleToWhisper(nativeSamples, fromRate: file.fileFormat.sampleRate)
    
    print("DEBUG_AUDIO: frameCount=\(frameCount), frameLength=\(buffer.frameLength), native=\(nativeSamples.count), whisper=\(whisperSamples.count)")
    
    let whisper = WhisperService()
    guard let modelURL = Safety.resourceBundle.url(forResource: modelName, withExtension: "bin") else {
        print("BENCHMARK_FAIL: Could not locate \(modelName).bin")
        exit(1)
    }
    whisper.loadModel(url: modelURL)
    
    let start = Date()
    
    await withCheckedContinuation { continuation in
        whisper.ontranscriptionComplete = { text in
            let end = Date()
            let ms = Int(end.timeIntervalSince(start) * 1000)
            print("BENCHMARK_RESULT:\(text.trimmingCharacters(in: .whitespacesAndNewlines))")
            print("BENCHMARK_LATENCY_MS:\(ms)")
            continuation.resume()
        }
        _ = whisper.transcribe(audioFrames: whisperSamples)
    }
    exit(0)
}

@MainActor
private func runBenchmarkCorpus(
    corpusPath: String,
    modelName: String,
    decodeProfile: ExperimentFlags.DecodeProfile,
    utteranceEndPreset: String,
    jsonOutputPath: String?,
    csvOutputPath: String?,
    gatePath: String?
) async {
    let directory = URL(fileURLWithPath: corpusPath)

    let items: [BenchmarkItem]
    do {
        items = try loadBenchmarkCorpus(from: directory)
    } catch {
        print("BENCHMARK_FAIL: Could not load corpus at \(corpusPath)")
        exit(1)
    }

    guard let modelURL = Safety.resourceBundle.url(forResource: modelName, withExtension: "bin")
        ?? WhisperModelCatalog.shared.descriptor(for: modelName)?.url else {
        print("BENCHMARK_FAIL: Could not locate \(modelName).bin")
        exit(1)
    }

    ExperimentFlags.whisperDecodeProfile = decodeProfile
    if let preset = AppSettings.UtteranceEndPreset.allCases.first(where: { $0.rawValue.lowercased() == utteranceEndPreset.lowercased() }) {
        let settings = AppSettings.shared
        settings.utteranceEndPreset = preset
        ExperimentFlags.applyRuntimeSettings(settings)
    }

    let whisper = WhisperService()
    whisper.loadModel(url: modelURL, modelID: modelName, decodeProfile: decodeProfile)

    var latencies: [Double] = []
    var wers: [Double] = []
    var csvLines = ["file_name,reference,hypothesis,latency_ms,wer"]

    for item in items {
        guard FileManager.default.fileExists(atPath: item.fileURL.path) else { continue }
        guard let file = try? AVAudioFile(forReading: item.fileURL) else { continue }

        let frameCount = AVAudioFrameCount(file.length)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            continue
        }

        buffer.frameLength = frameCount
        try? file.read(into: buffer)
        guard let floatData = buffer.floatChannelData?[0] else { continue }

        let nativeSamples = Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
        var trimmedSamples = nativeSamples
        if ExperimentFlags.enableTrailingTrim {
            trimmedSamples = AudioResampler.trimTrailingSilenceCalibrated(
                nativeSamples,
                sampleRate: file.fileFormat.sampleRate,
                minimumSilenceMs: ExperimentFlags.trailingTrimMinimumSilenceMs,
                padMs: ExperimentFlags.trailingTrimPadMs
            )
        }
        let whisperSamples = AudioResampler.resampleToWhisper(trimmedSamples, fromRate: file.fileFormat.sampleRate)

        let start = Date()
        let hypothesis: String = await withCheckedContinuation { continuation in
            whisper.ontranscriptionComplete = { text in
                continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            _ = whisper.transcribe(audioFrames: whisperSamples)
        }
        let latencyMs = Double(Int(Date().timeIntervalSince(start) * 1000))
        let wer = computeWER(reference: item.referenceText, hypothesis: hypothesis)
        latencies.append(latencyMs)
        wers.append(wer)
        csvLines.append("\"\(item.fileName)\",\"\(item.referenceText.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(hypothesis.replacingOccurrences(of: "\"", with: "\"\""))\",\(Int(latencyMs)),\(wer)")
    }

    let averageWER = wers.isEmpty ? 0 : wers.reduce(0, +) / Double(wers.count)
    let averageLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
    let p95Latency = percentile(latencies, p: 0.95)
    let summary = ModelBenchmarkResult(
        hardwareFingerprint: BenchmarkEnvironment.hardwareFingerprint(),
        appVersion: BenchmarkEnvironment.appVersion(),
        modelID: modelName,
        modelIdentity: whisper.loadedModelURL.map { (try? WhisperModelCatalog.sha256(for: $0)) ?? "\($0.lastPathComponent)" } ?? modelName,
        decodeProfile: decodeProfile.cliName,
        utteranceEndPreset: AppSettings.shared.utteranceEndPreset.rawValue,
        processedFiles: latencies.count,
        averageWER: averageWER,
        averageLatencyMs: averageLatency,
        p95LatencyMs: p95Latency,
        completedAt: Date()
    )

    if let jsonOutputPath {
        let url = URL(fileURLWithPath: jsonOutputPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(summary) {
            try? data.write(to: url, options: .atomic)
        }
    }

    if let csvOutputPath {
        try? csvLines.joined(separator: "\n").appending("\n").write(to: URL(fileURLWithPath: csvOutputPath), atomically: true, encoding: .utf8)
    }

    print("BENCHMARK_CORPUS_FILES:\(summary.processedFiles)")
    print("BENCHMARK_CORPUS_AVG_WER:\(summary.averageWER)")
    print("BENCHMARK_CORPUS_AVG_LATENCY_MS:\(summary.averageLatencyMs)")
    print("BENCHMARK_CORPUS_P95_LATENCY_MS:\(summary.p95LatencyMs)")

    if let gatePath,
       let gateData = try? Data(contentsOf: URL(fileURLWithPath: gatePath)),
       let baseline = try? JSONDecoder().decode(BenchmarkBaseline.self, from: gateData) {
        let passed = summary.averageWER <= baseline.thresholds.maxAverageWER &&
            summary.p95LatencyMs <= baseline.thresholds.maxP95LatencyMs
        print("BENCHMARK_GATE_RESULT:\(passed ? "PASS" : "FAIL")")
        exit(passed ? 0 : 2)
    }

    exit(0)
}

Task { @MainActor in
    let args = ProcessInfo.processInfo.arguments
    var modelName = "tiny.en"
    var decodeProfile: ExperimentFlags.DecodeProfile = .accuracy
    var utteranceEndPreset = "stable"
    var jsonOutputPath: String?
    var csvOutputPath: String?
    var gatePath: String?

    if let modelIdx = args.firstIndex(of: "--model"), modelIdx + 1 < args.count {
        modelName = args[modelIdx + 1]
    }
    if let profileIdx = args.firstIndex(of: "--decode-profile"), profileIdx + 1 < args.count {
        switch args[profileIdx + 1].lowercased() {
        case "speed":
            decodeProfile = .speed
        case "balanced":
            decodeProfile = .balanced
        default:
            decodeProfile = .accuracy
        }
    }
    if let presetIdx = args.firstIndex(of: "--utterance-end-preset"), presetIdx + 1 < args.count {
        utteranceEndPreset = args[presetIdx + 1]
    }
    if let jsonIdx = args.firstIndex(of: "--json-output"), jsonIdx + 1 < args.count {
        jsonOutputPath = args[jsonIdx + 1]
    }
    if let csvIdx = args.firstIndex(of: "--csv-output"), csvIdx + 1 < args.count {
        csvOutputPath = args[csvIdx + 1]
    }
    if let gateIdx = args.firstIndex(of: "--gate-file"), gateIdx + 1 < args.count {
        gatePath = args[gateIdx + 1]
    }

    if let idx = args.firstIndex(of: "--benchmark-corpus"), idx + 1 < args.count {
        await runBenchmarkCorpus(
            corpusPath: args[idx + 1],
            modelName: modelName,
            decodeProfile: decodeProfile,
            utteranceEndPreset: utteranceEndPreset,
            jsonOutputPath: jsonOutputPath,
            csvOutputPath: csvOutputPath,
            gatePath: gatePath
        )
    } else if let idx = args.firstIndex(of: "--benchmark"), idx + 1 < args.count {
        ExperimentFlags.whisperDecodeProfile = decodeProfile
        await runBenchmark(path: args[idx + 1], modelName: modelName)
    } else {
        runAllPaths()
    }
}

dispatchMain()
