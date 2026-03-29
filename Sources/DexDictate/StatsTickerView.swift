import SwiftUI
import DexDictateKit

struct StatsTickerView: View {
    @ObservedObject var history: TranscriptionHistory
    let animateWhenNeeded: Bool

    private var statsText: String {
        let items = history.items
        guard !items.isEmpty else { return "No dictation stats yet." }

        let words = items.reduce(0) { $0 + $1.text.split(separator: " ").count }

        guard items.count >= 2 else {
            return "\(words) word\(words == 1 ? "" : "s")"
        }

        let earliest = items.last!.createdAt
        let latest = items.first!.createdAt
        let minutes = latest.timeIntervalSince(earliest) / 60
        let minInt = max(1, Int(minutes))
        let wpm = minutes > 0 ? Int(Double(words) / minutes) : words

        return "\(words) words · \(minInt) min · ~\(wpm) wpm"
    }

    var body: some View {
        FlavorTickerView(
            text: statsText,
            animateWhenNeeded: animateWhenNeeded,
            labelLine1: "DEX",
            labelLine2: "STAT",
            labelGradientColors: [
                Color(red: 0.10, green: 0.55, blue: 0.30),
                Color(red: 0.05, green: 0.32, blue: 0.18)
            ]
        )
    }
}
