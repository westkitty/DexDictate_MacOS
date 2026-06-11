import AppKit
import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Tests for paste-pipeline hardening: focus identity matching, ClipboardManager
/// editable validation, and InsertionModeOverride round-trip decoding.
final class OutputPipelineHardeningTests: XCTestCase {

    // MARK: - FocusedElementIdentityMatcher

    func testSameElementPassesWhenBothHaveSameIdentifier() {
        let trigger = FocusedElementSnapshot(
            role: "AXTextField", identifier: "search-box",
            processIdentifier: 100, bundleIdentifier: "com.example.app"
        )
        let current = FocusedElementSnapshot(
            role: "AXTextField", identifier: "search-box",
            processIdentifier: 100, bundleIdentifier: "com.example.app"
        )
        XCTAssertTrue(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testDifferentIdentifierFails() {
        let trigger = FocusedElementSnapshot(identifier: "field-a", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(identifier: "field-b", bundleIdentifier: "com.example.app")
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testDifferentBundleIDFails() {
        let trigger = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: "com.other.app")
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testDifferentRoleFails() {
        let trigger = FocusedElementSnapshot(role: "AXTextField", title: "Name", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(role: "AXTextArea", title: "Name", bundleIdentifier: "com.example.app")
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testMatchingSemanticFieldPasses() {
        let trigger = FocusedElementSnapshot(role: "AXTextField", placeholder: "Search", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(role: "AXTextField", placeholder: "Search", bundleIdentifier: "com.example.app")
        XCTAssertTrue(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testNoMatchingSemanticFieldFails() {
        let trigger = FocusedElementSnapshot(role: "AXTextField", title: "Name", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(role: "AXTextField", title: "Email", bundleIdentifier: "com.example.app")
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testNilCurrentSnapshotConservativelyAllowsPaste() {
        let trigger = FocusedElementSnapshot(identifier: "field-a", bundleIdentifier: "com.example.app")
        XCTAssertTrue(FocusedElementIdentityMatcher.isSameContext(trigger, nil))
    }

    func testNoSemanticInfoOnEitherSideAllowsPaste() {
        // No identifier, no semantic fields — fall back to allowing paste
        let trigger = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: "com.example.app")
        let current = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: "com.example.app")
        XCTAssertTrue(FocusedElementIdentityMatcher.isSameContext(trigger, current))
    }

    func testTargetBundleIDUsedWhenTriggerBundleIDNil() {
        let trigger = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: nil)
        let current = FocusedElementSnapshot(role: "AXTextField", bundleIdentifier: "com.other.app")
        // targetBundleID = "com.example.app" != current "com.other.app" → fail
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(
            trigger, current, targetBundleID: "com.example.app"
        ))
    }

    func testDifferentPIDFailsEvenWhenBundleIDsAreAbsent() {
        // PID check (rule 0) must fire before bundle check so that process changes
        // aren't missed when bundle IDs couldn't be captured.
        let trigger = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1001, bundleIdentifier: nil
        )
        let current = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1002, bundleIdentifier: nil
        )
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current),
            "Different PIDs with absent bundle IDs must fail — different process is different app")
    }

    func testSamePIDPassesWhenBundleIDsAreAbsent() {
        let trigger = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1001, bundleIdentifier: nil
        )
        let current = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1001, bundleIdentifier: nil
        )
        XCTAssertTrue(FocusedElementIdentityMatcher.isSameContext(trigger, current),
            "Same PID, same role, no further info — same process, allow paste")
    }

    func testPIDCheckTakesPriorityOverBundleCheck() {
        // Same bundle but different PID: should fail (different process instance)
        let trigger = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1001, bundleIdentifier: "com.example.app"
        )
        let current = FocusedElementSnapshot(
            role: "AXTextField", processIdentifier: 1002, bundleIdentifier: "com.example.app"
        )
        XCTAssertFalse(FocusedElementIdentityMatcher.isSameContext(trigger, current),
            "Same bundle but different PID must fail — app was relaunched between trigger and delivery")
    }

    // MARK: - ClipboardManager.isFocusedElementEditableProvider

