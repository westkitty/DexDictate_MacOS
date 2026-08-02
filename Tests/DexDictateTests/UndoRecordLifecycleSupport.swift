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

    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        currentValue
    }

    func getSelectedRange(element: AXUIElement) -> NSRange? {
        selectedRange
    }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        guard let string = value as? String else { return .failure }
        setValues.append(string)
        mutatedElements.append(element)
        if !contradictReadback {
            currentValue = string
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
