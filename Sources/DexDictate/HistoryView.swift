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

    /// Seconds remaining until silence auto-stop; `nil` when inactive.
    var silenceCountdown: Double? = nil

    var body: some View {
        VStack(spacing: 5) {
            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Text("Transcription History")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                if isListening {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(SemanticColors.listening)
                            .frame(width: 6, height: 6)
                        Text("Mic Active")
                            .font(.caption2)
                            .foregroundStyle(SemanticColors.listening.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SemanticColors.listening.opacity(0.12))
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

            // ── Scrollable content ───────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {

                    // Live capture section
                    if isListening {
                        VStack(alignment: .leading, spacing: 6) {
                            // Waveform visualizer replaces the flat progress bar
                            AudioWaveformView(inputLevel: inputLevel, isActive: isListening)

                            if let countdown = silenceCountdown, countdown > 0 {
                                Text("Auto-stopping in \(Int(ceil(countdown)))s...")
                                    .font(.caption2)
                                    .foregroundStyle(SemanticColors.error.opacity(0.9))
                            }
                            if !liveTranscript.isEmpty {
                                Text(liveTranscript)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(6)
                                    .background(SemanticColors.ready.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    // Empty state
                    if history.isEmpty {
                        EmptyHistoryView(statusText: statusText)
                    } else {
                        // History items
                        ForEach(history.items) { item in
                            HistoryCardRow(item: item)
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
                    : AnyShapeStyle(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(historyAccentColor.opacity(0.42), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private var historyAccentColor: Color {
        if isListening { return SemanticColors.listening }
        return history.isEmpty ? .white : SemanticColors.ready
    }
}

// MARK: - Waveform Visualizer (#1)

/// Animated multi-bar waveform that mirrors speech energy in real time.
///
/// Bar heights are driven by `inputLevel` (overall amplitude) combined with
/// per-bar sine-wave offsets so the bars move independently and naturally.
private struct AudioWaveformView: View {
    let inputLevel: Double
    let isActive: Bool

    // 18 bars; heights updated by the timer
    @State private var barHeights: [CGFloat] = Array(repeating: 3, count: 18)
    @State private var phase: Double = 0

    // A lightweight timer that drives the animation
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                // Pulsing dot
                Circle()
                    .fill(SemanticColors.listening)
                    .frame(width: 7, height: 7)
                    .shadow(color: SemanticColors.listening.opacity(0.7), radius: 4)
                    .opacity(isActive ? 1 : 0.4)
                Text("LISTENING")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }

            // The waveform bars
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barHeights.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    SemanticColors.listening.opacity(0.9),
                                    SemanticColors.listening.opacity(0.4)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3, height: barHeights[i])
                }
            }
            .frame(height: 32, alignment: .center)
            .animation(.linear(duration: 0.05), value: barHeights)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            guard isActive else {
                barHeights = Array(repeating: 3, count: barHeights.count)
                return
            }
            phase += 0.18
            let amp = max(0.05, inputLevel)
            barHeights = barHeights.enumerated().map { i, _ in
                let sine = sin(phase + Double(i) * 0.6) * 0.5 + 0.5
                return CGFloat(max(3, (sine + Double.random(in: 0...0.3)) * amp * 30))
            }
        }
    }
}

// MARK: - History Item Row (#3)

/// A single history item card with a cyan left-accent stripe and inline copy action.
private struct HistoryCardRow: View {
    let item: HistoryItem
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left accent stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(SemanticColors.accent.opacity(0.5))
                .frame(width: 2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                // Metadata row
                HStack(spacing: 6) {
                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))

                    // Word count badge (computed from text)
                    let wordCount = item.text.split(separator: " ").count
                    if wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(SemanticColors.accent.opacity(0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SemanticColors.accent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(SemanticColors.accent.opacity(0.18), lineWidth: 1)
                            )
                    }

                    if item.isAccuracyRetry {
                        Text("Accuracy retry")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SemanticColors.accent)
                    }

                    Spacer()

                    // Copy button with confirmation
                    Button(action: copyItem) {
                        Text(copied ? "✓" : "copy")
                            .font(.caption2)
                            .foregroundStyle(copied ? SemanticColors.ready : .white.opacity(0.3))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(copied ? SemanticColors.ready.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy history item")
                }

                Text(item.text)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.leading, 8)
            .padding(.vertical, 6)
            .padding(.trailing, 6)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
    }

    private func copyItem() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - Empty State (#5)

/// Guides new users to their first transcription with an icon, headline, and shortcut hint.
private struct EmptyHistoryView: View {
    let statusText: String

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // Dashed mic icon container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "mic")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.28))
            }

            VStack(spacing: 4) {
                Text("Nothing transcribed yet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Shortcut hint badge
            HStack(spacing: 5) {
                Text("Press")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.28))
                Text(AppSettings.shared.userShortcut.displayString)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .foregroundStyle(.white.opacity(0.55))
                Text("to start dictating")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}
