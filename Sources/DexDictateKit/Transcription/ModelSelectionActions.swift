import Foundation

/// Shared "what does picking this model/engine mean" logic, used by both Settings
/// (`QuickSettingsView`'s "Model Library" list) and the slim popover's (`DexContextChips`,
/// re-hosted from the former experimental UI in Packet 12A-B) model pill so the two
/// surfaces can't drift into different behavior for the same underlying settings.
///
/// BUG-006A moved this here from `Sources/DexDictate/` (the app executable target) so the
/// state-sharing logic that is the actual subject of that fix — not just its individual
/// pieces (`AppSettings`, `WhisperModelCatalog`, `TranscriptionProviderRegistry`, all already
/// in `DexDictateKit`) — is reachable from `Tests/DexDictateTests`. It has no SwiftUI
/// dependency; this is a pure-logic relocation, not a UI move, so it doesn't touch the
/// `Package.swift` test-target boundary the BUG-005/BUG-004 precedent established for actual
/// SwiftUI views.
public enum ModelSelectionActions {
    /// Every Whisper size already on disk, unioned with the full downloadable catalog —
    /// de-duplicated by id so an installed size never appears twice.
    public struct WhisperRow: Identifiable {
        public let id: String
        public let displayName: String
        public let isInstalled: Bool
    }

    @MainActor
    public static func whisperRows(modelCatalog: WhisperModelCatalog) -> [WhisperRow] {
        var seen = Set<String>()
        var rows: [WhisperRow] = []
        for model in modelCatalog.availableModels where seen.insert(model.id).inserted {
            rows.append(WhisperRow(id: model.id, displayName: model.displayName, isInstalled: true))
        }
        for entry in WhisperModelCatalog.downloadableCatalog where seen.insert(entry.id).inserted {
            rows.append(WhisperRow(
                id: entry.id,
                displayName: "\(entry.displayName) (\(entry.approximateSizeMB) MB)",
                isInstalled: false
            ))
        }
        return rows
    }

    /// The engine currently producing the committed/pasted transcript: the explicit pin if one
    /// is set, otherwise the automatic Parakeet-if-healthy-else-Whisper default.
    @MainActor
    public static func primaryEngineID(settings: AppSettings, registry: TranscriptionProviderRegistry) -> TranscriptionProviderID {
        if let pin = TranscriptionProviderID(rawValue: settings.preferredPrimaryEngineID) {
            return pin
        }
        return registry.healthReport[.parakeetTDT06Bv3]?.isAvailable == true ? .parakeetTDT06Bv3 : .whisperKit
    }

    @MainActor
    public static func applyWhisperSelection(id: String, settings: AppSettings) {
        settings.activeWhisperModelID = id
        settings.preferredPrimaryEngineID = TranscriptionProviderID.whisperKit.rawValue
    }

    @MainActor
    public static func applyProviderSelection(_ pid: TranscriptionProviderID, settings: AppSettings) {
        switch pid {
        case .parakeetTDT06Bv3:
            settings.preferredPrimaryEngineID = pid.rawValue
        case .nemotron35ASRStreaming06B, .appleSpeech:
            settings.liveTranscriptionEnabled = true
        case .moonshineV2:
            settings.commandModeEnabled = true
        case .whisperKit:
            break
        }
    }

    /// Downloads (if needed) and selects a Whisper size. Safe to call even if already installed.
    @MainActor
    public static func selectWhisper(id: String, isInstalled: Bool, settings: AppSettings, modelCatalog: WhisperModelCatalog) async {
        if !isInstalled {
            guard let entry = WhisperModelCatalog.downloadableCatalog.first(where: { $0.id == id }) else { return }
            do {
                _ = try await modelCatalog.downloadModel(entry)
            } catch {
                Safety.log("Whisper model download failed for \(id): \(error.localizedDescription)", category: .settings)
                return
            }
        }
        applyWhisperSelection(id: id, settings: settings)
    }

    /// Downloads (if needed) and selects a provider engine. Safe to call even if already healthy.
    @MainActor
    public static func selectProvider(_ pid: TranscriptionProviderID, settings: AppSettings, registry: TranscriptionProviderRegistry) async {
        if registry.healthReport[pid]?.isAvailable != true {
            await registry.downloadModelsIfNeeded(for: pid)
        }
        guard registry.healthReport[pid]?.isAvailable == true else { return }
        applyProviderSelection(pid, settings: settings)
    }

    // MARK: - BUG-006A: honest "Active Dictation Model" selector

    /// One row in the unified **Active Dictation Model** selector — deliberately limited to the
    /// real, mutually-exclusive primary-engine choices (Parakeet, or an installed Whisper size).
    /// Nemotron/Moonshine/Apple Speech are excluded on purpose: they're independent feature-role
    /// toggles (Live Transcription, Command Mode) that never change which engine produces the
    /// committed/pasted transcript (see `TranscriptionEngine.runPrimaryEngine`), so presenting them
    /// alongside Parakeet/Whisper here would repeat BUG-006A's original confusion.
    public struct ActiveModelRow: Identifiable {
        public enum Kind: Equatable {
            case parakeet
            case whisper(id: String)
        }
        public let id: String
        public let displayName: String
        public let isSelected: Bool
        public let kind: Kind
    }

