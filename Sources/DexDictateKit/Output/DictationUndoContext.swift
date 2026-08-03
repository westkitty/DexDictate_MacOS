import ApplicationServices
import Foundation

/// How a reversible delivery should be put back.
///
/// A direct Accessibility write always knows the exact committed text it replaced. A verified
/// clipboard paste into a web composer often does not: the host reported presentation-only
/// placeholder text through `kAXValueAttribute` beforehand, so there is no committed previous
/// string to restore — the correct restoration is emptiness, and the host then paints its own
/// placeholder again.
public enum DictationUndoRestoration: Equatable, Sendable {
    /// `previousFieldValue` is real committed content and is written back verbatim.
    case knownPreviousValue
    /// The editor held no committed text before the delivery. Restore `""` — never the
    /// presentation string, which was never editable content in the first place.
    ///
    /// `presentationValue` is the raw pre-delivery `kAXValueAttribute` reading, retained
    /// *only* so restoration can be verified: a host that paints its placeholder back into
    /// `AXValue` reports exactly this string again, and for this mode alone that reading is
    /// accepted as proof the editor is empty.
    case logicallyEmptyEditor(presentationValue: String?)
}

public struct DictationUndoContext: Equatable {
    /// The exact text this delivery actually inserted (after auto-spacing).
    public let insertedText: String
    /// Full field value immediately before insertion, when readable via Accessibility.
    /// `nil` when the field didn't expose a readable `kAXValueAttribute` at delivery time.
    public let previousFieldValue: String?
    /// Range inside `previousFieldValue` that `insertedText` replaced (usually zero-length,
    /// at the cursor; non-zero when replacing a selection or an entire field).
    public let replacementRange: NSRange?
    public let targetApplication: OutputTargetApplication?
    let targetElement: AccessibilityElementReference?
    /// How to put this delivery back. Defaults to the direct-Accessibility behaviour so every
    /// existing call site keeps its exact semantics.
    public let restoration: DictationUndoRestoration
    /// The value the field held immediately after a *verified* delivery. Undo refuses to touch
    /// anything unless the field still reads exactly this, which is what protects text the user
    /// edited after the insertion. `nil` for contexts built before the write was observed.
    public let verifiedPostDeliveryValue: String?

    public init(
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication?,
        restoration: DictationUndoRestoration = .knownPreviousValue,
        verifiedPostDeliveryValue: String? = nil
    ) {
        self.insertedText = insertedText
        self.previousFieldValue = previousFieldValue
        self.replacementRange = replacementRange
        self.targetApplication = targetApplication
        self.targetElement = nil
        self.restoration = restoration
        self.verifiedPostDeliveryValue = verifiedPostDeliveryValue
    }

    init(
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication?,
        targetElement: AXUIElement,
        restoration: DictationUndoRestoration = .knownPreviousValue,
        verifiedPostDeliveryValue: String? = nil
    ) {
        self.insertedText = insertedText
        self.previousFieldValue = previousFieldValue
        self.replacementRange = replacementRange
        self.targetApplication = targetApplication
        self.targetElement = AccessibilityElementReference(targetElement)
        self.restoration = restoration
        self.verifiedPostDeliveryValue = verifiedPostDeliveryValue
    }
}
