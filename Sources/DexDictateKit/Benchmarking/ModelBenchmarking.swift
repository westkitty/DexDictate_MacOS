import Foundation
import Combine

public struct VocabularyCorrectionDraft: Equatable {
    public var incorrectPhrase: String
    public var correctPhrase: String

    public init(incorrectPhrase: String = "", correctPhrase: String = "") {
        self.incorrectPhrase = incorrectPhrase
        self.correctPhrase = correctPhrase
    }

    public var isValid: Bool {
        !incorrectPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !correctPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct LastUtteranceSnapshot: Equatable {
    public let rawSamples: [Float]
    public let sourceSampleRate: Double
    public let originalTranscript: String
    public let sourceHistoryItemID: UUID?
    public let createdAt: Date

    public init(
        rawSamples: [Float],
        sourceSampleRate: Double,
        originalTranscript: String,
        sourceHistoryItemID: UUID?,
        createdAt: Date = Date()
    ) {
        self.rawSamples = rawSamples
        self.sourceSampleRate = sourceSampleRate
        self.originalTranscript = originalTranscript
        self.sourceHistoryItemID = sourceHistoryItemID
        self.createdAt = createdAt
    }

    public var hasAudio: Bool { !rawSamples.isEmpty }
}

public struct BenchmarkGateThresholds: Codable, Equatable {
    public let maxAverageWER: Double
    public let maxP95LatencyMs: Double
    public let minImprovementWERRatio: Double
    public let maxP95LatencyRegressionRatio: Double

    public init(
        maxAverageWER: Double,
        maxP95LatencyMs: Double,
        minImprovementWERRatio: Double,
        maxP95LatencyRegressionRatio: Double
    ) {
        self.maxAverageWER = maxAverageWER
        self.maxP95LatencyMs = maxP95LatencyMs
        self.minImprovementWERRatio = minImprovementWERRatio
        self.maxP95LatencyRegressionRatio = maxP95LatencyRegressionRatio
    }
}

public struct BenchmarkBaseline: Codable, Equatable {
    public let benchmarkVersion: String
    public let thresholds: BenchmarkGateThresholds
    public let stableModelID: String

    public init(benchmarkVersion: String, thresholds: BenchmarkGateThresholds, stableModelID: String) {
        self.benchmarkVersion = benchmarkVersion
        self.thresholds = thresholds
        self.stableModelID = stableModelID
    }

    public static func loadCommittedBaseline() -> BenchmarkBaseline? {
        let candidateURLs: [URL?] = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("benchmark_baseline.json"),
            Bundle.main.resourceURL?.appendingPathComponent("benchmark_baseline.json"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("benchmark_baseline.json")
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            guard let data = try? Data(contentsOf: url),
                  let baseline = try? JSONDecoder().decode(BenchmarkBaseline.self, from: data) else {
                continue
            }
            return baseline
        }

        return nil
    }
}

public struct ModelBenchmarkResult: Codable, Equatable, Identifiable {
    public var id: String {
        "\(hardwareFingerprint)|\(appVersion)|\(modelID)|\(modelIdentity)|\(decodeProfile)|\(utteranceEndPreset)"
    }

    public let hardwareFingerprint: String
    public let appVersion: String
    public let modelID: String
    public let modelIdentity: String
    public let decodeProfile: String
    public let utteranceEndPreset: String
    public let processedFiles: Int
    public let averageWER: Double
    public let averageLatencyMs: Double
    public let p95LatencyMs: Double
    public let completedAt: Date

    public init(
        hardwareFingerprint: String,
        appVersion: String,
        modelID: String,
        modelIdentity: String,
        decodeProfile: String,
        utteranceEndPreset: String,
        processedFiles: Int,
        averageWER: Double,
        averageLatencyMs: Double,
        p95LatencyMs: Double,
        completedAt: Date
    ) {
        self.hardwareFingerprint = hardwareFingerprint
        self.appVersion = appVersion
        self.modelID = modelID
        self.modelIdentity = modelIdentity
        self.decodeProfile = decodeProfile
        self.utteranceEndPreset = utteranceEndPreset
        self.processedFiles = processedFiles
        self.averageWER = averageWER
        self.averageLatencyMs = averageLatencyMs
        self.p95LatencyMs = p95LatencyMs
        self.completedAt = completedAt
    }
}

public struct BenchmarkPromotionDecision: Equatable {
    public let shouldPromote: Bool
    public let reason: String
}

public enum BenchmarkProgressState: Equatable {
    case queued
    case running
    case cached
    case completed
    case failed
    case cancelled
}

public struct BenchmarkProgressEntry: Identifiable, Equatable {
    public let id: String
    public let modelID: String
    public let state: BenchmarkProgressState
    public let detail: String

    public init(modelID: String, state: BenchmarkProgressState, detail: String) {
        self.id = modelID
        self.modelID = modelID
        self.state = state
        self.detail = detail
    }
}

public enum BenchmarkStatus: Equatable {
    case idle
    case scheduled
    case running(modelID: String)
    case paused
    case cancelled
    case unavailable(String)
    case completed(String)

    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .scheduled:
            return "Scheduled"
        case .running(let modelID):
            return "Benchmarking \(modelID)"
        case .paused:
            return "Paused for dictation"
        case .cancelled:
            return "Cancelled"
        case .unavailable(let message):
            return message
        case .completed(let message):
            return message
        }
    }

