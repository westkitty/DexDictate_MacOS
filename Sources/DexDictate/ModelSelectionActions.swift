import Foundation
import DexDictateKit

/// Shared "what does picking this model/engine mean" logic, used by both the Classic
/// (`QuickSettingsView`'s "Choose Model" list) and the slim popover's (`DexContextChips`,
/// re-hosted from the former experimental UI in Packet 12A-B) model pill so the two
/// surfaces can't drift into different behavior for the same underlying settings.
enum ModelSelectionActions {
    /// Every Whisper size already on disk, unioned with the full downloadable catalog —
    /// de-duplicated by id so an installed size never appears twice.
    struct WhisperRow: Identifiable {
        let id: String
        let displayName: String
        let isInstalled: Bool
    }

    @MainActor
    static func whisperRows(modelCatalog: WhisperModelCatalog) -> [WhisperRow] {
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
    static func primaryEngineID(settings: AppSettings, registry: TranscriptionProviderRegistry) -> TranscriptionProviderID {
        if let pin = TranscriptionProviderID(rawValue: settings.preferredPrimaryEngineID) {
            return pin
        }
        return registry.healthReport[.parakeetTDT06Bv3]?.isAvailable == true ? .parakeetTDT06Bv3 : .whisperKit
    }

    @MainActor
    static func applyWhisperSelection(id: String, settings: AppSettings) {
        settings.activeWhisperModelID = id
        settings.preferredPrimaryEngineID = TranscriptionProviderID.whisperKit.rawValue
    }

    @MainActor
    static func applyProviderSelection(_ pid: TranscriptionProviderID, settings: AppSettings) {
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
    static func selectWhisper(id: String, isInstalled: Bool, settings: AppSettings, modelCatalog: WhisperModelCatalog) async {
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
    static func selectProvider(_ pid: TranscriptionProviderID, settings: AppSettings, registry: TranscriptionProviderRegistry) async {
        if registry.healthReport[pid]?.isAvailable != true {
            await registry.downloadModelsIfNeeded(for: pid)
        }
        guard registry.healthReport[pid]?.isAvailable == true else { return }
        applyProviderSelection(pid, settings: settings)
    }
}
