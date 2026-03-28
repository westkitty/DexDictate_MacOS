// Sources/DexDictateKit/Output/FocusedTextReader.swift
import AppKit

/// Reads text content from the currently focused UI element via the Accessibility API.
public struct FocusedTextReader {
    public init() {}

    /// Returns the last `maxChars` characters from the focused text field, or nil
    /// if the focused element has no readable text or Accessibility permission is unavailable.
    public func readTail(maxChars: Int = 200) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }

        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focusedRef, to: AXUIElement.self)

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let text = valueRef as? String,
              !text.isEmpty else { return nil }

        let tail = String(text.suffix(maxChars))
        return tail.isEmpty ? nil : tail
    }
}
