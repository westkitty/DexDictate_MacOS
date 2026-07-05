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
