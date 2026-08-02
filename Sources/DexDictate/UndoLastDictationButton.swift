import SwiftUI
import DexDictateKit

/// The one "Undo Last Dictation" control in the app. Rendered by both the active slim
/// popover (`PopoverResultView`) and the classic popover (`ControlsView`) so the two
/// surfaces cannot diverge — this used to exist only as a private view inside
/// `ControlsView`, which made it unreachable whenever `settings.useSlimPopover` was on
/// (the default), i.e. for every normal user.
///
/// Visibility and copy come from `UndoControlModel` in DexDictateKit, driven by
/// `engine.canUndoLastDictation` — a stored `@Published` property, so arming and clearing
/// undo actually publish a SwiftUI update rather than depending on some other property
/// changing in the same turn of the run loop.
struct UndoLastDictationButton: View {
    @ObservedObject var engine: TranscriptionEngine

    var body: some View {
        let model = UndoControlModel(canUndoLastDictation: engine.canUndoLastDictation)
        if model.isVisible {
            Button(model.title) {
                MainActorAction.run { engine.undoLastDictation() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(model.accessibilityLabel)
            .help(model.helpText)
        }
    }
}
