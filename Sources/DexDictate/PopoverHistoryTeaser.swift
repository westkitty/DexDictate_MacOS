import SwiftUI
import DexDictateKit

/// Last 3 history rows + a button to the full history window (Packet 09 slim popover
/// contract). Reads the same `TranscriptionHistory` the classic `HistoryView` and the
/// detached History window read — no new storage, no new history logic.
struct PopoverHistoryTeaser: View {
    @ObservedObject var history: TranscriptionHistory
    var onOpenHistory: (() -> Void)?

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
                ForEach(recentItems) { item in
                    HStack(alignment: .top) {
                        Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.text)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Button("Open History Window…") {
                onOpenHistory?()
            }
            .buttonStyle(.plain)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.cyan)
        }
        .padding(.horizontal)
    }
}
