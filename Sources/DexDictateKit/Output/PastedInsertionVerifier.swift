import ApplicationServices
import Foundation

/// Everything captured about a clipboard-paste target *before* Cmd-V is dispatched, so the
/// result can be checked against it afterwards. Held in memory only for the lifetime of one
/// verification and never persisted.
struct PastePreDispatchRecord {
    let element: AXUIElement
    let targetApplication: OutputTargetApplication?
    let role: String?
    let subrole: String?
    /// Raw `kAXValueAttribute` before the paste. For a web composer this may be
    /// presentation-only placeholder text rather than committed content.
    let rawValue: String?
    /// What the snapshot could actually vouch for: `""` when provably empty, the raw value
    /// when provably real content, `nil` when the evidence was contradictory.
    let committedValue: String?
    let emptiness: AccessibilityTextEmptiness
    let selectedRange: NSRange?
    let insertedText: String

    /// Shapes only — never the field, placeholder, or dictated text.
    var diagnosticSummary: String {
        let range = selectedRange.map { "{\($0.location),\($0.length)}" } ?? "nil"
        return "role=\(role ?? "nil") rawLen=\((rawValue as NSString?)?.length ?? -1)"
            + " committedLen=\((committedValue as NSString?)?.length ?? -1)"
            + " emptiness=\(emptiness.rawValue) selection=\(range)"
            + " insertedLen=\((insertedText as NSString).length)"
    }
}

/// What the field looked like once the paste had time to land.
enum PasteVerificationOutcome: Equatable {
    /// The field now holds exactly the expected result of inserting the transcription into
    /// known committed content.
    case verifiedKnownContent(postValue: String, previousValue: String, range: NSRange)
    /// The field now holds exactly the transcription and nothing else, and the editor was
    /// logically empty beforehand — the pre-paste raw reading was presentation only.
    case verifiedLogicallyEmpty(postValue: String, presentationValue: String?)
    /// Nothing changed after every bounded retry: the paste did not land.
    case noChange
    /// The field changed into something that cannot be explained exactly.
    case unexplainedChange
    /// The target went away, or could not be read at all.
    case targetUnavailable

    var isVerified: Bool {
        switch self {
        case .verifiedKnownContent, .verifiedLogicallyEmpty: return true
        case .noChange, .unexplainedChange, .targetUnavailable: return false
        }
    }

    /// Short, privacy-safe label for logging.
    var diagnosticLabel: String {
        switch self {
        case .verifiedKnownContent: return "verifiedKnownContent"
        case .verifiedLogicallyEmpty: return "verifiedLogicallyEmpty"
        case .noChange: return "noChange"
        case .unexplainedChange: return "unexplainedChange"
        case .targetUnavailable: return "targetUnavailable"
        }
    }
}

/// Decides whether a dispatched clipboard paste actually produced the expected text, by
/// re-reading **the saved element** — never whatever happens to be focused later.
///
/// This exists because a posted Cmd-V is not evidence of anything. Treating every dispatch as
/// reversible would risk deleting text the paste never inserted; treating none of them as
/// reversible is what left undo permanently disabled in browsers, where the clipboard path is
/// the only one that works. Verification replaces the guess with an exact observation.
struct PastedInsertionVerifier {
    private let axOperator: AccessibilityElementOperating

    init(axOperator: AccessibilityElementOperating) {
        self.axOperator = axOperator
    }

    /// One evaluation against the current state of the saved element.
    func evaluate(_ record: PastePreDispatchRecord) -> PasteVerificationOutcome {
        guard axOperator.isElementAlive(record.element) else { return .targetUnavailable }
        let snapshot = axOperator.editableTextSnapshot(element: record.element)
        guard let postRaw = snapshot.rawValue else { return .targetUnavailable }

        // Unchanged: the paste has not landed (yet, or at all).
        if let preRaw = record.rawValue, postRaw == preRaw {
            return .noChange
        }

        // Case 1 — the pre-paste state was trustworthy, so the exact expected result is known.
        //
        // Restricted to insertions that are *interior* to the old value, or that replaced a
        // non-empty selection. A zero-length insertion at offset 0 or at the very end produces
        // `inserted + old` / `old + inserted` — byte-identical to the shape a surviving
        // placeholder produces. Those two cannot be told apart, and verifying the wrong one
        // would let undo write presentation text back as committed content. Boundary pastes
        // therefore stay unverified: no undo, rather than an undo that could corrupt the field.
        if let previous = record.committedValue,
           record.emptiness == .confirmedContent,
           let range = record.selectedRange,
           isUnambiguousInsertionPoint(range, in: previous),
           let expected = accessibilityReplacingText(in: previous, range: range, with: record.insertedText),
           postRaw == expected {
            return .verifiedKnownContent(postValue: postRaw, previousValue: previous, range: range)
        }

        // Case 2 — the editor turns out to have been logically empty. The pre-paste reading
        // looked like content (that is exactly the ambiguity that cannot be resolved *before*
        // a paste), but the field now holds the transcription and nothing else. Every one of
        // these must hold: a zero-length pre-paste selection, a post value that is exactly the
        // transcription with no surviving prefix or suffix, and a post value that differs from
        // the pre-paste presentation string. That combination cannot be produced by inserting
        // into real content — real content would still be present around the insertion.
        if postRaw == record.insertedText,
           record.selectedRange?.length == 0,
           postRaw != record.rawValue {
            return .verifiedLogicallyEmpty(postValue: postRaw, presentationValue: record.rawValue)
        }

        return .unexplainedChange
    }

    /// True when the result of this insertion could not also have been produced by a
    /// presentation-only string surviving alongside the pasted text.
    private func isUnambiguousInsertionPoint(_ range: NSRange, in value: String) -> Bool {
        if range.length > 0 { return true }
        return range.location > 0 && range.location < (value as NSString).length
    }

    /// Bounded polling: browsers apply a paste asynchronously, so a single immediate read would
    /// almost always report `.noChange`. Gives up after `attempts` and never blocks a caller.
    ///
    /// `schedule` is injected so tests drive this deterministically instead of sleeping.
    func verify(
        _ record: PastePreDispatchRecord,
        attempts: Int = 8,
        interval: TimeInterval = 0.12,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void,
        isStillCurrent: @escaping () -> Bool,
        completion: @escaping (PasteVerificationOutcome) -> Void
    ) {
        func attempt(_ remaining: Int) {
            // A newer dictation supersedes this verification outright — arming undo for a
            // delivery that has already been replaced is how stale records mutate live text.
            guard isStillCurrent() else { return }

            let outcome = evaluate(record)
            switch outcome {
            case .noChange where remaining > 1:
                schedule(interval) { attempt(remaining - 1) }
            case .targetUnavailable where remaining > 1:
                schedule(interval) { attempt(remaining - 1) }
            default:
                completion(outcome)
            }
        }
        attempt(max(1, attempts))
    }
}
