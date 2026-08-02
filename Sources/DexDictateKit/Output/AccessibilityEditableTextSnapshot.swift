import ApplicationServices
import Foundation

/// How confident we are about whether an editable Accessibility target actually holds
/// committed text, as opposed to a placeholder the host is rendering into `AXValue`.
public enum AccessibilityTextEmptiness: String, Equatable, Sendable {
    /// The field holds no committed text. Anything `AXValue` reported is decoration.
    case confirmedEmpty
    /// `AXValue` is real, user-owned content and must be preserved exactly.
    case confirmedContent
    /// The evidence contradicts itself. Nothing may be overwritten on this basis.
    case ambiguous
}

/// One semantic reading of an editable Accessibility target, taken immediately before an
/// insertion.
///
/// Chromium-hosted web editors (and some native controls) report their *placeholder* through
/// `kAXValueAttribute` while the editor is empty. Treating that string as committed content is
/// what produced the shipped defect: inserting at the reported cursor spliced the dictation
/// into the placeholder, so the placeholder became literal submitted text — appended when the
/// reported cursor sat at offset 0, prefixed when it sat at the end of the placeholder. That is
/// the whole explanation for the direction varying between hosts; it was never a spacing bug.
///
/// This type separates the *raw* reading from the *semantic* one so the rest of the output path
/// only ever operates on committed content. Nothing here inspects the text itself — no phrase
/// list, no host or domain matching. A string is discarded only when a second Accessibility
/// attribute independently corroborates that the editor is empty.
public struct AccessibilityEditableTextSnapshot: Equatable {
    /// Not exported by the SDK as a constant, unlike the `kAX…` attributes.
    public static let placeholderAttribute = "AXPlaceholderValue"

    public let rawValue: String?
    public let placeholderValue: String?
    /// `AXNumberOfCharacters`. The authoritative count of *committed* characters, which is why
    /// it can disagree with `rawValue`'s length precisely when `rawValue` is a placeholder.
    public let reportedCharacterCount: Int?
    public let selectedRange: NSRange?
    public let role: String?
    public let subrole: String?

    public init(
        rawValue: String?,
        placeholderValue: String? = nil,
        reportedCharacterCount: Int? = nil,
        selectedRange: NSRange? = nil,
        role: String? = nil,
        subrole: String? = nil
    ) {
        self.rawValue = rawValue
        self.placeholderValue = placeholderValue
        self.reportedCharacterCount = reportedCharacterCount
        self.selectedRange = selectedRange
        self.role = role
        self.subrole = subrole
    }

    /// Accessibility ranges are UTF-16/NSString offsets, so lengths must be too.
    public var rawValueLength: Int { (rawValue as NSString?)?.length ?? 0 }

    /// The host is echoing its own placeholder through `AXValue`. On its own this is a
    /// suspicion, not a verdict — `emptiness` decides what it is worth.
    public var reportsPlaceholderMatchingValue: Bool {
        guard let rawValue, !rawValue.isEmpty, let placeholderValue else { return false }
        return placeholderValue == rawValue
    }

    /// Deliberately ordered so that the *absence* of placeholder evidence short-circuits to
    /// `.confirmedContent`. Native fields (TextEdit and friends) expose no `AXPlaceholderValue`
    /// matching their value, so they take that early exit and behave exactly as before this
    /// type existed — the placeholder handling cannot regress them.
    public var emptiness: AccessibilityTextEmptiness {
        guard let rawValue else { return .ambiguous }
        if rawValue.isEmpty { return .confirmedEmpty }
        // A zero count is the host stating outright that nothing is committed, whatever
        // `AXValue` says. This is the strongest signal available and needs no corroboration.
        if reportedCharacterCount == 0 { return .confirmedEmpty }

        guard reportsPlaceholderMatchingValue else { return .confirmedContent }

        if let reportedCharacterCount {
            // The host claims committed characters *and* echoes its placeholder. If the count
            // matches the string, the user genuinely typed text identical to the placeholder
            // and it must survive. Any other count is self-contradictory evidence.
            return reportedCharacterCount == rawValueLength ? .confirmedContent : .ambiguous
        }

        // No count attribute: the placeholder match is the only corroboration available, and
        // it is the one the affected hosts do provide.
        return .confirmedEmpty
    }

    /// What the field logically contains. `""` where a placeholder was discarded, so callers
    /// splice into empty text rather than into decoration. `nil` when the state is ambiguous,
    /// which is the signal to stop rather than guess.
    public var committedValue: String? {
        switch emptiness {
        case .confirmedEmpty: return ""
        case .confirmedContent: return rawValue
        case .ambiguous: return nil
        }
    }

    /// The insertion range expressed against `committedValue`. A semantically empty editor is
    /// always `{0, 0}` regardless of where the host claimed the cursor was — that reported
    /// offset was an index into the placeholder and is meaningless once it is discarded.
    public var logicalRange: NSRange? {
        switch emptiness {
        case .confirmedEmpty:
            return NSRange(location: 0, length: 0)
        case .confirmedContent:
            guard let rawValue, let selectedRange,
                  isValidAccessibilityRange(selectedRange, in: rawValue) else { return nil }
            return selectedRange
        case .ambiguous:
            return nil
        }
    }

    /// True when a placeholder was identified and dropped. Used only for diagnostics.
    public var isPlaceholderNormalized: Bool {
        emptiness == .confirmedEmpty && reportsPlaceholderMatchingValue
    }

    /// Safe to perform a confirmed, reversible mutation against.
    public var isSafeForConfirmedMutation: Bool {
        committedValue != nil && logicalRange != nil
    }

    /// Shapes and lengths only — never the value, the placeholder, or any dictated text.
    public var diagnosticSummary: String {
        let range = selectedRange.map { "{\($0.location),\($0.length)}" } ?? "nil"
        return """
        role=\(role ?? "nil") subrole=\(subrole ?? "nil") rawLen=\(rawValueLength) \
        placeholderLen=\(placeholderValue.map { ($0 as NSString).length }.map(String.init) ?? "nil") \
        placeholderMatchesValue=\(reportsPlaceholderMatchingValue) \
        reportedCount=\(reportedCharacterCount.map(String.init) ?? "nil") \
        selection=\(range) emptiness=\(emptiness.rawValue) normalizedPlaceholder=\(isPlaceholderNormalized)
        """
    }
}
