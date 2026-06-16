import AppKit

/// Reads text content from the currently focused UI element via the Accessibility API.
///
/// Used (opt-in) to prime Whisper's `initial_prompt` with the text the user is currently
/// editing, improving accuracy for proper nouns and sentence continuations. Returns nil
/// whenever the focused element has no readable text or Accessibility permission is
/// unavailable — callers must treat nil as "no context", never as an error.
public struct FocusedTextReader {
    public init() {}

    /// Returns the last `maxChars` characters from the focused text field, or nil if the
    /// focused element exposes no readable string value (or AX is unavailable).
    public func readTail(maxChars: Int = 200) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }

        let element = unsafeBitCast(focusedRef, to: AXUIElement.self)

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let text = valueRef as? String,
              !text.isEmpty else { return nil }

        let tail = String(text.suffix(max(0, maxChars)))
        return tail.isEmpty ? nil : tail
    }
}
