import XCTest
@testable import DexDictateKit

final class VocabularyLayeringTests: XCTestCase {
    private let storageKey = "customVocabulary"
    private var originalData: Data?

    override func setUp() {
        super.setUp()
        originalData = UserDefaults.standard.data(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        if let originalData {
            UserDefaults.standard.set(originalData, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        super.tearDown()
    }

    func testBundledVocabularyDoesNotPersistIntoCustomVocabularyStorage() throws {
        let manager = VocabularyManager()
        manager.items = [VocabularyItem(original: "dex dictate", replacement: "DexDictate")]
        manager.setBundledItems(BundledVocabularyPacks.pack(for: .canadian))

        let reloadedManager = VocabularyManager()

        XCTAssertEqual(reloadedManager.items.map(\.original), ["dex dictate"])
        XCTAssertEqual(reloadedManager.items.map(\.replacement), ["DexDictate"])
        XCTAssertTrue(reloadedManager.bundledItems.isEmpty)

        let storedData = try XCTUnwrap(UserDefaults.standard.data(forKey: storageKey))
        let decoded = try JSONDecoder().decode([VocabularyItem].self, from: storedData)
        XCTAssertEqual(decoded.map(\.original), ["dex dictate"])
        XCTAssertEqual(decoded.map(\.replacement), ["DexDictate"])
    }

    func testApplyEffectiveUsesBundledAndCustomLayersWithCustomOverride() {
        let manager = VocabularyManager()
        manager.items = [VocabularyItem(original: "double double", replacement: "Double Double")]
        manager.setBundledItems(BundledVocabularyPacks.pack(for: .canadian))

        XCTAssertEqual(manager.applyEffective(to: "grab a double double from tim hortons"), "grab a Double Double from Tim Hortons")
    }
}
