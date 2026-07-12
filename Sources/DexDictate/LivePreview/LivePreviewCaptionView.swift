import SwiftUI
import DexDictateKit

/// Renders the live preview caption unmistakably provisional (dimmed/italic + "PREVIEW"
/// tag), per the plan of record's visual contract — users must never mistake preview for
/// committed output. Whole-line replacement only (the controller already throttles to
/// ≤4 updates/sec) — no per-token animation, which was the documented Parakeet flicker
/// symptom this is deliberately avoiding.
struct LivePreviewCaptionView: View {
    @ObservedObject var controller: LivePreviewController

    var body: some View {
        if controller.isFinalizing {
            finalizingBadge
        } else if !controller.caption.isEmpty {
            captionRow
        } else if let reason = controller.unavailableReason {
            unavailableRow(reason)
        }
    }

    private func unavailableRow(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "text.badge.xmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(reason)
        }
        .transition(.opacity)
    }

    private var captionRow: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("PREVIEW")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())

            Text(controller.caption)
                .font(.caption.italic())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Live preview, not final: \(controller.caption)")
        }
        .transition(.opacity)
    }

    private var finalizingBadge: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Finalizing…")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .transition(.opacity)
    }
}
