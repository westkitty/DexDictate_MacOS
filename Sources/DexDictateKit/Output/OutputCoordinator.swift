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

    public init(delivery: OutputDelivery) {
        self.delivery = delivery
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

public struct OutputCoordinator: OutputCoordinating {
    private let writer: OutputWriting
    private let contextInspector: FocusedContextInspecting
    private let applicationActivator: OutputApplicationActivating
    private let axOperator: AccessibilityElementOperating

    public init(
        writer: OutputWriting = ClipboardOutputWriter(),
        contextInspector: FocusedContextInspecting = AccessibilityFocusedContextInspector(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.init(
            writer: writer,
            contextInspector: contextInspector,
            applicationActivator: AppKitOutputApplicationActivator(),
            axOperator: axOperator
        )
    }

    init(
        writer: OutputWriting,
        contextInspector: FocusedContextInspecting,
        applicationActivator: OutputApplicationActivating = AppKitOutputApplicationActivator(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.writer = writer
        self.contextInspector = contextInspector
        self.applicationActivator = applicationActivator
        self.axOperator = axOperator
    }

    public func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride = .clipboardPaste,
        targetApplication: OutputTargetApplication? = nil
    ) -> OutputDeliveryDecision {
        guard autoPaste else {
            return OutputDeliveryDecision(delivery: .savedOnly)
        }

        if insertionMode == .clipboardOnly {
            writer.copy(text)
            return OutputDeliveryDecision(delivery: .copiedOnly(reason: "Per-app clipboard-only mode"))
        }

        activateTargetApplicationIfNeeded(targetApplication)

        if protectSensitiveContexts {
            let context = contextInspector.inspectFocusedContext()
            if case .sensitive(let reason) = context {
                writer.copy(text)
                return OutputDeliveryDecision(delivery: .copiedOnly(reason: reason))
            }
        }

        if insertionMode == .accessibilityAPI {
            if insertViaAccessibility(text) {
                return OutputDeliveryDecision(delivery: .pastedToActiveApp)
            }
        }

        writer.copyAndPaste(text, targetApplication: targetApplication)
        return OutputDeliveryDecision(delivery: .pastedToActiveApp)
    }

    /// Attempts to insert text at the current cursor position via the Accessibility API.
    /// Preflights each attribute with `AXUIElementIsAttributeSettable` before attempting
    /// a set, and logs each failed strategy with the returned `AXError`.
    /// Returns `true` if any strategy succeeded.
    private func insertViaAccessibility(_ text: String) -> Bool {
        guard let element = axOperator.focusedElement() else {
            Safety.log("insertViaAccessibility() — no focused AX element", category: .output)
            return false
        }

        let valueSettable = axOperator.isSettable(kAXValueAttribute as CFString, element: element)

        // Strategy 1: replace the selected range inside the full value
        if valueSettable,
           let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element),
           let selectedRange = axOperator.getSelectedRange(element: element) {
            let updatedValue = replacingText(in: currentValue, selectedRange: selectedRange, with: text)
            let result = axOperator.set(updatedValue as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
            if result == .success {
                axOperator.setCursor(location: selectedRange.location + text.utf16.count, element: element)
                return true
            }
            Safety.log("insertViaAccessibility() — strategy 1 (value+range) failed: AXError \(result.rawValue)", category: .output)
        } else if !valueSettable {
            Safety.log("insertViaAccessibility() — strategies 1 and 3 skipped: kAXValueAttribute not settable", category: .output)
        }

        // Strategy 2: replace the selected text directly
        let selectedTextSettable = axOperator.isSettable(kAXSelectedTextAttribute as CFString, element: element)
        if selectedTextSettable {
            let result = axOperator.set(text as CFTypeRef, for: kAXSelectedTextAttribute as CFString, element: element)
            if result == .success { return true }
            Safety.log("insertViaAccessibility() — strategy 2 (selectedText) failed: AXError \(result.rawValue)", category: .output)
        } else {
            Safety.log("insertViaAccessibility() — strategy 2 (selectedText) skipped: attribute not settable", category: .output)
        }

        // Strategy 3: append to the full value
        if valueSettable,
           let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element) {
            let result = axOperator.set((currentValue + text) as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
            if result == .success { return true }
            Safety.log("insertViaAccessibility() — strategy 3 (append) failed: AXError \(result.rawValue)", category: .output)
        }

        Safety.log("insertViaAccessibility() — all strategies failed; falling back to clipboard", category: .output)
        return false
    }

    private func activateTargetApplicationIfNeeded(_ targetApplication: OutputTargetApplication?) {
        guard let targetApplication else { return }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier else {
            return
        }
        guard targetApplication.processIdentifier != applicationActivator.frontmostProcessIdentifier else {
            return
        }

        applicationActivator.activate(targetApplication)
    }

    private func replacingText(in currentValue: String, selectedRange: NSRange, with replacement: String) -> String {
        let currentNSString = currentValue as NSString
        let maxLocation = currentNSString.length
        let clampedLocation = min(max(0, selectedRange.location), maxLocation)
        let clampedLength = min(max(0, selectedRange.length), maxLocation - clampedLocation)
        let clampedRange = NSRange(location: clampedLocation, length: clampedLength)
        return currentNSString.replacingCharacters(in: clampedRange, with: replacement)
    }
}
