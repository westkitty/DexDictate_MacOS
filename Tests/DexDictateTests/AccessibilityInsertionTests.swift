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
        ax.stringMap = [kAXValueAttribute as String: "existing"]
        ax.selectedRangeResult = NSRange(location: 8, length: 0)
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
        ax.stringMap = [kAXValueAttribute as String: "existing"]
        ax.selectedRangeResult = NSRange(location: 8, length: 0)
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

    func testCursorOffsetEmojiUsesUTF16() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // Accessibility text ranges use UTF-16 code units.
        _ = coordinator.deliver(text: "hello 🎉", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 8)
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
        // "hi 🎉 世界" occupies 8 UTF-16 code units.
        _ = coordinator.deliver(text: "hi 🎉 世界", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 8)
    }

    func testCursorOffsetNonZeroInitialRange() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "abc"]
        ax.selectedRangeResult = NSRange(location: 3, length: 0)  // cursor at end
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        // Inserting an emoji at UTF-16 position 3 advances by two code units.
        _ = coordinator.deliver(text: "🎉", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.setCursorLocations.last, 5)
    }

    func testCursorOffsetCombiningSequenceAndFamilyEmojiUsesUTF16() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(
            text: "e\u{301}👨‍👩‍👧‍👦",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(ax.setCursorLocations.last, 13)
    }

    func testMixedTextInsertionUsesUTF16RangeBeforeAndAfterCursor() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "A😀Z"]
        ax.selectedRangeResult = NSRange(location: 3, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let coordinator = OutputCoordinator(axOperator: ax)
        _ = coordinator.deliver(
            text: "e\u{301}漢",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "A😀e\u{301}漢Z")
        XCTAssertEqual(ax.setCursorLocations.last, 6)
    }

    func testSuccessfulSetterWithContradictoryReadbackIsUnverified() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello"]
        ax.selectedRangeResult = NSRange(location: 5, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]
        ax.appliesSuccessfulMutations = false
        let writer = MockOutputWriter()

        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)
        let decision = coordinator.deliver(
            text: " world",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertNil(decision.undoContext)
        XCTAssertTrue(writer.pastedTexts.isEmpty, "Do not duplicate a mutation that may have occurred")
    }

    func testReturnsFalseAndFallsThroughToClipboardWhenNoFocusedElement() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = false
        let writer = MockOutputWriter()

        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)
        let decision = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["hello"], "Should fall back to clipboard when no focused element")
        XCTAssertTrue(ax.setCallLog.isEmpty, "No AX set calls should occur without a focused element")
    }
}

// MARK: - Test doubles

final class MockAccessibilityOperator: AccessibilityElementOperating {
    let focused = AXUIElementCreateSystemWide()
    var hasFocusedElement: Bool = false
    var settableMap: [String: Bool] = [:]
    var stringMap: [String: String] = [:]
    var selectedRangeResult: NSRange?
    var setResults: [String: AXError] = [:]
    var appliesSuccessfulMutations = true
    /// `AXNumberOfCharacters`. `nil` models a target that doesn't publish the attribute.
    /// When set, it tracks applied mutations the way a real host does — otherwise a field
    /// that started empty would keep claiming zero committed characters after insertion.
    var numberOfCharacters: Int?
    private(set) var setCallLog: [String] = []
    private(set) var setCursorLocations: [Int] = []
    private(set) var lastSetValue: String?

    func focusedElement() -> AXUIElement? {
        hasFocusedElement ? focused : nil
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

    func getNumberOfCharacters(element: AXUIElement) -> Int? { numberOfCharacters }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        setCallLog.append(attribute as String)
        lastSetValue = value as? String
        let result = setResults[attribute as String] ?? .attributeUnsupported
        guard result == .success, appliesSuccessfulMutations else { return result }
        if attribute as String == kAXValueAttribute as String, let value = value as? String {
            applyValue(value)
        } else if attribute as String == kAXSelectedTextAttribute as String,
                  let text = value as? String {
            // Splice into the *committed* value at the *logical* range, which is what a real
            // editor does — a host rendering a placeholder inserts into its empty content, it
            // does not splice into the placeholder string it happens to expose via AXValue.
            let snapshot = editableTextSnapshot(element: element)
            if let currentValue = snapshot.committedValue,
               let range = snapshot.logicalRange,
               let updated = accessibilityReplacingText(in: currentValue, range: range, with: text) {
                applyValue(updated)
            }
        }
        return result
    }

    private func applyValue(_ value: String) {
        stringMap[kAXValueAttribute as String] = value
        if numberOfCharacters != nil {
            numberOfCharacters = (value as NSString).length
        }
    }

    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError {
        setCursorLocations.append(location)
        if appliesSuccessfulMutations {
            selectedRangeResult = NSRange(location: location, length: 0)
        }
        return .success
    }
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var selectAllAndPastedTexts: [String] = []
    var lastPasteTargetApplication: OutputTargetApplication?

    @discardableResult
    func copy(_ text: String) -> Bool {
        copiedTexts.append(text)
        return true
    }
    @discardableResult
    func copyAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        pastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
        return true
    }
    @discardableResult
    func selectAllAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        selectAllAndPastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
        return true
    }
}
