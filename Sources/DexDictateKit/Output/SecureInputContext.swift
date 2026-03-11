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
    private static let tokens = [
        "secure",
        "password",
        "passcode",
        "pin",
        "secret",
        "token",
        "otp",
        "2fa",
        "one-time code",
        "verification code"
    ]

    static func classify(_ snapshot: FocusedElementSnapshot) -> OutputTargetContext {
        let fields = [
            snapshot.subrole,
            snapshot.role,
            snapshot.title,
            snapshot.placeholder,
            snapshot.label,
            snapshot.identifier
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }

        for field in fields {
            if let token = tokens.first(where: { field.contains($0) }) {
                return .sensitive(reason: "Detected likely secure input context (\(token)).")
            }
        }

        return .standard
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
