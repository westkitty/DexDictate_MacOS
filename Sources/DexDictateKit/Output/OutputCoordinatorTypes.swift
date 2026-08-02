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
    /// Accessibility readback confirmed the target field mutation and resulting selection.
    case pastedToActiveApp
    case copiedOnly(reason: String)
    case blocked(reason: String)
    case failed(reason: String)
    /// Synthetic paste events were scheduled or posted, but macOS offers no delivery receipt.
    case requestedButUnverified
}

public extension OutputDelivery {
    /// Why this delivery left nothing exact to reverse. Shown on the disabled undo control,
    /// so "no button appeared" becomes a stated fact rather than a silent absence.
    var undoIneligibilityDetail: String {
        switch self {
        case .pastedToActiveApp:
            return "the insertion was confirmed."
        case .savedOnly:
            return "auto-paste is off, so it was only saved to history."
        case .copiedOnly(let reason):
            return "it was copied to the clipboard instead of inserted (\(reason))."
        case .requestedButUnverified:
            return "it was delivered by clipboard paste, which macOS can't confirm, so there is no exact insertion to reverse."
        case .blocked(let reason):
            return "delivery was blocked (\(reason))."
        case .failed(let reason):
            return "delivery failed (\(reason))."
        }
    }
}

public struct OutputDeliveryDecision: Equatable {
    public let delivery: OutputDelivery
    /// Populated only when `delivery == .pastedToActiveApp`; carries what's needed to
    /// reverse this specific insertion later via `DictationUndoManager`. `nil` when nothing
    /// was confirmed or when the exact target and pre-insertion state were unavailable.
    public let undoContext: DictationUndoContext?

    public init(delivery: OutputDelivery, undoContext: DictationUndoContext? = nil) {
        self.delivery = delivery
        self.undoContext = undoContext
    }
}

/// Retains the exact Accessibility element used for a confirmed insertion. `CFEqual`
/// compares the underlying AX object rather than broad app or role metadata.
final class AccessibilityElementReference: Equatable {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    static func == (lhs: AccessibilityElementReference, rhs: AccessibilityElementReference) -> Bool {
        CFEqual(lhs.element, rhs.element)
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
    let targetElement: AccessibilityElementReference?

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
        self.targetElement = nil
    }

    init(
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication?,
        targetElement: AXUIElement
    ) {
        self.insertedText = insertedText
        self.previousFieldValue = previousFieldValue
        self.replacementRange = replacementRange
        self.targetApplication = targetApplication
        self.targetElement = AccessibilityElementReference(targetElement)
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
    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError
    /// Distinguishes a destroyed/replaced element from a transient read failure, so undo can
    /// retain a still-valid record instead of discarding it on the first hiccup.
    func isElementAlive(_ element: AXUIElement) -> Bool
}

public extension AccessibilityElementOperating {
    /// Conservative default: assume the element is alive. Retaining a record is safe because
    /// every mutation is still gated on exact identity, content, range, and readback checks;
    /// discarding one on weak evidence is what silently loses the feature.
    func isElementAlive(_ element: AXUIElement) -> Bool { true }
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
        return NSRange(location: range.location, length: range.length)
    }

    public func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(element, attribute, value)
    }

    /// `kAXErrorInvalidUIElement` is the system's definitive "this element is gone" answer.
    /// Any other failure (timeout, not-implemented, permission) is treated as transient.
    public func isElementAlive(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return result != .invalidUIElement
    }

    @discardableResult
    public func setCursor(location: Int, element: AXUIElement) -> AXError {
        var cursor = CFRange(location: location, length: 0)
        guard let cursorValue = AXValueCreate(.cfRange, &cursor) else { return .failure }
        return AXUIElementSetAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, cursorValue
        )
    }
}

public protocol OutputWriting {
    @discardableResult
    func copy(_ text: String) -> Bool
    @discardableResult
    func copyAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool
    /// Selects all text in the focused field (Cmd+A) then pastes (Cmd+V).
    @discardableResult
    func selectAllAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool
}

public protocol FocusedContextInspecting {
    func inspectFocusedContext() -> OutputTargetContext
}

public protocol OutputCoordinating {
    // Completion is additive so existing five-argument call sites keep their shape.
    // swiftlint:disable:next function_parameter_count
    func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDeliveryDecision) -> Void
    ) -> OutputDeliveryDecision
}

public extension OutputCoordinating {
    func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride = .clipboardPaste,
        targetApplication: OutputTargetApplication? = nil
    ) -> OutputDeliveryDecision {
        deliver(
            text: text,
            autoPaste: autoPaste,
            protectSensitiveContexts: protectSensitiveContexts,
            insertionMode: insertionMode,
            targetApplication: targetApplication,
            completion: { _ in }
        )
    }
}

public struct ClipboardOutputWriter: OutputWriting {
    public init() {}

    @discardableResult
    public func copy(_ text: String) -> Bool {
        ClipboardManager.copy(text)
    }

    @discardableResult
    public func copyAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        ClipboardManager.copyAndPaste(
            text,
            targetApplication: targetApplication,
            completion: completion
        )
    }

    @discardableResult
    public func selectAllAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        ClipboardManager.copySelectAllAndPaste(
            text,
            targetApplication: targetApplication,
            completion: completion
        )
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

/// Accessibility text ranges are UTF-16/NSString ranges. Invalid input is rejected rather
/// than clamped into a different mutation target.
func isValidAccessibilityRange(_ range: NSRange, in value: String) -> Bool {
    let utf16Length = (value as NSString).length
    guard range.location >= 0, range.length >= 0, range.location <= utf16Length else {
        return false
    }
    return range.length <= utf16Length - range.location
}

func accessibilityReplacingText(in currentValue: String, range: NSRange, with replacement: String) -> String? {
    guard isValidAccessibilityRange(range, in: currentValue) else { return nil }
    let currentNSString = currentValue as NSString
    return currentNSString.replacingCharacters(in: range, with: replacement)
}
