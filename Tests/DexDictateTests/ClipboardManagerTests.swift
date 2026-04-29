import AppKit
import XCTest
@testable import DexDictateKit

final class ClipboardManagerTests: XCTestCase {
    func testDefaultPasteDeliveryProfileWaitsForStandardApps() {
        let profile = PasteDeliveryProfile.resolve(for: nil)

        XCTAssertEqual(profile.initialDelay, 0.12)
        XCTAssertEqual(profile.activationTimeout, 0.20)
        XCTAssertEqual(profile.activationPollInterval, 0.02)
        XCTAssertTrue(profile.postsToTargetProcess)
    }

    func testZoomPasteDeliveryProfileAllowsExtraActivationTime() {
        let target = OutputTargetApplication(bundleIdentifier: "us.zoom.xos", processIdentifier: 99)

        let profile = PasteDeliveryProfile.resolve(for: target)

        XCTAssertEqual(profile.initialDelay, 0.22)
        XCTAssertEqual(profile.activationTimeout, 0.45)
        XCTAssertEqual(profile.activationPollInterval, 0.02)
        XCTAssertTrue(profile.postsToTargetProcess)
    }

    func testZoomPrefixResolutionAppliesToAllUsZoomBundles() {
        let target = OutputTargetApplication(bundleIdentifier: "us.zoom.chat", processIdentifier: 77)

        let profile = PasteDeliveryProfile.resolve(for: target)

        XCTAssertEqual(profile.initialDelay, 0.22)
        XCTAssertEqual(profile.activationTimeout, 0.45)
    }

    func testNonMatchingZoomLikeBundleUsesDefaultProfile() {
        let target = OutputTargetApplication(bundleIdentifier: "com.zoom.us", processIdentifier: 88)

        let profile = PasteDeliveryProfile.resolve(for: target)

        XCTAssertEqual(profile.initialDelay, 0.12)
        XCTAssertEqual(profile.activationTimeout, 0.20)
    }

    func testClonePasteboardItemPreservesIndependentRepresentations() {
        let source = NSPasteboardItem()
        let dataType = NSPasteboard.PasteboardType("com.dexdictate.test.data")
        let plistType = NSPasteboard.PasteboardType("com.dexdictate.test.plist")
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let propertyList: [String: String] = ["label": "DexDictate"]

        XCTAssertTrue(source.setString("transcript", forType: .string))
        XCTAssertTrue(source.setData(payload, forType: dataType))
        XCTAssertTrue(source.setPropertyList(propertyList, forType: plistType))

        let clone = ClipboardManager.clonePasteboardItem(source)

        XCTAssertNotEqual(ObjectIdentifier(source), ObjectIdentifier(clone))
        XCTAssertEqual(clone.string(forType: .string), "transcript")
        XCTAssertEqual(clone.data(forType: dataType), payload)
        XCTAssertEqual(
            clone.propertyList(forType: plistType) as? [String: String],
            propertyList
        )
    }

    func testClonePasteboardItemsKeepsTrackOfUnrestorableOriginalClipboardContents() {
        let uncloneableItem = NSPasteboardItem()

        let snapshot = ClipboardManager.clonePasteboardItems([uncloneableItem])

        XCTAssertTrue(snapshot.hadOriginalContents)
        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.makePasteboardItems().isEmpty)
    }

    func testClonePasteboardItemsWithNilInputRepresentsEmptyClipboardSafely() {
        let snapshot = ClipboardManager.clonePasteboardItems(nil)

        XCTAssertFalse(snapshot.hadOriginalContents)
        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.makePasteboardItems().isEmpty)
    }

    func testClonePasteboardItemsDropsEmptyClonesButKeepsValidItems() {
        let validItem = NSPasteboardItem()
        XCTAssertTrue(validItem.setString("transcript", forType: .string))

        let uncloneableItem = NSPasteboardItem()

        let snapshot = ClipboardManager.clonePasteboardItems([validItem, uncloneableItem])

        XCTAssertTrue(snapshot.hadOriginalContents)
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.makePasteboardItems().first?.string(forType: .string), "transcript")
    }

    func testSavedPasteboardContentsMaterializesFreshItemsForEachRestoreAttempt() {
        let source = NSPasteboardItem()
        XCTAssertTrue(source.setString("transcript", forType: .string))

        let snapshot = ClipboardManager.clonePasteboardItems([source])
        let firstRestore = snapshot.makePasteboardItems()
        let secondRestore = snapshot.makePasteboardItems()

        XCTAssertEqual(firstRestore.count, 1)
        XCTAssertEqual(secondRestore.count, 1)
        XCTAssertNotEqual(ObjectIdentifier(firstRestore[0]), ObjectIdentifier(secondRestore[0]))
        XCTAssertEqual(firstRestore[0].string(forType: .string), "transcript")
        XCTAssertEqual(secondRestore[0].string(forType: .string), "transcript")
    }

    func testRestoreOwnershipCheckAllowsRestoreOnlyWhenDexDictateStillOwnsPayload() {
        XCTAssertTrue(
            ClipboardManager.shouldRestoreClipboard(
                currentChangeCount: 31,
                currentStringPayload: "dictation",
                dictationChangeCount: 31,
                dictationPayload: "dictation"
            )
        )
    }

    func testRestoreOwnershipCheckRejectsRestoreWhenClipboardChangeCountMoved() {
        XCTAssertFalse(
            ClipboardManager.shouldRestoreClipboard(
                currentChangeCount: 32,
                currentStringPayload: "dictation",
                dictationChangeCount: 31,
                dictationPayload: "dictation"
            )
        )
    }

    func testRestoreOwnershipCheckRejectsRestoreWhenPayloadNoLongerMatches() {
        XCTAssertFalse(
            ClipboardManager.shouldRestoreClipboard(
                currentChangeCount: 31,
                currentStringPayload: "user-updated",
                dictationChangeCount: 31,
                dictationPayload: "dictation"
            )
        )
    }

    func testRestoreOwnershipCheckRejectsRestoreWhenStringPayloadMissing() {
        XCTAssertFalse(
            ClipboardManager.shouldRestoreClipboard(
                currentChangeCount: 31,
                currentStringPayload: nil,
                dictationChangeCount: 31,
                dictationPayload: "dictation"
            )
        )
    }

    func testRestoreOwnershipCheckPreventsStaleRestoreAcrossRepeatedPasteOperations() {
        let firstPasteOwnsClipboard = ClipboardManager.shouldRestoreClipboard(
            currentChangeCount: 102,
            currentStringPayload: "second-pass",
            dictationChangeCount: 101,
            dictationPayload: "first-pass"
        )
        let secondPasteOwnsClipboard = ClipboardManager.shouldRestoreClipboard(
            currentChangeCount: 102,
            currentStringPayload: "second-pass",
            dictationChangeCount: 102,
            dictationPayload: "second-pass"
        )

        XCTAssertFalse(firstPasteOwnsClipboard)
        XCTAssertTrue(secondPasteOwnsClipboard)
    }
}
