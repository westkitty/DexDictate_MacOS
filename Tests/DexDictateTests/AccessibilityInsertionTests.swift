import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Tests that `OutputCoordinator` preflights `AXUIElementIsAttributeSettable` before
/// attempting `AXUIElementSetAttributeValue`, and logs each failed strategy.
final class AccessibilityInsertionTests: XCTestCase {

    // MARK: - Settability preflight

    func testDoesNotSetValueAttributeWhenNotSettable() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: false,
                          kAXSelectedTextAttribute as String: false]
        ax.stringMap = [kAXValueAttribute as String: "existing text"]
        ax.selectedRangeResult = NSRange(location: 13, length: 0)

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertFalse(
            ax.setCallLog.contains(kAXValueAttribute as String),
            "Should not attempt setValue when kAXValueAttribute is not settable"
        )
    }

    func testDoesNotSetSelectedTextAttributeWhenNotSettable() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: false,
                          kAXSelectedTextAttribute as String: false]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertFalse(
            ax.setCallLog.contains(kAXSelectedTextAttribute as String),
            "Should not attempt setValue when kAXSelectedTextAttribute is not settable"
        )
    }

    func testSetValueCalledWhenValueAttributeIsSettable() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true,
                          kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello"]
        ax.selectedRangeResult = NSRange(location: 5, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(text: " world", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertTrue(
            ax.setCallLog.contains(kAXValueAttribute as String),
            "Should attempt setValue when kAXValueAttribute is settable"
        )
    }

    func testFallsBackToSelectedTextWhenValueAttributeNotSettableButSelectedTextIs() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: false,
                          kAXSelectedTextAttribute as String: true]
        ax.setResults = [kAXSelectedTextAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertTrue(
            ax.setCallLog.contains(kAXSelectedTextAttribute as String),
            "Should attempt selectedText strategy when value attribute is not settable"
        )
        XCTAssertFalse(
            ax.setCallLog.contains(kAXValueAttribute as String),
            "Should NOT attempt value set when it is not settable"
        )
    }

    // MARK: - Strategy 3 removal

    func testWhenBothStrategiesFailOnlyTwoSetAttemptsOccurAndNothingIsAppended() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true, kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "existing text"]
        ax.selectedRangeResult = NSRange(location: 13, length: 0)
        // Both strategies fail
        ax.setResults = [kAXValueAttribute as String: .failure, kAXSelectedTextAttribute as String: .failure]
        let writer = MockOutputWriter()

        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)
        _ = coordinator.deliver(text: "new", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        // Exactly two set attempts: Strategy 1 (value) and Strategy 2 (selectedText).
        // No third attempt with the appended value ("existing textnew").
        XCTAssertEqual(ax.setCallLog.count, 2,
            "Expected exactly 2 AX set attempts (Strategy 1 + Strategy 2), got \(ax.setCallLog.count)")
        XCTAssertEqual(ax.setCallLog[0], kAXValueAttribute as String)
        XCTAssertEqual(ax.setCallLog[1], kAXSelectedTextAttribute as String)
        // Fell back to clipboard paste — did not append
        XCTAssertEqual(writer.pastedTexts, ["new"])
    }

    func testWhenValueNotSettableOnlySelectedTextStrategyIsAttempted() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: false, kAXSelectedTextAttribute as String: true]
        ax.setResults = [kAXSelectedTextAttribute as String: .failure]
        let writer = MockOutputWriter()

        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)
        _ = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCallLog.count, 1, "Only Strategy 2 (selectedText) should be attempted when value not settable")
        XCTAssertEqual(ax.setCallLog[0], kAXSelectedTextAttribute as String)
        XCTAssertEqual(writer.pastedTexts, ["hello"])
    }

    // MARK: - Cursor offset (B)

    func testCursorOffsetASCII() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 5)  // utf16.count == unicodeScalars.count for ASCII
    }

    func testCursorOffsetEmojiUsesUnicodeScalarsNotUTF16() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // "hello 🎉": 6 ASCII + 1 emoji = 7 unicode scalars, but 8 UTF-16 code units
        _ = coordinator.deliver(text: "hello 🎉", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 7,
            "Cursor should be at 7 (unicodeScalars.count), not 8 (utf16.count)")
    }

    func testCursorOffsetCJK() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // CJK characters are in the BMP: utf16 == unicodeScalars
        _ = coordinator.deliver(text: "你好世界", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 4)
    }

    func testCursorOffsetMixedEmojiAndCJK() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // "hi 🎉 世界": h(1)i(1) (1)🎉(1 scalar,2 utf16) (1)世(1)界(1) = 7 scalars, 8 utf16
        _ = coordinator.deliver(text: "hi 🎉 世界", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 7,
            "Mixed emoji+CJK: 7 unicode scalars, cursor should land at 7")
    }

    func testCursorOffsetNonZeroInitialRange() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "abc"]
        ax.selectedRangeResult = NSRange(location: 3, length: 0)  // cursor at end
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // Inserting emoji at position 3: cursor should land at 3+1=4 (not 3+2 for UTF-16)
        _ = coordinator.deliver(text: "🎉", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 4)
    }

    func testReturnsFalseAndFallsThroughToClipboardWhenNoFocusedElement() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = false
        let writer = MockOutputWriter()

        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)
        let decision = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.pastedTexts, ["hello"], "Should fall back to clipboard when no focused element")
        XCTAssertTrue(ax.setCallLog.isEmpty, "No AX set calls should occur without a focused element")
    }
}

// MARK: - Test doubles

final class MockAccessibilityOperator: AccessibilityElementOperating {
    var hasFocusedElement: Bool = false
    var settableMap: [String: Bool] = [:]
    var stringMap: [String: String] = [:]
    var selectedRangeResult: NSRange? = nil
    var setResults: [String: AXError] = [:]
    private(set) var setCallLog: [String] = []
    private(set) var setCursorLocations: [Int] = []
    private(set) var lastSetValue: String?

    func focusedElement() -> AXUIElement? {
        hasFocusedElement ? AXUIElementCreateSystemWide() : nil
    }

    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        settableMap[attribute as String] ?? false
    }

    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        stringMap[attribute as String]
    }

    func getSelectedRange(element: AXUIElement) -> NSRange? {
        selectedRangeResult
    }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        setCallLog.append(attribute as String)
        lastSetValue = value as? String
        return setResults[attribute as String] ?? .attributeUnsupported
    }

    func setCursor(location: Int, element: AXUIElement) {
        setCursorLocations.append(location)
    }
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var selectAllAndPastedTexts: [String] = []
    var lastPasteTargetApplication: OutputTargetApplication?

    func copy(_ text: String) { copiedTexts.append(text) }
    func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        pastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
    }
    func selectAllAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        selectAllAndPastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
    }
}