    public var isBusy: Bool {
        if case .running = self {
            return true
        }
        return self == .scheduled
    }
}

public enum BenchmarkPromotionPolicy {
    public static func shouldPromote(
        candidate: ModelBenchmarkResult,
        current: ModelBenchmarkResult,
        thresholds: BenchmarkGateThresholds
    ) -> BenchmarkPromotionDecision {
        guard current.averageWER > 0 else {
            return BenchmarkPromotionDecision(shouldPromote: false, reason: "Current benchmark result is incomplete.")
        }

        let werImprovement = (current.averageWER - candidate.averageWER) / current.averageWER
        let latencyRegression = current.p95LatencyMs == 0
            ? 0
            : max(0, (candidate.p95LatencyMs - current.p95LatencyMs) / current.p95LatencyMs)

        guard werImprovement >= thresholds.minImprovementWERRatio else {
            return BenchmarkPromotionDecision(shouldPromote: false, reason: "WER improvement was below the promotion threshold.")
        }

        guard latencyRegression <= thresholds.maxP95LatencyRegressionRatio else {
            return BenchmarkPromotionDecision(shouldPromote: false, reason: "Latency regression exceeded the promotion threshold.")
        }

        return BenchmarkPromotionDecision(shouldPromote: true, reason: "Candidate cleared the local promotion thresholds.")
    }
}

public struct BenchmarkEnvironment {
    public static func hardwareFingerprint() -> String {
        let processInfo = ProcessInfo.processInfo
        let version = processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)-cpu\(processInfo.activeProcessorCount)"
    }

    public static func appVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let versionURL = cwdURL.appendingPathComponent("VERSION")
        if let version = try? String(contentsOf: versionURL, encoding: .utf8) {
            return version.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "dev"
    }
}

@MainActor
public final class BenchmarkResultsStore: ObservableObject {
    public static let shared = BenchmarkResultsStore()

    @Published public private(set) var results: [ModelBenchmarkResult] = []
    private let fileManager = FileManager.default

    public init() {
        reload()
    }

