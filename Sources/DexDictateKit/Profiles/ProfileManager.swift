import Foundation

@MainActor
public final class ProfileManager: ObservableObject {
    @Published public private(set) var activeProfile: AppProfile
    @Published public private(set) var currentFlavorLine: FlavorLine?
    @Published public private(set) var currentWatermarkAsset: WatermarkAsset?
    @Published public private(set) var bundledVocabularyItems: [VocabularyItem]

    private let settings: AppSettings
    private let tickerManager: FlavorTickerManager
    private let watermarkAssetProvider: WatermarkAssetProvider

    public init(
        settings: AppSettings = .shared,
        tickerManager: FlavorTickerManager? = nil,
        watermarkAssetProvider: WatermarkAssetProvider? = nil
    ) {
        self.settings = settings
        self.tickerManager = tickerManager ?? FlavorTickerManager()
        self.watermarkAssetProvider = watermarkAssetProvider ?? WatermarkAssetProvider()
        self.activeProfile = settings.localizationMode
        self.bundledVocabularyItems = BundledVocabularyPacks.pack(for: settings.localizationMode)
        self.currentFlavorLine = nil
        self.currentWatermarkAsset = nil
    }

    public func selectProfile(_ profile: AppProfile) {
        guard settings.localizationMode != profile else { return }
        settings.localizationMode = profile
        applyProfile(profile)
    }

    public func returnToStandard() {
        selectProfile(.standard)
    }

    public func refreshDynamicContent() {
        let pack = FlavorQuotePacks.pack(for: activeProfile)
        currentFlavorLine = tickerManager.selectNextLine(from: pack, for: activeProfile)
        currentWatermarkAsset = watermarkAssetProvider.selectRandomAsset(for: activeProfile)
    }

    public func synchronizeBundledVocabulary(with vocabularyManager: VocabularyManager) {
        vocabularyManager.setBundledItems(bundledVocabularyItems)
    }

    public func watermarkAssets(for profile: AppProfile) -> [WatermarkAsset] {
        watermarkAssetProvider.assets(for: profile)
    }

    public func synchronizeFromSettings() {
        let profile = settings.localizationMode
        guard activeProfile != profile || bundledVocabularyItems != BundledVocabularyPacks.pack(for: profile) else {
            return
        }

        applyProfile(profile)
    }

    private func applyProfile(_ profile: AppProfile) {
        activeProfile = profile
        bundledVocabularyItems = BundledVocabularyPacks.pack(for: profile)
    }
}
