import ApplicationServices
import Foundation
@testable import DexDictateKit

/// Records which element each mutation targeted, so "never touch the wrong field" is an
/// assertion rather than an assumption.
final class UndoFakeOperator: AccessibilityElementOperating {
    private let focused: AXUIElement
    var currentValue: String?
    var selectedRange: NSRange? = NSRange(location: 11, length: 0)
    var settableAttributes: Set<String> = [kAXValueAttribute as String]
    var elementIsAlive = true
    var contradictReadback = false

    private(set) var setValues: [String] = []
    private(set) var mutatedElements: [AXUIElement] = []
    private(set) var focusedElementCallCount = 0

    init(focusedElement: AXUIElement, currentValue: String?) {
        self.focused = focusedElement
        self.currentValue = currentValue
    }

    func focusedElement() -> AXUIElement? {
        focusedElementCallCount += 1
        return focused
    }

    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        settableAttributes.contains(attribute as String)
    }

    /// Answers only for `kAXValueAttribute`. Returning `currentValue` for every attribute
    /// would make the fake report its own value as its `AXPlaceholderValue`, i.e. claim to be
    /// an empty field rendering a placeholder — which is a real state the production code now
    /// distinguishes, so the fake has to stop conflating it.
    var placeholderValue: String?
    var numberOfCharacters: Int?

    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        switch attribute as String {
        case kAXValueAttribute as String: return currentValue
        case AccessibilityEditableTextSnapshot.placeholderAttribute: return placeholderValue
        default: return nil
        }
    }

    func getNumberOfCharacters(element: AXUIElement) -> Int? { numberOfCharacters }

    func getSelectedRange(element: AXUIElement) -> NSRange? {
        selectedRange
    }

    /// What `AXValue` reports once the field has been written back to `""`. Web composers
    /// re-render their placeholder there, so this models the real readback undo has to cope
    /// with rather than assuming an emptied field reads back as an empty string.
    var valueAfterClearing: String?

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        guard let string = value as? String else { return .failure }
        setValues.append(string)
        mutatedElements.append(element)
        if !contradictReadback {
            currentValue = (string.isEmpty ? valueAfterClearing : nil) ?? string
        }
        return .success
    }

    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError {
        selectedRange = NSRange(location: location, length: 0)
        return .success
    }

    func isElementAlive(_ element: AXUIElement) -> Bool { elementIsAlive }
}
