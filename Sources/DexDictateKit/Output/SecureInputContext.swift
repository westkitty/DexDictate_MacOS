import AppKit
import ApplicationServices
import Foundation

struct FocusedElementSnapshot: Equatable {
    var role: String?
    var subrole: String?
    var title: String?
    var placeholder: String?
    var label: String?
    var identifier: String?
    /// PID of the application that owned the focused element when captured.
    var processIdentifier: pid_t?
    /// Bundle identifier of the application that owned the focused element when captured.
    var bundleIdentifier: String?

    init(
        role: String? = nil,
        subrole: String? = nil,
        title: String? = nil,
        placeholder: String? = nil,
        label: String? = nil,
        identifier: String? = nil,
        processIdentifier: pid_t? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.role = role
        self.subrole = subrole
        self.title = title
        self.placeholder = placeholder
        self.label = label
        self.identifier = identifier
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
    }

    /// Captures a snapshot of the currently focused AX element.
    /// Returns `nil` if no focused element exists or AX access is unavailable.
    static func captureFromSystem() -> FocusedElementSnapshot? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }

        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)

        return FocusedElementSnapshot(
            role: axStringAttr(kAXRoleAttribute, from: element),
            subrole: axStringAttr(kAXSubroleAttribute, from: element),
            title: axStringAttr(kAXTitleAttribute, from: element),
            placeholder: axStringAttr("AXPlaceholderValue", from: element),
            label: axStringAttr(kAXDescriptionAttribute, from: element),
            identifier: axStringAttr("AXIdentifier", from: element),
            processIdentifier: pid > 0 ? pid : nil,
            bundleIdentifier: app?.bundleIdentifier
        )
    }
}

/// Determines whether two element snapshots represent the same focused text field.
/// Used to detect whether focus shifted during transcription.
/// Errs toward false negatives (permitting paste) over false positives (blocking paste).
enum FocusedElementIdentityMatcher {
    /// Returns `true` if `trigger` and `current` are plausibly the same element.
    ///
    /// Matching rules (in order of strength):
    /// 1. If apps differ by bundle identifier → fail.
    /// 2. If both have an AX `identifier` → compare directly.
    /// 3. If role differs → fail.
    /// 4. If semantic fields (title/placeholder/label) are available on both, at least one must match.
    /// 5. If current is nil (AX unavailable) → allow paste conservatively.
    static func isSameContext(
        _ trigger: FocusedElementSnapshot,
        _ current: FocusedElementSnapshot?,
        targetBundleID: String? = nil
    ) -> Bool {
        guard let current else {
            return true  // can't snapshot → conservative allow
        }

        // 1. App identity check
        let triggerBundle = trigger.bundleIdentifier ?? targetBundleID
        let currentBundle = current.bundleIdentifier
        if let t = triggerBundle, let c = currentBundle, t != c {
            return false
        }

        // 2. Strong AX identifier
        if let tid = trigger.identifier, !tid.isEmpty,
           let cid = current.identifier, !cid.isEmpty {
            return tid == cid
        }

        // 3. Role must be compatible
        if let tr = trigger.role, let cr = current.role, tr != cr {
            return false
        }

        // 4. At least one semantic field must match when both have any
        let triggerSemantic = [trigger.title, trigger.placeholder, trigger.label]
            .compactMap { $0 }.filter { !$0.isEmpty }
        let currentSemantic = [current.title, current.placeholder, current.label]
            .compactMap { $0 }.filter { !$0.isEmpty }
        if !triggerSemantic.isEmpty && !currentSemantic.isEmpty {
            return !Set(triggerSemantic).isDisjoint(with: Set(currentSemantic))
        }

        // 5. No discriminating info → allow
        return true
    }
}

private func axStringAttr(_ attribute: Any, from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    let key = attribute as! CFString
    guard AXUIElementCopyAttributeValue(element, key, &value) == .success,
          let value else { return nil }
    return value as? String
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
