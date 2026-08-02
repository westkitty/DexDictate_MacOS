import SwiftUI
import DexDictateKit

/// The one "Undo Last Dictation" control in the app. Rendered by both the active slim
/// popover (`PopoverResultView`) and the classic popover (`ControlsView`) so the two
/// surfaces cannot diverge.
///
/// It is **always** rendered once a latest result exists — enabled when a reversible record
/// is armed, disabled with the real reason otherwise. It previously rendered nothing when
/// undo was unavailable, which made "this delivery wasn't reversible" look identical to
/// "this feature doesn't exist"; that is the defect this control now closes.
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
