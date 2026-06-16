import Foundation

/// Builds the single `initial_prompt` string passed to whisper.cpp by combining the static
/// domain-bias vocabulary prompt with optional dynamic focused-field context.
///
/// Kept pure (no AX / no AppKit) so the combination + bounding logic is unit-testable.
public enum DictationContextPrompt {
    /// Combines a domain-bias prompt with focused-field context into one initial prompt.
    ///
    /// - Both inputs may be nil or empty; whitespace-only inputs are treated as empty.
    /// - The domain bias comes first (stable vocabulary), then the focused context (recent text).
    /// - The result is bounded to `maxChars`, keeping the **tail** so the most recent context —
    ///   the part most useful for continuing the current sentence — is never truncated away.
    /// - Returns nil when nothing usable remains, so callers can clear the prompt.
    public static func combine(domainBias: String?, focusedContext: String?, maxChars: Int = 240) -> String? {
        let parts = [domainBias, focusedContext]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }

        let joined = parts.joined(separator: " ")
        guard maxChars > 0 else { return nil }
        if joined.count > maxChars {
            return String(joined.suffix(maxChars))
        }
        return joined
    }
}
