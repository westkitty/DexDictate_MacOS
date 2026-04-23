import AppKit
import Foundation
import ApplicationServices

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

public struct OutputCoordinator: OutputCoordinating {
    private let writer: OutputWriting
    private let contextInspector: FocusedContextInspecting

    public init(
        writer: OutputWriting = ClipboardOutputWriter(),
        contextInspector: FocusedContextInspecting = AccessibilityFocusedContextInspector()
    ) {
        self.writer = writer
        self.contextInspector = contextInspector
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

        if insertionMode != .accessibilityAPI && protectSensitiveContexts {
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
    /// Returns `true` if the insertion succeeded.
    private func insertViaAccessibility(_ text: String) -> Bool {
        guard let element = focusedAXElement() else {
            return false
        }

        if let currentValue = stringAttribute(kAXValueAttribute as String, from: element),
           let selectedRange = selectedTextRange(from: element) {
            let updatedValue = replacingText(in: currentValue, selectedRange: selectedRange, with: text)
            let setValueResult = AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                updatedValue as CFString
            )
            if setValueResult == .success {
                var cursor = CFRange(location: selectedRange.location + text.utf16.count, length: 0)
                if let cursorValue = AXValueCreate(.cfRange, &cursor) {
                    _ = AXUIElementSetAttributeValue(
                        element,
                        kAXSelectedTextRangeAttribute as CFString,
                        cursorValue
                    )
                }
                return true
            }
        }

        let selectedTextResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        if selectedTextResult == .success {
            return true
        }

        if let currentValue = stringAttribute(kAXValueAttribute as String, from: element) {
            let appendResult = AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                (currentValue + text) as CFString
            )
            return appendResult == .success
        }

        return false
    }

    private func activateTargetApplicationIfNeeded(_ targetApplication: OutputTargetApplication?) {
        guard let targetApplication else { return }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier,
              let app = NSRunningApplication(processIdentifier: targetApplication.processIdentifier) else {
            return
        }
        _ = app.activate(options: [])
    }

    private func focusedAXElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(focusedValue, to: AXUIElement.self)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func selectedTextRange(from element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }

        return NSRange(location: max(0, range.location), length: max(0, range.length))
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
