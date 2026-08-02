import SwiftUI
import DexDictateKit

/// The one "Undo Last Dictation" control in the app. Mounted by `PopoverUndoFooter`, which
/// both popover roots place at route level, so the two surfaces cannot diverge.
///
/// Enabled when a reversible record is armed, disabled with the real reason otherwise.
///
/// Visibility, enablement, and copy all come from `UndoControlModel`, built from the single
/// published `engine.undoAvailability` — so the button and its explanation can never
/// contradict the authoritative undo record.
struct UndoLastDictationButton: View {
    @ObservedObject var engine: TranscriptionEngine
    /// Which surface is invoking undo. The popover moves focus to DexDictate, so the button
    /// verifies and mutates the saved element directly instead of requiring it to still hold
    /// global focus — see `DictationUndoManager`.
    var invocation: DictationUndoInvocation = .popoverButton

    var body: some View {
        let model = UndoControlModel(availability: engine.undoAvailability)
        Button(model.title) {
            MainActorAction.run { engine.undoLastDictation(invocation: invocation) }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!model.isEnabled)
        .accessibilityLabel(model.accessibilityLabel)
        .accessibilityHint(model.accessibilityHint)
        .help(model.helpText)
    }
}

/// Route-level chrome carrying the undo control, placed by every popover root immediately
/// above its footer — outside the scroll container, outside every full-content screen swap,
/// and outside every result-feedback, history, retry, correction and delivery-outcome branch.
///
/// This placement is the fix. The control itself was correct and had been correct through
/// several repairs; it was mounted inside the latest-result card, which renders nothing at all
/// when there is no latest history item and which sits far enough down a 320×480 scroll view
/// to be below the fold even when it does render. Both of those read to the user as "the
/// feature does not exist". Nothing above may reintroduce a condition here: the row is
/// unconditional, and only the button's `disabled` state varies.
struct PopoverUndoFooter: View {
    @ObservedObject var engine: TranscriptionEngine

    var body: some View {
        HStack {
            UndoLastDictationButton(engine: engine)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