    public func reload() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ModelBenchmarkResult].self, from: data) else {
            results = []
            return
        }
        results = decoded
    }

    public func upsert(_ result: ModelBenchmarkResult) {
        var current = results
        current.removeAll(where: { $0.id == result.id })
        current.append(result)
        current.sort(by: { $0.completedAt > $1.completedAt })
        results = current
        persist()
    }

    public func latestResult(for model: WhisperModelDescriptor, settings: AppSettings = .shared) -> ModelBenchmarkResult? {
        let identity = model.sha256 ?? "\(model.fileSizeBytes)"
        return results.first(where: {
            $0.modelID == model.id &&
            $0.modelIdentity == identity &&
            $0.hardwareFingerprint == BenchmarkEnvironment.hardwareFingerprint() &&
            $0.appVersion == BenchmarkEnvironment.appVersion() &&
            $0.utteranceEndPreset == settings.utteranceEndPreset.rawValue
        })
    }

    public func latestResultsForCurrentEnvironment(settings: AppSettings = .shared) -> [ModelBenchmarkResult] {
        results.filter {
            $0.hardwareFingerprint == BenchmarkEnvironment.hardwareFingerprint() &&
            $0.appVersion == BenchmarkEnvironment.appVersion() &&
            $0.utteranceEndPreset == settings.utteranceEndPreset.rawValue
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(results) else { return }
        try? fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: .atomic)
    }

    private var storeURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("DexDictate", isDirectory: true)
            .appendingPathComponent("BenchmarkResults", isDirectory: true)
            .appendingPathComponent("model_benchmarks.json")
    }
}

@MainActor
public final class AdaptiveBenchmarkController: ObservableObject {
    @Published public private(set) var status: BenchmarkStatus = .idle
    @Published public private(set) var progressEntries: [BenchmarkProgressEntry] = []

    private weak var engine: TranscriptionEngine?
    private var benchmarkTask: Task<Void, Never>?
    private var helperProcess: Process?
    private var cancellables = Set<AnyCancellable>()
    private var lastDictationEndAt: Date?
    private var helperTerminationWasRequested = false
    private let helperURLResolver: (() -> URL?)?
    private let catalogProvider: () -> WhisperModelCatalog
    private let resultsStoreProvider: () -> BenchmarkResultsStore
    private let initialDelayNs: UInt64
    private let postDictationDelayNs: UInt64

    public init(
        helperURLResolver: (() -> URL?)? = nil,
        catalogProvider: (() -> WhisperModelCatalog)? = nil,
        resultsStoreProvider: (() -> BenchmarkResultsStore)? = nil,
        initialDelayNs: UInt64 = 120_000_000_000,
        postDictationDelayNs: UInt64 = 30_000_000_000
    ) {
        self.helperURLResolver = helperURLResolver
        self.catalogProvider = catalogProvider ?? { WhisperModelCatalog.shared }
        self.resultsStoreProvider = resultsStoreProvider ?? { BenchmarkResultsStore.shared }
        self.initialDelayNs = initialDelayNs
        self.postDictationDelayNs = postDictationDelayNs
    }

    public func start(engine: TranscriptionEngine) {
        self.engine = engine
        observe(engine: engine)
        scheduleIfNeeded()
    }

    public func cancelForDictation() {
        benchmarkTask?.cancel()
        benchmarkTask = nil
        helperTerminationWasRequested = true
        helperProcess?.terminate()
        helperProcess = nil
        progressEntries = progressEntries.map {
            switch $0.state {
            case .running, .queued:
                return BenchmarkProgressEntry(modelID: $0.modelID, state: .cancelled, detail: "Cancelled for dictation")
            case .cached, .completed, .failed, .cancelled:
                return $0
            }
        }
        status = .cancelled
    }

    public func runBenchmarksNow() {
        guard let engine else { return }

        benchmarkTask?.cancel()
        benchmarkTask = nil

        guard engine.state == .ready || engine.state == .stopped else {
            status = .paused
            return
        }

        guard resolveVerificationRunnerURL() != nil else {
            status = .unavailable("VerificationRunner helper unavailable")
            return
        }

        prepareProgressEntries(for: modelsForCurrentRun())
        status = .scheduled
        benchmarkTask = Task { [weak self] in
            await self?.runManualBenchmarks()
        }
    }

