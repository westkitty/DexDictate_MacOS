import SwiftUI
import DexDictateKit

/// Dexter stateful feed — local quote-pack driven, no network.
///
/// Adopted into Settings → Dexter & Personality (Packet 12A-B) as an unconditional
/// feature — the `useExperimentalDexterFeed` flag's only reader lived in the now-retired
/// `DexLayeredRevealView.swift` (Packet 12B). Sources lines from the existing
/// `FlavorQuotePacks` infrastructure; no RSS or remote fetching is performed. If the repo
/// gains verified network support later, this view can be extended without changing the
/// production dictation path.
///
/// Dexter copy guidelines (from 01_FINAL_UIUX_DECISION_REPORT):
/// - Event-driven: one short line after success, error, or idle.
/// - Never interrupts dictation.
/// - Never makes Dexter the sole indicator of state.
/// - Mutable at any time via showFlavorTicker setting.
struct DexDexterFeedView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager

    @State private var displayedLines: [DexFeedLine] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if displayedLines.isEmpty {
                placeholderRow
            } else {
                ForEach(displayedLines) { line in
                    DexFeedLineRow(line: line)
                }
            }

            Button(action: loadLines) {
                Label("Shuffle lines", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.cyan.opacity(0.80))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("Load new Dexter commentary lines")
        }
        .onAppear { loadLines() }
    }

    // MARK: - Sub-views

    private var placeholderRow: some View {
        Text("Loading Dexter's thoughts…")
            .font(.caption2.italic())
            .foregroundStyle(.white.opacity(0.35))
    }

    // MARK: - Load

    private func loadLines() {
        let active = profileManager.activeProfile
        let activeLines = FlavorQuotePacks.pack(for: active)
            .map { (text: $0.text, pack: active.rawValue) }
        let otherLines = AppProfile.allCases
            .filter { $0 != active }
            .flatMap { p in FlavorQuotePacks.pack(for: p).map { (text: $0.text, pack: p.rawValue) } }

        // 3 from active profile, 2 from others; shuffle each pool independently
        let activePick = Array(activeLines.shuffled().prefix(3))
        let otherPick  = Array(otherLines.shuffled().prefix(max(0, 5 - activePick.count)))
        let combined   = (activePick + otherPick).shuffled()

        guard !combined.isEmpty else { return }
        displayedLines = combined.map { DexFeedLine(id: UUID(), text: $0.text, packName: $0.pack) }
    }
}

// MARK: - Feed Line Model

struct DexFeedLine: Identifiable {
    let id: UUID
    let text: String
    let packName: String
}

// MARK: - Feed Line Row

private struct DexFeedLineRow: View {
    let line: DexFeedLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\u{201C}\(line.text)\u{201D}")
                .font(.caption.italic())
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Text(line.packName)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dexter: \(line.text)")
    }
}
