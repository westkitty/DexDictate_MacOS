import SwiftUI
import DexDictateKit

/// Shows the last transcript, the Pasted/Copied badge, and the contextual Retry/Learn
/// Correction buttons — subscribing to the exact same `engine` published state
/// `ControlsView` already reads (`resultFeedback`, `latestHistoryItem`,
/// `canRetryLastUtterance`, `canUndoLastHistoryRemoval`), so nothing about when these
/// appear or what they call changes. Plain background — never renders under a watermark.
struct PopoverResultView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var history: TranscriptionHistory
    @ObservedObject var settings: AppSettings
    /// Only needed for the inline Dexter quote (Packet 12A adoption); optional so existing
    /// call sites that don't pass it still compile — the quote just doesn't render.
    var profileManager: ProfileManager?
    var onOpenHistory: (() -> Void)?
    @State private var isCorrectionSheetPresented = false
    @State private var correctionDraft = VocabularyCorrectionDraft()
    @State private var preferredVariant: HistoryTextVariant = .cleaned
    @State private var isExpanded = false
    @State private var copyFeedback: TranscriptCopyResult?
    @State private var copyFeedbackTask: Task<Void, Never>?

    private var latestHistoryItem: HistoryItem? {
        guard let latest = engine.latestHistoryItem else { return nil }
        return history.items.first(where: { $0.id == latest.id }) ?? latest
    }

    private var optionalAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }

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
        if let latest = latestHistoryItem {
            let content = HistoryDisplayContent(item: latest)
            let displayVariant = content.effectiveVariant(preferred: preferredVariant)
            let displayText = content.text(preferred: preferredVariant)
            let canExpand = HistoryPresentation.shouldOfferExpansion(for: displayText)

            VStack(alignment: .leading, spacing: 8) {
                Text(displayText)
                    .font(.caption)
                    .lineLimit(isExpanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if canExpand {
                    Button(isExpanded ? "Show Less" : "Show More") {
                        withAnimation(optionalAnimation) {
                            isExpanded.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityLabel(isExpanded ? "Collapse latest transcription" : "Expand latest transcription")
                    .accessibilityHint(isExpanded ? "Shows fewer lines." : "Shows the complete transcription.")
                }

                if content.hasDistinctCleanedText {
                    HStack(spacing: 6) {
                        Text(displayVariant.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.cyan)
                        Button(displayVariant == .cleaned ? "Show Raw" : "Show Cleaned") {
                            withAnimation(optionalAnimation) {
                                preferredVariant = displayVariant == .cleaned ? .raw : .cleaned
                                isExpanded = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .accessibilityLabel(
                            displayVariant == .cleaned
                            ? "Show raw latest transcription"
                            : "Show cleaned latest transcription"
                        )
                    }
                }

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
                        Button("Retry with Higher Quality") { retryLastUtterance() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Retry the last utterance with higher quality")
                    }
                }

                HStack(spacing: 6) {
                    Button("Copy") { copy(displayText) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Copy latest transcription")
                        .accessibilityHint("Copies the displayed \(displayVariant.label.lowercased()) text.")

                    if settings.enableCorrectionSheet {
                        Button("Learn Correction") { openCorrectionSheet() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Create a correction from the latest transcription")
                    }

                    Button("Open History") { onOpenHistory?() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Open full transcription history")
                }

                Text(copyFeedback?.feedbackText ?? "Copy failed")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(copyFeedback == .failed ? .orange : .green)
                    .frame(height: 14, alignment: .leading)
                    .opacity(copyFeedback == nil ? 0 : 1)
                    .accessibilityHidden(true)

                if settings.showInlineResultQuote, let profileManager,
                   let quoteText = profileManager.currentFlavorLine?.text, !quoteText.isEmpty {
                    DexterCommentaryLine(text: quoteText)
                }
            }
            .padding(SurfaceTokens.cardPadding)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            .padding(.horizontal)
            .sheet(isPresented: $isCorrectionSheetPresented) {
                VocabularyCorrectionSheet(draft: $correctionDraft, onSave: saveCorrection)
            }
            .onDisappear {
                copyFeedbackTask?.cancel()
            }
        }
    }

    private func copy(_ text: String) {
        let result = TranscriptCopyAction.copy(text)
        copyFeedbackTask?.cancel()
        withAnimation(optionalAnimation) {
            copyFeedback = result
        }
        TranscriptCopyAction.announce(result)
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(optionalAnimation) {
                copyFeedback = nil
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