    @MainActor
    public static func activeModelRows(
        settings: AppSettings, registry: TranscriptionProviderRegistry, modelCatalog: WhisperModelCatalog
    ) -> [ActiveModelRow] {
        let primary = primaryEngineID(settings: settings, registry: registry)
        var rows: [ActiveModelRow] = []
        if registry.healthReport[.parakeetTDT06Bv3]?.isAvailable == true {
            rows.append(ActiveModelRow(
                id: "parakeet",
                displayName: registry.parakeetProvider.displayName,
                isSelected: primary == .parakeetTDT06Bv3,
                kind: .parakeet
            ))
        }
        for model in modelCatalog.availableModels {
            rows.append(ActiveModelRow(
                id: "whisper:\(model.id)",
                displayName: model.displayName,
                isSelected: primary == .whisperKit && settings.activeWhisperModelID == model.id,
                kind: .whisper(id: model.id)
            ))
        }
        return rows
    }

    @MainActor
    public static func applyActiveModelSelection(_ row: ActiveModelRow, settings: AppSettings) {
        switch row.kind {
        case .parakeet:
            applyProviderSelection(.parakeetTDT06Bv3, settings: settings)
        case .whisper(let id):
            applyWhisperSelection(id: id, settings: settings)
        }
    }

    /// Honest, single-source explanation of what's actually producing the typed text right now.
    /// Shared by the Settings "Active Dictation Model" section and `LiveTranscriptionStatusView`'s
    /// "Primary dictation engine" line so the two can never contradict each other.
    @MainActor
    public static func primaryEngineStatusExplanation(settings: AppSettings, registry: TranscriptionProviderRegistry) -> String {
        let isPinned = !settings.preferredPrimaryEngineID.isEmpty
        switch primaryEngineID(settings: settings, registry: registry) {
        case .parakeetTDT06Bv3:
            return isPinned
                ? "Pinned to Parakeet."
                : "Parakeet is downloaded and healthy, so it produces the text that gets typed automatically. Whisper is the fallback if it ever becomes unavailable."
        default:
            let parakeetHealthy = registry.healthReport[.parakeetTDT06Bv3]?.isAvailable == true
            if isPinned { return "Pinned to Whisper." }
            return parakeetHealthy
                ? "Whisper produces the text that gets typed."
                : "Whisper produces the text that gets typed. Download Parakeet below to make it the primary engine instead."
        }
    }

    // MARK: - Live-streaming (partial captions) status vocabulary

    /// Distinct from `primaryEngineStatusExplanation` above, which describes the *committed*
    /// dictation engine (Parakeet/Whisper) — this describes which provider (if any) is
    /// driving the *live partial preview* while the user is speaking, using the fixed
    /// vocabulary the Settings UI surfaces verbatim: "Ready — Nemotron", "Ready — Apple
    /// Speech", "Nemotron loading", and "Final-only fallback — Whisper" with one of three
    /// specific reasons attached.
    public enum LiveStreamingStatus: Equatable {
        case liveTranscriptionOff
        case readyNemotron
        case readyAppleSpeech
        case nemotronLoading
        case finalOnlyFallback(reason: FallbackReason)

        public enum FallbackReason: Equatable {
            case nemotronNotInstalled
            case speechPermissionRequired
            case noStreamingProviderAvailable
        }

        public var headline: String {
            switch self {
            case .liveTranscriptionOff: return "Live Transcription is off"
            case .readyNemotron: return "Ready — Nemotron"
            case .readyAppleSpeech: return "Ready — Apple Speech"
            case .nemotronLoading: return "Nemotron loading"
            case .finalOnlyFallback: return "Final-only fallback — Whisper"
            }
        }

        public var detail: String? {
            guard case .finalOnlyFallback(let reason) = self else { return nil }
            switch reason {
            case .nemotronNotInstalled: return "Nemotron model not installed"
            case .speechPermissionRequired: return "Speech Recognition permission required"
            case .noStreamingProviderAvailable: return "No streaming provider available"
            }
        }
    }

    @MainActor
    public static func liveStreamingStatus(settings: AppSettings, registry: TranscriptionProviderRegistry) -> LiveStreamingStatus {
        guard settings.liveTranscriptionEnabled else { return .liveTranscriptionOff }
        if registry.healthReport[.nemotron35ASRStreaming06B]?.isAvailable == true { return .readyNemotron }
        if registry.nemotronProvider.isDownloading { return .nemotronLoading }
        if registry.healthReport[.appleSpeech]?.isAvailable == true { return .readyAppleSpeech }
        if registry.nemotronProvider.modelInstallStatus == .notInstalled {
            return .finalOnlyFallback(reason: .nemotronNotInstalled)
        }
        if AppleSpeechTranscriptionProvider.authorizationState != .authorized {
            return .finalOnlyFallback(reason: .speechPermissionRequired)
        }
        return .finalOnlyFallback(reason: .noStreamingProviderAvailable)
    }
}
