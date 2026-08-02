import AppKit
import ApplicationServices
import Foundation

public struct OutputTargetApplication: Equatable {
    public let bundleIdentifier: String
    public let processIdentifier: pid_t

    public init(bundleIdentifier: String, processIdentifier: pid_t) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

public enum OutputTargetContext: Equatable {
    case standard
    case sensitive(reason: String)
}

public enum OutputDelivery: Equatable {
    case savedOnly
    case pastedToActiveApp
    case copiedOnly(reason: String)
}

public struct OutputDeliveryDecision: Equatable {
    public let delivery: OutputDelivery
    /// Populated only when `delivery == .pastedToActiveApp`; carries what's needed to
    /// reverse this specific insertion later via `DictationUndoManager`. `nil` when nothing
    /// was actually inserted, or `undoContext` fields are `nil` when Accessibility couldn't
    /// read the relevant state for this particular field.
    public let undoContext: DictationUndoContext?

    public init(delivery: OutputDelivery, undoContext: DictationUndoContext? = nil) {
        self.delivery = delivery
        self.undoContext = undoContext
    }
}

/// Everything needed to reverse a single successful insertion later. Captured at delivery
/// time because the target field's pre-insertion value and cursor position can't be
/// reconstructed after the fact — once anything else happens in that field, they're gone.
public struct DictationUndoContext: Equatable {
    /// The exact text this delivery actually inserted (after auto-spacing).
    public let insertedText: String
    /// Full field value immediately before insertion, when readable via Accessibility.
    /// `nil` when the field didn't expose a readable `kAXValueAttribute` at delivery time.
    public let previousFieldValue: String?
    /// Range inside `previousFieldValue` that `insertedText` replaced (usually zero-length,
    /// at the cursor; non-zero when replacing a selection or an entire field).
    public let replacementRange: NSRange?
    public let targetApplication: OutputTargetApplication?

    public init(
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication?
    ) {
        self.insertedText = insertedText
        self.previousFieldValue = previousFieldValue
        self.replacementRange = replacementRange
        self.targetApplication = targetApplication
    }
}

/// Wraps the raw Accessibility API calls used during text insertion so they can be
/// replaced with a mock in unit tests without requiring real on-screen UI elements.
public protocol AccessibilityElementOperating {
    func focusedElement() -> AXUIElement?
    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool
    func getString(_ attribute: CFString, element: AXUIElement) -> String?
    func getSelectedRange(element: AXUIElement) -> NSRange?
    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError
    func setCursor(location: Int, element: AXUIElement)
}

/// Production implementation that calls the real macOS Accessibility APIs.
public struct SystemAccessibilityElementOperator: AccessibilityElementOperating {
    public init() {}

    public func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(focusedValue, to: AXUIElement.self)
    }

    public func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, attribute, &settable)
        return settable.boolValue
    }

    public func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    public func getSelectedRange(element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return NSRange(location: max(0, range.location), length: max(0, range.length))
    }

    public func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(element, attribute, value)
    }

    public func setCursor(location: Int, element: AXUIElement) {
        var cursor = CFRange(location: location, length: 0)
        if let cursorValue = AXValueCreate(.cfRange, &cursor) {
            _ = AXUIElementSetAttributeValue(
                element, kAXSelectedTextRangeAttribute as CFString, cursorValue
            )
        }
    }
}

public protocol OutputWriting {
    func copy(_ text: String)
    func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?)
    /// Selects all text in the focused field (Cmd+A) then pastes (Cmd+V).
    func selectAllAndPaste(_ text: String, targetApplication: OutputTargetApplication?)
}

public protocol FocusedContextInspecting {
    func inspectFocusedContext() -> OutputTargetContext
}

public protocol OutputCoordinating {
    func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride,
        targetApplication: OutputTargetApplication?
    ) -> OutputDeliveryDecision
}

public struct ClipboardOutputWriter: OutputWriting {
    public init() {}

    public func copy(_ text: String) {
        ClipboardManager.copy(text)
    }

    public func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        ClipboardManager.copyAndPaste(text, targetApplication: targetApplication)
    }

    public func selectAllAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        ClipboardManager.copySelectAllAndPaste(text, targetApplication: targetApplication)
    }
}

protocol OutputApplicationActivating {
    var frontmostProcessIdentifier: pid_t? { get }
    func activate(_ targetApplication: OutputTargetApplication)
}

struct AppKitOutputApplicationActivator: OutputApplicationActivating {
    var frontmostProcessIdentifier: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func activate(_ targetApplication: OutputTargetApplication) {
        guard let app = NSRunningApplication(processIdentifier: targetApplication.processIdentifier) else {
            return
        }
        _ = app.activate(options: [])
    }
}

/// Splices `replacement` into `currentValue` at `range`, clamping the range to the string's
/// bounds. Shared by `OutputCoordinator.insertViaAccessibility` (performing an insertion) and
/// `DictationUndoManager` (verifying/reversing one), so both sides of an insert/undo pair
/// agree on exactly the same substitution semantics.
func accessibilityReplacingText(in currentValue: String, range: NSRange, with replacement: String) -> String {
    let currentNSString = currentValue as NSString
    let maxLocation = currentNSString.length
    let clampedLocation = min(max(0, range.location), maxLocation)
    let clampedLength = min(max(0, range.length), maxLocation - clampedLocation)
    let clampedRange = NSRange(location: clampedLocation, length: clampedLength)
    return currentNSString.replacingCharacters(in: clampedRange, with: replacement)
}
