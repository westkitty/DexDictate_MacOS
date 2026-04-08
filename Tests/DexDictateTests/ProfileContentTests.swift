import XCTest
@testable import DexDictateKit

@MainActor
final class ProfileContentTests: XCTestCase {
    func testProfileManagerDefaultsToStandardAndLoadsStandardBundledVocabulary() {
        let settings = AppSettings()
        settings.localizationMode = .standard

        let profileManager = ProfileManager(settings: settings)

        XCTAssertEqual(profileManager.activeProfile, .standard)
        XCTAssertEqual(profileManager.bundledVocabularyItems, BundledVocabularyPacks.pack(for: .standard))
    }

    func testSelectingProfileChangesBundledVocabularyAndWatermarkPool() {
        let settings = AppSettings()
        settings.localizationMode = .standard

        let profileManager = ProfileManager(settings: settings)
        profileManager.selectProfile(.canadian)

        XCTAssertEqual(profileManager.activeProfile, .canadian)
        XCTAssertEqual(profileManager.bundledVocabularyItems, BundledVocabularyPacks.pack(for: .canadian))
        XCTAssertEqual(profileManager.watermarkAssets(for: .canadian).count, 5)
        XCTAssertEqual(profileManager.watermarkAssets(for: .aussie).count, 2)
        XCTAssertEqual(profileManager.watermarkAssets(for: .standard).count, 57)
    }

    func testSynchronizeFromSettingsAppliesExternalProfileChanges() {
        let settings = AppSettings()
        settings.localizationMode = .canadian

        let profileManager = ProfileManager(settings: settings)
        settings.localizationMode = .aussie

        profileManager.synchronizeFromSettings()

        XCTAssertEqual(profileManager.activeProfile, .aussie)
        XCTAssertEqual(profileManager.bundledVocabularyItems, BundledVocabularyPacks.pack(for: .aussie))
    }

    func testFlavorTickerManagerAvoidsImmediateRepeats() {
        let manager = FlavorTickerManager()
        let pack = FlavorQuotePacks.standard

        var previous: FlavorLine?
        for _ in 0..<50 {
            let line = manager.selectNextLine(from: pack, for: .standard)
            XCTAssertNotNil(line)
            if let previous, let line {
                XCTAssertNotEqual(previous, line)
            }
            previous = line
        }
    }

    func testFlavorTickerManagerAvoidsRecentFiveWhenPossible() {
        let manager = FlavorTickerManager()
        let pack = [
            FlavorLine("one"),
            FlavorLine("two"),
            FlavorLine("three"),
            FlavorLine("four"),
            FlavorLine("five"),
            FlavorLine("six")
        ]

        var seen: [FlavorLine] = []
        for _ in 0..<6 {
            let line = manager.selectNextLine(from: pack, for: .aussie)
            XCTAssertNotNil(line)
            if let line {
                seen.append(line)
            }
        }

        XCTAssertEqual(Set(seen).count, 6)
    }

    func testWatermarkManifestMatchesExactPoolsAndExcludesSheets() {
        let standardFilenames = WatermarkAssetProvider.filenames(for: .standard)

        XCTAssertEqual(standardFilenames.count, 57)
        XCTAssertTrue(standardFilenames.contains("DexDictate_onboarding__welcome__variant_a.png"))
        XCTAssertTrue(standardFilenames.contains("DexDictate_random_cycle__standing_pose__variant_c.jpg"))
        XCTAssertFalse(standardFilenames.contains("dexdictate-icon-standard-11.png"))
        XCTAssertEqual(WatermarkAssetProvider.filenames(for: .canadian).count, 5)
        XCTAssertEqual(WatermarkAssetProvider.filenames(for: .aussie).count, 2)
        XCTAssertFalse(standardFilenames.contains("dexdictate-icon-standard-sheet-01.png"))
        XCTAssertFalse(standardFilenames.contains("dexdictate-icon-standard-sheet-02.png"))
    }
}
