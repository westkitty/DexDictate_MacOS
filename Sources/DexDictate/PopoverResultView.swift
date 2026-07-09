import SwiftUI
import DexDictateKit

/// Shows the last transcript, the Pasted/Copied badge, and the contextual Retry/Learn
/// Correction buttons — subscribing to the exact same `engine` published state
/// `ControlsView` already reads (`resultFeedback`, `latestHistoryItem`,
/// `canRetryLastUtterance`, `canUndoLastHistoryRemoval`), so nothing about when these
/// appear or what they call changes. Plain background — never renders under a watermark.
struct PopoverResultView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @State private var isCorrectionSheetPresented = false
    @State private var correctionDraft = VocabularyCorrectionDraft()

    private var feedbackBackgroundColor: Color {
        switch engine.resultFeedback.tone {
        case .neutral: return Color.white.opacity(0.12)
        case .success: return Color.green.opacity(0.18)
        case .warning: return Color.orange.opacity(0.18)
        }
    }

    private var feedbackForegroundColor: Color {
        switch engine.resultFeedback.tone {
        case .neutral: return .secondary
        case .success: return .green
        case .warning: return .orange
        }
    }

    var body: some View {
        if let latest = engine.latestHistoryItem {
            VStack(alignment: .leading, spacing: 8) {
                Text(latest.text)
                    .font(.caption)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if engine.resultFeedback != .idle {
                    HStack(spacing: 6) {
                        Image(systemName: engine.resultFeedback.symbolName)
                            .font(.caption)
                        Text(engine.resultFeedback.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(feedbackBackgroundColor)
                    .foregroundStyle(feedbackForegroundColor)
                    .clipShape(Capsule())
                    .help(engine.resultFeedback.detail)
                }

                HStack(spacing: 8) {
                    if engine.resultFeedback == .deletedPreviousHistory && engine.canUndoLastHistoryRemoval {
                        Button("Undo removal") { undoLastHistoryRemoval() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    if engine.canRetryLastUtterance {
                        Button("Retry Last in Accuracy Mode") { retryLastUtterance() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Retry the last utterance in accuracy mode")
                    }

                    if settings.enableCorrectionSheet {
                        Button("Learn Correction") { openCorrectionSheet() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Create a custom vocabulary correction")
                    }
                }
            }
            .padding(SurfaceTokens.cardPadding)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            .padding(.horizontal)
            .sheet(isPresented: $isCorrectionSheetPresented) {
                VocabularyCorrectionSheet(draft: $correctionDraft, onSave: saveCorrection)
            }
        }
    }

    private func undoLastHistoryRemoval() {
        MainActorAction.run { engine.undoLastHistoryRemoval() }
    }

    private func retryLastUtterance() {
        MainActorAction.run { engine.retryLastUtteranceInAccuracyMode() }
    }

    private func openCorrectionSheet() {
        MainActorAction.run {
            correctionDraft = VocabularyCorrectionDraft(
                incorrectPhrase: engine.latestHistoryItem?.text ?? "",
                correctPhrase: ""
            )
            isCorrectionSheetPresented = true
        }
    }

    private func saveCorrection() {
        MainActorAction.run {
            let incorrect = correctionDraft.incorrectPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            let corrected = correctionDraft.correctPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !incorrect.isEmpty, !corrected.isEmpty else { return }
            try? engine.vocabularyManager.add(original: incorrect, replacement: corrected)
            isCorrectionSheetPresented = false
        }
    }
}