    public func noteDictationFinished() {
        lastDictationEndAt = Date()
        if status == .paused || status == .cancelled {
            scheduleIfNeeded()
        }
    }

    public func scheduleIfNeeded(force: Bool = false) {
        guard let engine else { return }
        let settings = AppSettings.shared
        let catalog = catalogProvider()
        catalog.refresh()

        guard settings.modelSelectionMode == .autoIdleBenchmark else {
            status = .idle
            return
        }

        guard !catalog.importedModels.isEmpty else {
            status = .idle
            progressEntries = []
            return
        }

        guard resolveVerificationRunnerURL() != nil else {
            status = .unavailable("VerificationRunner helper unavailable")
            progressEntries = []
            return
        }

        guard engine.state == .ready || engine.state == .stopped else {
            status = .paused
            return
        }

        let postDictationDelaySeconds = Double(postDictationDelayNs) / 1_000_000_000
        if !force, let lastDictationEndAt, Date().timeIntervalSince(lastDictationEndAt) < postDictationDelaySeconds {
            prepareProgressEntries(for: modelsForCurrentRun())
            status = .scheduled
            benchmarkTask?.cancel()
            benchmarkTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.postDictationDelayNs ?? 0)
                guard !Task.isCancelled else { return }
                self?.scheduleIfNeeded(force: true)
            }
            return
        }

        benchmarkTask?.cancel()
        prepareProgressEntries(for: modelsForCurrentRun())
        status = .scheduled
        benchmarkTask = Task { [weak self] in
            let delay: UInt64 = force ? 0 : (self?.initialDelayNs ?? 0)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.runNextPendingBenchmark()
        }
    }

    private func observe(engine: TranscriptionEngine) {
        cancellables.removeAll()

        engine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                if state == .listening || state == .transcribing {
                    self.cancelForDictation()
                } else if state == .ready {
                    self.scheduleIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func runNextPendingBenchmark() async {
        guard let engine else { return }

        let settings = AppSettings.shared
        let catalog = catalogProvider()
        let store = resultsStoreProvider()
        let baseline = BenchmarkBaseline.loadCommittedBaseline()
        let currentModel = catalog.activeDescriptor(settings: settings)

        guard let currentModel else {
            status = .unavailable("No active model available")
            return
        }

        let candidates = catalog.importedModels.filter {
            $0.id != currentModel.id &&
            store.latestResult(for: $0, settings: settings) == nil
        }
        guard let candidate = candidates.first else {
            progressEntries = []
            status = .completed("Benchmark cache is current")
            return
        }

        guard engine.state == .ready || engine.state == .stopped else {
            status = .paused
            return
        }

        do {
            let currentResult = try await runBenchmarkIfNeeded(for: currentModel, settings: settings, store: store)
            let candidateResult = try await runBenchmarkIfNeeded(for: candidate, settings: settings, store: store)

            if let baseline, settings.allowAutoModelPromotion {
                let decision = BenchmarkPromotionPolicy.shouldPromote(
                    candidate: candidateResult,
                    current: currentResult,
                    thresholds: baseline.thresholds
                )
                if decision.shouldPromote {
                    settings.activeWhisperModelID = candidate.id
                    status = .completed("Promoted \(candidate.id)")
                } else {
                    status = .completed(decision.reason)
                }
            } else {
                status = .completed("Saved benchmark results for \(candidate.id)")
            }
        } catch is CancellationError {
            if status != .cancelled {
                status = .paused
            }
        } catch {
            status = .unavailable(error.localizedDescription)
            updateProgress(modelID: candidate.id, state: .failed, detail: error.localizedDescription)
        }
    }

    private func runManualBenchmarks() async {
        guard let engine else { return }
        let settings = AppSettings.shared
        let catalog = catalogProvider()
        let store = resultsStoreProvider()
        let baseline = BenchmarkBaseline.loadCommittedBaseline()

        catalog.refresh()

        guard engine.state == .ready || engine.state == .stopped else {
            status = .paused
            return
        }

        guard let currentModel = catalog.activeDescriptor(settings: settings) else {
            status = .unavailable("No active model available")
            return
        }

        let importedModels = catalog.importedModels.filter { $0.id != currentModel.id }
        var refreshedResults: [ModelBenchmarkResult] = []

        do {
            let currentResult = try await runBenchmarkIfNeeded(
                for: currentModel,
                settings: settings,
                store: store,
                forceRefresh: true
            )
            refreshedResults.append(currentResult)

            for model in importedModels {
                let result = try await runBenchmarkIfNeeded(
                    for: model,
                    settings: settings,
                    store: store,
                    forceRefresh: true
                )
                refreshedResults.append(result)
            }

            guard importedModels.isEmpty == false,
                  let baseline,
                  settings.allowAutoModelPromotion else {
                status = .completed("Benchmark results refreshed")
                return
            }

            let currentFreshResult = refreshedResults.first(where: { $0.modelID == currentModel.id }) ?? currentResult
            let candidateResults = refreshedResults.filter { $0.modelID != currentModel.id }

            let rankedCandidate = candidateResults
                .map { result -> (ModelBenchmarkResult, BenchmarkPromotionDecision, Double) in
                    let decision = BenchmarkPromotionPolicy.shouldPromote(
                        candidate: result,
                        current: currentFreshResult,
                        thresholds: baseline.thresholds
                    )
                    let improvement = currentFreshResult.averageWER - result.averageWER
                    return (result, decision, improvement)
                }
                .filter { $0.1.shouldPromote }
                .max(by: { $0.2 < $1.2 })

            if let rankedCandidate {
                settings.activeWhisperModelID = rankedCandidate.0.modelID
                status = .completed("Promoted \(rankedCandidate.0.modelID)")
            } else {
                status = .completed("Benchmark results refreshed")
            }
        } catch is CancellationError {
            if status != .cancelled {
                status = .paused
            }
        } catch {
            status = .unavailable(error.localizedDescription)
        }
    }

    private func runBenchmarkIfNeeded(
        for model: WhisperModelDescriptor,
        settings: AppSettings,
        store: BenchmarkResultsStore,
        forceRefresh: Bool = false
    ) async throws -> ModelBenchmarkResult {
        if !forceRefresh, let existing = store.latestResult(for: model, settings: settings) {
            updateProgress(modelID: model.id, state: .cached, detail: "Using cached result")
            return existing
        }

        let result = try await runBenchmark(for: model, settings: settings)
        store.upsert(result)
        updateProgress(
            modelID: model.id,
            state: .completed,
            detail: "WER \(formatPercent(result.averageWER)) · p95 \(Int(result.p95LatencyMs))ms"
        )
        return result
    }

    private func runBenchmark(
        for model: WhisperModelDescriptor,
        settings: AppSettings
    ) async throws -> ModelBenchmarkResult {
        guard let helperURL = resolveVerificationRunnerURL() else {
            throw DictationError.unknown("VerificationRunner helper unavailable.")
        }

        guard let corpusDirectory = bundledCorpusDirectoryURL() else {
            throw DictationError.unknown("Bundled benchmark corpus unavailable.")
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DexDictateBenchmark", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let outputURL = tempDirectory.appendingPathComponent("\(model.id)-\(UUID().uuidString).json")

        status = .running(modelID: model.id)
        updateProgress(modelID: model.id, state: .running, detail: "Benchmarking now")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = helperURL
            process.arguments = [
                "--benchmark-corpus", corpusDirectory.path,
                "--model", model.id,
                "--decode-profile", ExperimentFlags.whisperDecodeProfile.cliName,
                "--utterance-end-preset", settings.utteranceEndPreset.rawValue.lowercased(),
                "--json-output", outputURL.path
            ]

            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    self?.helperProcess = nil
                    let terminationWasRequested = self?.helperTerminationWasRequested == true
                    self?.helperTerminationWasRequested = false
                    if terminationWasRequested {
                        self?.updateProgress(modelID: model.id, state: .cancelled, detail: "Cancelled for dictation")
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    guard process.terminationStatus == 0,
                          let data = try? Data(contentsOf: outputURL),
                          let decoded = try? JSONDecoder().decode(ModelBenchmarkResult.self, from: data) else {
                        self?.updateProgress(modelID: model.id, state: .failed, detail: "Benchmark helper failed")
                        continuation.resume(throwing: DictationError.unknown("Benchmark helper failed for \(model.id)."))
                        return
                    }
                    continuation.resume(returning: decoded)
                }
            }

            do {
                helperTerminationWasRequested = false
                try process.run()
                helperProcess = process
            } catch {
                updateProgress(modelID: model.id, state: .failed, detail: error.localizedDescription)
                continuation.resume(throwing: error)
            }
        }
    }

    private func resolveVerificationRunnerURL() -> URL? {
        if let helperURLResolver {
            return helperURLResolver()
        }

        let env = ProcessInfo.processInfo.environment["DEXDICTATE_VERIFICATION_RUNNER_PATH"]
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates: [URL] = [
            env.map(URL.init(fileURLWithPath:)),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/VerificationRunner"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("VerificationRunner"),
            cwd.appendingPathComponent(".build/debug/VerificationRunner"),
            cwd.appendingPathComponent(".build/release/VerificationRunner")
        ].compactMap { $0 }

        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
    }

    private func bundledCorpusDirectoryURL() -> URL? {
        // 1. Bundled resource inside the app bundle (production).
        if let resourceURL = Safety.resourceBundle.url(forResource: "BundledBenchmarkCorpus", withExtension: nil) {
            return resourceURL
        }

        // 2. Developer environment: sample_corpus in the current working directory.
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceCorpus = cwd.appendingPathComponent("sample_corpus")
        if FileManager.default.fileExists(atPath: sourceCorpus.path) {
            return sourceCorpus
        }

        // 3. User-captured sessions in ~/Library/Application Support/DexDictate/BenchmarkCaptures/.
        //    Return the most recent session directory that contains at least one .wav file —
        //    sessions without recordings cannot be used for benchmarking.
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let capturesDir = appSupport.appendingPathComponent("DexDictate/BenchmarkCaptures", isDirectory: true)
            let sessions = (try? FileManager.default.contentsOfDirectory(
                at: capturesDir,
                includingPropertiesForKeys: nil
            ).filter { $0.hasDirectoryPath }.sorted { $0.path > $1.path }) ?? []
            for session in sessions {
                let wavFiles = (try? FileManager.default.contentsOfDirectory(
                    at: session,
                    includingPropertiesForKeys: nil
                ).filter { $0.pathExtension.lowercased() == "wav" }) ?? []
                if !wavFiles.isEmpty { return session }
            }
        }

        return nil
    }

    private func modelsForCurrentRun() -> [String] {
        let settings = AppSettings.shared
        let catalog = catalogProvider()
        var ids: [String] = []
        if let active = catalog.activeDescriptor(settings: settings)?.id {
            ids.append(active)
        }
        ids.append(contentsOf: catalog.importedModels.map(\.id).filter { !ids.contains($0) })
        return ids
    }

    private func prepareProgressEntries(for modelIDs: [String]) {
        progressEntries = modelIDs.map { BenchmarkProgressEntry(modelID: $0, state: .queued, detail: "Queued") }
    }

    private func updateProgress(modelID: String, state: BenchmarkProgressState, detail: String) {
        let entry = BenchmarkProgressEntry(modelID: modelID, state: state, detail: detail)
        if let index = progressEntries.firstIndex(where: { $0.modelID == modelID }) {
            progressEntries[index] = entry
        } else {
            progressEntries.append(entry)
        }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
