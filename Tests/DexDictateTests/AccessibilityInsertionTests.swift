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
        return setResults[attribute as String] ?? .attributeUnsupported
    }

    func setCursor(location: Int, element: AXUIElement) {}
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var lastPasteTargetApplication: OutputTargetApplication?

    func copy(_ text: String) { copiedTexts.append(text) }
    func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        pastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
    }
}
