import Foundation

public struct WatermarkAsset: Identifiable, Equatable {
    public let filename: String
    public let url: URL

    public var id: String { filename }
}

@MainActor
public final class WatermarkAssetProvider: ObservableObject {
    @Published public private(set) var currentAsset: WatermarkAsset?

    private var lastSelectedFilenameByProfile: [AppProfile: String] = [:]
    private static let standardRandomCycleFilenames: [String] = [
        "DexDictate_active_processing_label__processing.png",
        "DexDictate_active_recording_label__recording.png",
        "DexDictate_app_settings.png",
        "DexDictate_benchmark__failed__variant_a.png",
        "DexDictate_benchmark__failed__variant_b.png",
        "DexDictate_benchmark__running__variant_a.png",
        "DexDictate_benchmark__running__variant_b.png",
        "DexDictate_copied_to_clipboard.png",
        "DexDictate_error__misunderstood__variant_a.png",
        "DexDictate_filter_profanity.png",
        "DexDictate_floating_hud_window__variant_a.png",
        "DexDictate_floating_hud_window__variant_b.png",
        "DexDictate_input_device_selector.png",
        "DexDictate_listening__waiting__variant_a.png",
        "DexDictate_listening__waiting__variant_b.png",
        "DexDictate_listening__waiting__variant_c.png",
        "DexDictate_loading_ai_model.png",
        "DexDictate_mic_only_icon__variant_a.png",
        "DexDictate_mic_only_icon__variant_b.png",
        "DexDictate_mode__aussie_profile.png",
        "DexDictate_mode__canadian_profile__variant_a.png",
        "DexDictate_mode__canadian_profile__variant_b.png",
        "DexDictate_offline_privacy__variant_a.png",
        "DexDictate_offline_privacy__variant_b.png",
        "DexDictate_onboarding__completion.png",
        "DexDictate_onboarding__shortcut_selection__variant_a.png",
        "DexDictate_onboarding__shortcut_selection__variant_b.png",
        "DexDictate_onboarding__welcome__variant_a.png",
        "DexDictate_onboarding__welcome__variant_b.png",
        "DexDictate_processing__typing__variant_a.png",
        "DexDictate_processing__typing__variant_b.png",
        "DexDictate_processing__typing__variant_c.png",
        "DexDictate_random_cycle__headphones_portrait.jpg",
        "DexDictate_random_cycle__red_button_prompt.jpg",
        "DexDictate_random_cycle__side_eye_pose__variant_a.jpg",
        "DexDictate_random_cycle__side_eye_pose__variant_b.jpg",
        "DexDictate_random_cycle__side_eye_pose__variant_c.jpg",
        "DexDictate_random_cycle__smiley_mask_splatter__variant_a.jpg",
        "DexDictate_random_cycle__smiley_mask_splatter__variant_b.jpg",
        "DexDictate_random_cycle__smiley_mask_splatter__variant_c.jpg",
        "DexDictate_random_cycle__standing_pose__variant_a.jpg",
        "DexDictate_random_cycle__standing_pose__variant_b.jpg",
        "DexDictate_random_cycle__standing_pose__variant_c.jpg",
        "DexDictate_result_feedback_badge__variant_a.png",
        "DexDictate_result_feedback_badge__variant_b.png",
        "DexDictate_start_dictation__variant_a.png",
        "DexDictate_success__saved__variant_a.png",
        "DexDictate_success__saved__variant_b.png",
        "DexDictate_transcribe_file__variant_a.png",
        "DexDictate_transcribe_file__variant_b.png",
        "DexDictate_transcription_history__collapsed.png",
        "DexDictate_transcription_history__expanded__variant_a.png",
        "DexDictate_transcription_history__expanded__variant_b.png",
        "DexDictate_trigger_mode__hold_to_talk__variant_a.png",
        "DexDictate_trigger_mode__hold_to_talk__variant_b.png",
        "DexDictate_undo_removal__variant_a.png",
        "DexDictate_undo_removal__variant_b.png"
    ]

    public init() {}

    public func assets(for profile: AppProfile) -> [WatermarkAsset] {
        Self.filenames(for: profile).compactMap { filename in
            let resourceName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            let resourceExtension = URL(fileURLWithPath: filename).pathExtension
            guard let url = Safety.resourceBundle.url(forResource: resourceName, withExtension: resourceExtension.isEmpty ? nil : resourceExtension) else {
                return nil
            }

            return WatermarkAsset(filename: filename, url: url)
        }
    }

    @discardableResult
    public func selectRandomAsset(for profile: AppProfile) -> WatermarkAsset? {
        let pool = assets(for: profile)
        guard !pool.isEmpty else {
            currentAsset = nil
            return nil
        }

        let lastFilename = lastSelectedFilenameByProfile[profile]
        let nonRepeatingPool = pool.filter { $0.filename != lastFilename }
        let selectionPool = nonRepeatingPool.isEmpty ? pool : nonRepeatingPool
        let asset = selectionPool.randomElement() ?? pool[0]

        currentAsset = asset
        lastSelectedFilenameByProfile[profile] = asset.filename
        return asset
    }

    public static func filenames(for profile: AppProfile) -> [String] {
        switch profile {
        case .standard:
            return standardRandomCycleFilenames
        case .canadian:
            return [
                "dexdictate-icon-canada-01.png",
                "dexdictate-icon-canada-02.png",
                "dexdictate-icon-canada-03.png",
                "dexdictate-icon-canada-04.png",
                "dexdictate-icon-canada-05.png"
            ]
        case .aussie:
            return [
                "dexdictate-icon-aussie-01.png",
                "dexdictate-icon-aussie-02.png"
            ]
        }
    }
}