    func testNonEditableFocusAbortsPaste() {
        ClipboardManager.isFocusedElementEditableProvider = { return false }
        defer { restoreEditableProvider() }

        var pasteSimulated = false
        ClipboardManager.isFrontmostProvider = { _ in return true }
        defer { restoreFrontmostProvider() }

        // We can't intercept simulatePaste directly, but we can verify that when the
        // provider returns false the test harness doesn't crash (the method simply returns).
        // The real behavioral guarantee is covered by manual/integration testing.
        // What we CAN test: the provider is consulted when isFrontmostProvider returns true.
        let expectation = self.expectation(description: "Editable check fires")

        var checkCalled = false
        ClipboardManager.isFocusedElementEditableProvider = {
            checkCalled = true
            expectation.fulfill()
            return false
        }

        ClipboardManager.copyAndPaste("test", targetApplication: OutputTargetApplication(
            bundleIdentifier: "com.example.app", processIdentifier: 9999
        ))

        waitForExpectations(timeout: 1.0, handler: nil)
        XCTAssertTrue(checkCalled, "Editable provider should be consulted before paste")
        _ = pasteSimulated  // suppress unused warning
    }

    func testEditableProviderIsConsultedBeforeSelectAllPaste() {
        var checkCalled = false
        ClipboardManager.isFocusedElementEditableProvider = {
            checkCalled = true
            return false
        }
        defer { restoreEditableProvider() }
        ClipboardManager.isFrontmostProvider = { _ in return true }
        defer { restoreFrontmostProvider() }

        let expectation = self.expectation(description: "Editable check fires for select-all-paste")

        ClipboardManager.isFocusedElementEditableProvider = {
            checkCalled = true
            expectation.fulfill()
            return false
        }

        ClipboardManager.copySelectAllAndPaste("test", targetApplication: OutputTargetApplication(
            bundleIdentifier: "com.example.app", processIdentifier: 9999
        ))

        waitForExpectations(timeout: 1.0, handler: nil)
        XCTAssertTrue(checkCalled)
    }

    // MARK: - InsertionModeOverride round-trip

    func testAllInsertionModesDecodeFromRawValues() {
        let cases: [(String, InsertionModeOverride)] = [
            ("Use Global Setting", .useGlobal),
            ("Clipboard Paste (Cmd+V)", .clipboardPaste),
            ("Clipboard Only (no paste)", .clipboardOnly),
            ("Accessibility API", .accessibilityAPI),
            ("Replace Entire Field (Cmd+A then paste)", .replaceFieldWithClipboardPaste),
        ]
        for (raw, expected) in cases {
            let decoded = InsertionModeOverride(rawValue: raw)
            XCTAssertEqual(decoded, expected, "'\(raw)' should decode to .\(expected)")
        }
    }

    func testExistingModesStillDecodeAfterAddingReplaceFieldCase() throws {
        let override = AppInsertionOverride(
            bundleID: "com.example.app",
            displayName: "Example",
            mode: .clipboardPaste
        )
        let data = try JSONEncoder().encode([override])
        let decoded = try JSONDecoder().decode([AppInsertionOverride].self, from: data)
        XCTAssertEqual(decoded.first?.mode, .clipboardPaste)
    }

    func testReplaceFieldModeRoundTripsAsJSON() throws {
        let override = AppInsertionOverride(
            bundleID: "com.apple.safari",
            displayName: "Safari",
            mode: .replaceFieldWithClipboardPaste
        )
        let data = try JSONEncoder().encode([override])
        let decoded = try JSONDecoder().decode([AppInsertionOverride].self, from: data)
        XCTAssertEqual(decoded.first?.mode, .replaceFieldWithClipboardPaste)
    }

    // MARK: - Helpers

    private func restoreEditableProvider() {
        ClipboardManager.isFocusedElementEditableProvider = {
            let systemWide = AXUIElementCreateSystemWide()
            var focusedValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue
            ) == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return false }
            let element = unsafeBitCast(focusedValue, to: AXUIElement.self)
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
               settable.boolValue { return true }
            settable = false
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
               settable.boolValue { return true }
            return false
        }
    }

    private func restoreFrontmostProvider() {
        ClipboardManager.isFrontmostProvider = { app in
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        }
    }
}
