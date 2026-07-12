import Foundation

/// Holds every known transcription provider and decides which one is active given the
/// Live Transcription setting. This is the single place that implements the fallback order:
///
///   Live Transcription ON:  Nemotron → Apple Speech → Whisper compatibility
///   Live Transcription OFF: Whisper compatibility
///
/// Resolution always runs a fresh health check (cheap, synchronous, no I/O) and never assumes
/// a provider is available just because it exists — a stub provider is always unavailable, and
/// Apple Speech / Nemotron can flip between available and unavailable at any time (permissions,
/// installation state).
@MainActor
public final class TranscriptionProviderRegistry: ObservableObject {
    public struct Resolution: Equatable {
        public let selectedProviderID: TranscriptionProviderID
        public let selectedProviderDisplayName: String
        public let modeName: String
        /// True when the selected provider will emit partial results while listening.
        public let usesLiveStreaming: Bool
        /// Plain-language explanation of why we didn't pick the preferred provider(s), if any.
        public let fallbackExplanation: String?
    }

    @Published public private(set) var lastResolution: Resolution?
    @Published public private(set) var healthReport: [TranscriptionProviderID: TranscriptionProviderHealth] = [:]

    public let whisperKitProvider: WhisperKitTranscriptionProvider
    public let appleSpeechProvider: AppleSpeechTranscriptionProvider
    /// Real (not stub) — see `ParakeetTranscriptionProvider`. Models download on demand.
    public let parakeetProvider: ParakeetTranscriptionProvider
    /// Real (not stub) — see `NemotronTranscriptionProvider`. Models download on demand.
    public let nemotronProvider: NemotronTranscriptionProvider
    /// Real (not stub) — see `MoonshineTranscriptionProvider`. Models download on demand.
    public let moonshineProvider: MoonshineTranscriptionProvider

    public init(whisperService: WhisperService) {
        whisperKitProvider = WhisperKitTranscriptionProvider(whisperService: whisperService)
        appleSpeechProvider = AppleSpeechTranscriptionProvider()
        parakeetProvider = ParakeetTranscriptionProvider()
        nemotronProvider = NemotronTranscriptionProvider()
        moonshineProvider = MoonshineTranscriptionProvider()
    }

    /// Kicks off (or no-ops if already loaded/loading) the on-demand model download for the
    /// given provider ID. Only Parakeet, Nemotron, and Moonshine have anything to download.
    /// Always explicit/user-triggered — never called automatically by the resolver.
    public func downloadModelsIfNeeded(for id: TranscriptionProviderID) async {
        switch id {
        case .parakeetTDT06Bv3:
            await parakeetProvider.downloadModelsIfNeeded()
        case .nemotron35ASRStreaming06B:
            await nemotronProvider.downloadModelsIfNeeded()
        case .moonshineV2:
            await moonshineProvider.downloadModelsIfNeeded()
        case .whisperKit, .appleSpeech:
            break
        }
        refreshHealthReport()
    }

    /// Loads models that are **already downloaded on disk** but not yet loaded into this
    /// process — zero network activity, safe to call unconditionally (e.g. once at app
    /// launch).
    ///
    /// Root-cause fix: `isModelLoaded`/`manager != nil` on each provider is in-memory state
    /// that resets to "not loaded" on every single app launch, while the downloaded model
    /// *files* persist on disk across launches. Without this, a model a user (or a prior
    /// session) already fully downloaded permanently reported "downloaded but not loaded
    /// yet" every subsequent launch until the user manually re-clicked the exact same
    /// download/select row — indistinguishable, from the user's perspective, from the
    /// provider being broken or "inaccessible."
    ///
    /// Reuses `downloadModelsIfNeeded(for:)` — the same call the manual download button
    /// already triggers — which itself only initiates a network download when
    /// `modelInstallStatus` isn't already `.installed`; since this method only calls it when
    /// that's already true, the download branch never executes here. Each candidate is
    /// gated on the setting that actually governs whether it should be active, so this
    /// can't silently start using CPU/ANE for a feature the user has turned off.
    public func loadAlreadyDownloadedModelsIfNeeded(settings: AppSettings) async {
        if settings.liveTranscriptionEnabled {
            await loadIfInstalledButNotYetAvailable(id: .nemotron35ASRStreaming06B, provider: nemotronProvider)
        }
        if settings.commandModeEnabled {
            await loadIfInstalledButNotYetAvailable(id: .moonshineV2, provider: moonshineProvider)
        }
        // Parakeet is a primary-engine candidate independent of Live Transcription/Command
        // Mode, so it's not gated behind either setting.
        await loadIfInstalledButNotYetAvailable(id: .parakeetTDT06Bv3, provider: parakeetProvider)

        // Recompute lastResolution immediately (not just healthReport) so anything bound to
        // it — Settings status rows, LivePreviewController's honest "unavailable" messaging —
        // reflects the newly-loaded provider without waiting for the next dictation attempt.
        _ = resolveActiveProvider(liveTranscriptionEnabled: settings.liveTranscriptionEnabled)
    }

