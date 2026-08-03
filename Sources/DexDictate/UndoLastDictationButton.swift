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
        .buttonStyle(UndoControlButtonStyle(isAvailable: model.isEnabled))
        .disabled(!model.isEnabled)
        .accessibilityLabel(model.accessibilityLabel)
        .accessibilityHint(model.accessibilityHint)
        .help(model.helpText)
    }
}

/// Explicit high-contrast styling for the undo control.
///
/// `.bordered` rendered the disabled control as secondary-tinted text on a nearly transparent
/// fill; against the popover's dark translucent background that came out looking like inert
/// footer text, and it was reported as the control simply not being there. macOS still dims
/// disabled content, so the fix is to start from a much stronger base — solid white label on a
/// visible filled capsule — and let the system's dimming land somewhere still clearly legible,
/// rather than starting from a secondary colour that dims into the background.
private struct UndoControlButtonStyle: ButtonStyle {
    let isAvailable: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isAvailable
                    ? Color.accentColor.opacity(configuration.isPressed ? 0.55 : 0.85)
                    : Color.white.opacity(0.22)
                )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(isAvailable ? 0.0 : 0.35), lineWidth: 1)
            )
            .contentShape(Capsule())
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
        let model = UndoControlModel(availability: engine.undoAvailability)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                UndoLastDictationButton(engine: engine)
                Spacer(minLength: 0)
            }

            // Deliberately a *sibling* of the button rather than part of it: `.disabled()`
            // dims everything inside the control, and this line has to stay fully legible
            // exactly when the control is disabled — that is the whole point of it.
            Text(model.statusLine)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
