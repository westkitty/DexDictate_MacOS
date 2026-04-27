import ApplicationServices
import Foundation

struct FocusedElementSnapshot: Equatable {
    var role: String?
    var subrole: String?
    var title: String?
    var placeholder: String?
    var label: String?
    var identifier: String?
}

enum SensitiveContextHeuristic {
    // Strong signals: substring-matched across all AX attributes.
    // These strings don't occur as casual programming identifiers.
    private static let strongTokens = [
        "secure",
        "password",
        "passcode",
        "otp",
        "2fa",
        "one-time code",
        "verification code",
    ]

    // Weak signals: word-boundary-matched and only checked in human-readable fields
    // (title, placeholder, label). Excluded from role/subrole/identifier to avoid
    // false positives on programmer-assigned names like "tokenField" or "clientSecret".
    private static let weakTokens = [
        "pin",
        "token",
        "secret",
    ]

    static func classify(_ snapshot: FocusedElementSnapshot) -> OutputTargetContext {
        let allFields = [
            snapshot.subrole,
            snapshot.role,
            snapshot.title,
            snapshot.placeholder,
            snapshot.label,
            snapshot.identifier,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }

        for token in strongTokens {
            if allFields.contains(where: { $0.contains(token) }) {
                return .sensitive(reason: "Detected likely secure input context (\(token)).")
            }
        }

        let semanticFields = [
            snapshot.title,
            snapshot.placeholder,
            snapshot.label,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }

        for token in weakTokens {
            if semanticFields.contains(where: { $0.containsWholeWord(token) }) {
                return .sensitive(reason: "Detected likely secure input context (\(token)).")
            }
        }

        return .standard
    }
}

private extension String {
    /// Returns true if this string contains `word` as a whole token, using non-alphanumeric/
    /// non-underscore boundaries. Prevents "pin" from matching "opinion" or "spinControl".
    func containsWholeWord(_ word: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "(?i)(?<![a-zA-Z0-9_])\(escaped)(?![a-zA-Z0-9_])"
        return range(of: pattern, options: .regularExpression) != nil
    }
}

public struct AccessibilityFocusedContextInspector: FocusedContextInspecting {
    public init() {}

    public func inspectFocusedContext() -> OutputTargetContext {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success, let focusedValue else {
            return .standard
        }

        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .standard
        }

        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        let snapshot = FocusedElementSnapshot(
            role: stringAttribute(kAXRoleAttribute as String, from: focusedElement),
            subrole: stringAttribute(kAXSubroleAttribute as String, from: focusedElement),
            title: stringAttribute(kAXTitleAttribute as String, from: focusedElement),
            placeholder: stringAttribute("AXPlaceholderValue", from: focusedElement),
            label: stringAttribute(kAXDescriptionAttribute as String, from: focusedElement),
            identifier: stringAttribute("AXIdentifier", from: focusedElement)
        )

        return SensitiveContextHeuristic.classify(snapshot)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else { return nil }
        return value as? String
    }
}
