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

    // Regression test: replacement strings containing NSRegularExpression template
    // metacharacters ($0, $1, \1, etc.) must be output literally and not interpreted
    // as capture-group back-references.
    func testReplacementWithRegexTemplateMetacharactersIsOutputLiterally() {
        let manager = VocabularyManager()

        // $0 / $1 — dollar-sign back-reference syntax
        manager.items = [
            VocabularyItem(original: "one hundred dollars", replacement: "$100"),
            VocabularyItem(original: "rev counter", replacement: "$1000 RPM"),
            VocabularyItem(original: "cpp plus", replacement: "C++\\1"),
        ]

        XCTAssertEqual(
            manager.apply(to: "one hundred dollars"),
            "$100",
            "Replacement '$100' must appear verbatim; NSRegularExpression must not expand $1 as a capture group"
        )
        XCTAssertEqual(
            manager.apply(to: "rev counter"),
            "$1000 RPM",
            "Replacement '$1000 RPM' must appear verbatim"
        )
        XCTAssertEqual(
            manager.apply(to: "cpp plus"),
            "C++\\1",
            "Replacement 'C++\\1' must appear verbatim; backslash-digit must not be treated as a back-reference"
        )
    }
}
