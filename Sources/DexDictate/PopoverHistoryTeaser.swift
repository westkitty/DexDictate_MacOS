import SwiftUI
import DexDictateKit

/// Last 3 history rows in the slim popover. The full History window remains the owner of
/// search, export, destructive controls, context menus, and detailed metadata.
struct PopoverHistoryTeaser: View {
    @ObservedObject var history: TranscriptionHistory

    private var recentItems: [HistoryItem] {
        Array(history.items.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if recentItems.isEmpty {
                Text("No transcription history yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                    PopoverHistoryTeaserRow(
                        item: item,
                        position: index + 1,
                        total: recentItems.count
                    )
                    if item.id != recentItems.last?.id {
                        Divider().opacity(0.12)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct PopoverHistoryTeaserRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: HistoryItem
    let position: Int
    let total: Int

    @State private var preferredVariant: HistoryTextVariant = .cleaned
    @State private var copyFeedback: TranscriptCopyResult?
    @State private var copyFeedbackTask: Task<Void, Never>?

    private var optionalAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }

    var body: some View {
        let content = HistoryDisplayContent(item: item)
        let displayVariant = content.effectiveVariant(preferred: preferredVariant)
        let displayText = content.text(preferred: preferredVariant)
        let relativeTimestamp = HistoryPresentation.relativeTimestamp(for: item.createdAt)
        let exactTimestamp = HistoryPresentation.exactTimestamp(for: item.createdAt)
        let accessibilitySummary = HistoryPresentation.accessibilitySummary(
            item: item,
            displayedText: displayText,
            variant: displayVariant,
            position: position,
            total: total
        )

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(displayText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(accessibilitySummary)

                Button {
                    copy(displayText)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .accessibilityLabel("Copy recent transcription \(position)")
                .accessibilityHint("Copies the displayed \(displayVariant.label.lowercased()) text.")
            }

            HStack(spacing: 6) {
                Text(relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(exactTimestamp)
                    .accessibilityHidden(true)

                if content.hasDistinctCleanedText {
                    Button(displayVariant.label) {
                        withAnimation(optionalAnimation) {
                            preferredVariant = displayVariant == .cleaned ? .raw : .cleaned
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityLabel(
                        displayVariant == .cleaned
                        ? "Show raw text for recent transcription \(position)"
                        : "Show cleaned text for recent transcription \(position)"
                    )
                }

                Spacer(minLength: 0)

                Text(copyFeedback?.feedbackText ?? "Copy failed")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(copyFeedback == .failed ? .orange : .green)
                    .frame(width: 62, height: 14, alignment: .trailing)
                    .opacity(copyFeedback == nil ? 0 : 1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 3)
        .onDisappear {
            copyFeedbackTask?.cancel()
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
}