    private func loadIfInstalledButNotYetAvailable(id: TranscriptionProviderID, provider: any TranscriptionProvider) async {
        guard provider.modelInstallStatus == .installed, provider.healthCheck().isAvailable == false else { return }
        await downloadModelsIfNeeded(for: id)
    }

    public var allProviders: [any TranscriptionProvider] {
        [parakeetProvider, nemotronProvider, whisperKitProvider, moonshineProvider, appleSpeechProvider]
    }

    /// Re-runs `healthCheck()` on every provider and publishes the result. Cheap and
    /// synchronous — safe to call on the trigger-down path.
    @discardableResult
    public func refreshHealthReport() -> [TranscriptionProviderID: TranscriptionProviderHealth] {
        var report: [TranscriptionProviderID: TranscriptionProviderHealth] = [:]
        for provider in allProviders {
            report[provider.id] = provider.healthCheck()
        }
        healthReport = report
        Safety.log(
            "TranscriptionProviderRegistry health: " + report
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { "\($0.key.rawValue)=" + ($0.value.isAvailable ? "available" : "unavailable(\($0.value.reason ?? "?"))") }
                .joined(separator: ", "),
            category: .transcription
        )
        return report
    }

    @discardableResult
    public func resolveActiveProvider(liveTranscriptionEnabled: Bool) -> Resolution {
        let report = refreshHealthReport()

        guard liveTranscriptionEnabled else {
            let resolution = Resolution(
                selectedProviderID: .whisperKit,
                selectedProviderDisplayName: whisperKitProvider.displayName,
                modeName: TranscriptionMode.compatibility.displayName,
                usesLiveStreaming: false,
                fallbackExplanation: nil
            )
            lastResolution = resolution
            return resolution
        }

        if report[.nemotron35ASRStreaming06B]?.isAvailable == true {
            let resolution = Resolution(
                selectedProviderID: .nemotron35ASRStreaming06B,
                selectedProviderDisplayName: nemotronProvider.displayName,
                modeName: TranscriptionMode.liveStreaming.displayName,
                usesLiveStreaming: true,
                fallbackExplanation: nil
            )
            lastResolution = resolution
            Safety.log("TranscriptionProviderRegistry — selected Nemotron for live transcription", category: .transcription)
            return resolution
        }
        let nemotronReason = report[.nemotron35ASRStreaming06B]?.reason ?? "unavailable."

        if report[.appleSpeech]?.isAvailable == true {
            let resolution = Resolution(
                selectedProviderID: .appleSpeech,
                selectedProviderDisplayName: appleSpeechProvider.displayName,
                modeName: TranscriptionMode.appleSpeech.displayName,
                usesLiveStreaming: true,
                fallbackExplanation: "Nemotron unavailable: \(nemotronReason) Falling back to Apple Speech."
            )
            lastResolution = resolution
            Safety.log("TranscriptionProviderRegistry — selected Apple Speech for live transcription (Nemotron unavailable: \(nemotronReason))", category: .transcription)
            return resolution
        }
        let appleReason = report[.appleSpeech]?.reason ?? "unavailable."

        let resolution = Resolution(
            selectedProviderID: .whisperKit,
            selectedProviderDisplayName: whisperKitProvider.displayName,
            modeName: TranscriptionMode.compatibility.displayName,
            usesLiveStreaming: false,
            fallbackExplanation: "Nemotron unavailable: \(nemotronReason) Apple Speech unavailable: \(appleReason) Using Whisper compatibility mode."
        )
        lastResolution = resolution
        Safety.log(
            "TranscriptionProviderRegistry — falling back to Whisper compatibility (Nemotron unavailable: \(nemotronReason); Apple Speech unavailable: \(appleReason))",
            category: .transcription
        )
        return resolution
    }
}
