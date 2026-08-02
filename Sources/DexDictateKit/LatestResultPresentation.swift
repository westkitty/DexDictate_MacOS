import Foundation

/// The presentation contract for the shared "Undo Last Dictation" control. Lives in the kit
/// (not in a SwiftUI view) so the visibility rule and its user-facing copy are unit-testable,
/// and so the slim popover and the classic popover cannot drift apart: both render this one
/// model via `UndoLastDictationButton`.
public struct UndoControlModel: Equatable {
    /// Always true once a latest result exists. A control that vanishes when undo happens to
    /// be unavailable is indistinguishable from a feature that was never built — which is
    /// exactly how this shipped and how it was reported. The control now stays put and
    /// explains itself instead.
    public let isVisible = true
    public let isEnabled: Bool
    /// `nil` when enabled.
    public let unavailableReason: DictationUndoUnavailableReason?

    public init(availability: DictationUndoAvailability) {
        isEnabled = availability.canUndo
        unavailableReason = availability.unavailableReason
    }

    public var title: String { "Undo Last Dictation" }

    public var accessibilityLabel: String {
        isEnabled
        ? "Remove the most recently inserted dictation from the active app"
        : "Undo Last Dictation, unavailable"
    }

    /// Enabled: what the action does. Disabled: the actual reason it can't run right now.
    public var helpText: String {
        guard let unavailableReason else {
            return "Removes the last dictation from the target app without touching its clipboard or undo history."
        }
        return unavailableReason.message
    }

    public var accessibilityHint: String { helpText }
}

/// Per-item view state for the latest-result card. A new transcription must start from the
/// default presentation instead of inheriting the previous item's Raw/Cleaned choice or its
/// expanded state; `synchronize(with:)` is what the view calls when the item identity changes.
///
/// Purely a display concern — it never touches stored raw or cleaned text.
public struct LatestResultDisplayState: Equatable {
    public static let defaultVariant: HistoryTextVariant = .cleaned
    public static let defaultIsExpanded = false

    public private(set) var itemID: UUID?
    public private(set) var preferredVariant: HistoryTextVariant
    public private(set) var isExpanded: Bool

    public init(
        itemID: UUID? = nil,
        preferredVariant: HistoryTextVariant = LatestResultDisplayState.defaultVariant,
        isExpanded: Bool = LatestResultDisplayState.defaultIsExpanded
    ) {
        self.itemID = itemID
        self.preferredVariant = preferredVariant
        self.isExpanded = isExpanded
    }

    /// Resets variant and expansion when the displayed item changes identity.
    /// - Returns: `true` when a reset happened, so the caller can also drop stale copy
    ///   feedback belonging to the previous item.
    @discardableResult
    public mutating func synchronize(with newItemID: UUID?) -> Bool {
        guard newItemID != itemID else { return false }
        itemID = newItemID
        preferredVariant = Self.defaultVariant
        isExpanded = Self.defaultIsExpanded
        return true
    }

    public mutating func toggleVariant(displayed: HistoryTextVariant) {
        preferredVariant = displayed == .cleaned ? .raw : .cleaned
        isExpanded = false
    }

    public mutating func toggleExpansion() {
        isExpanded.toggle()
    }
}
