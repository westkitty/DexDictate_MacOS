import SwiftUI
import DexDictateKit

/// Expandable transcription history feed shown at the top of the main popover.
///
/// When history is empty the `statusText` placeholder is shown instead. Each row has a
/// copy-to-clipboard button. The list height toggles between 100 pt (collapsed) and
/// 300 pt (expanded) with animation.
struct HistoryView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var history: TranscriptionHistory
    @State private var isHovered = false
    /// Shown as a placeholder when `history` is empty.
    let statusText: String
    /// Partial transcription while dictating.
    let liveTranscript: String
    /// Normalized mic input level (0.0-1.0).
    let inputLevel: Double
    /// Indicates the engine is actively capturing or finishing audio.
    let isListening: Bool
    /// Controls whether the list is in its expanded (300 pt) or collapsed (100 pt) state.
    @Binding var expanded: Bool
    
    /// Action to perform when the detach button is clicked.
    var onDetach: (() -> Void)? = nil

    /// Whether the SilverTongue extension is enabled in settings.
    var silverTongueEnabled: Bool = false

    /// Whether the SilverTongue local service is ready for synthesis.
    var silverTongueReady: Bool = false

    /// Action for speaking a specific history item via SilverTongue.
    var onReadBack: ((String) -> Void)? = nil

    /// Seconds remaining until silence auto-stop; `nil` when inactive.
    var silenceCountdown: Double? = nil

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                if isListening {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Mic Active")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                ChromeIconButton(
                    systemName: "arrow.up.left.and.arrow.down.right",
                    accessibilityText: "Open detached history window"
                ) {
                    onDetach?()
                }
                .help("Detach History")
                
                ChromeIconButton(
                    systemName: expanded ? "chevron.up" : "chevron.down",
                    accessibilityText: expanded ? "Collapse history" : "Expand history"
                ) {
                    withAnimation { expanded.toggle() }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if isListening {
                        HStack(spacing: 8) {
                            Text(liveTranscript.isEmpty ? "Listening..." : "Live")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                            ProgressView(value: min(max(inputLevel, 0), 1))
                                .progressViewStyle(.linear)
                                .tint(.green)
                        }
                        if let countdown = silenceCountdown, countdown > 0 {
                            Text("Auto-stopping in \(Int(ceil(countdown)))s...")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                        if !liveTranscript.isEmpty {
                            Text(liveTranscript)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    if history.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.55))
                            Text("No transcription history yet")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
                    } else {
                        ForEach(history.items) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.45))

                                    Text(item.text)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)

                                    if item.isAccuracyRetry {
                                        Text("Accuracy retry")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.cyan)
                                    }
                                }
                                Spacer()
                                VStack(spacing: 6) {
                                    ChromeIconButton(
                                        systemName: "doc.on.doc",
                                        accessibilityText: "Copy history item"
                                    ) {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.text, forType: .string)
                                    }

                                    if silverTongueEnabled && silverTongueReady {
                                        ChromeIconButton(
                                            systemName: "speaker.wave.2.fill",
                                            accessibilityText: "Speak out loud"
                                        ) {
                                            onReadBack?(item.text)
                                        }
                                    }
                                }
                            }
                            .padding(6)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: expanded ? 300 : 100)
            .padding(8)
            .background(
                reduceTransparency
                ? AnyShapeStyle(Color.black.opacity(0.82))
                : isHovered
                    ? AnyShapeStyle(.regularMaterial)
                    : AnyShapeStyle(Color.white.opacity(0.06))
            )
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(historyAccentColor.opacity(isHovered ? 0.42 : 0.18), lineWidth: 1)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .onHover { isHovered = $0 }
        }
        .padding(.horizontal)
    }

    private var historyAccentColor: Color {
        if isListening { return .red }
        return history.isEmpty ? .white : .green
    }
}
