import SwiftUI
import DexDictateKit

struct FlavorTickerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let animateWhenNeeded: Bool

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var animationStart = Date()

    private let tickerHeight: CGFloat = 30
    private let gapWidth: CGFloat = 44

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Dex feed idle. Dictate something less chaotic." : trimmed
    }

    private var feedText: String {
        "/// \(displayText) ///"
    }

    private var shouldAnimate: Bool {
        animateWhenNeeded && !reduceMotion && !displayText.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            labelStrip

            GeometryReader { proxy in
                tickerContent
                    .frame(width: proxy.size.width, height: tickerHeight, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.12, blue: 0.16),
                                Color(red: 0.03, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipped()
                    .onAppear {
                        containerWidth = proxy.size.width
                        resetAnimationState()
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        containerWidth = newWidth
                        resetAnimationState()
                    }
            }
        }
        .frame(height: tickerHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .mask(
            RoundedRectangle(cornerRadius: 6)
        )
        .onChange(of: text) { _, _ in
            resetAnimationState()
        }
        .onChange(of: shouldAnimate) { _, _ in
            resetAnimationState()
        }
        .padding(.horizontal)
        .accessibilityLabel(displayText)
    }

    @ViewBuilder
    private var tickerContent: some View {
        if shouldAnimate {
            marqueeTicker
        } else {
            measuredTickerText
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
        }
    }

    private var marqueeTicker: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldAnimate)) { context in
            HStack(spacing: gapWidth) {
                ForEach(0..<repeatCount, id: \.self) { _ in
                    measuredTickerText
                }
            }
            .padding(.horizontal, 12)
            .offset(x: seamlessOffset(for: context.date))
        }
    }

    private var labelStrip: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.83, green: 0.16, blue: 0.14),
                    Color(red: 0.57, green: 0.07, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: -1) {
                Text("DEX")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                Text("FEED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 58, height: tickerHeight)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var measuredTickerText: some View {
        Text(feedText)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .textCase(.uppercase)
            .foregroundStyle(Color(red: 0.82, green: 0.93, blue: 1.0))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: FlavorTickerWidthPreferenceKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(FlavorTickerWidthPreferenceKey.self) { width in
                if abs(textWidth - width) > 0.5 {
                    textWidth = width
                    resetAnimationState()
                }
            }
    }

    private func resetAnimationState() {
        animationStart = Date()
    }

    private func seamlessOffset(for date: Date) -> CGFloat {
        let cycleWidth = max(textWidth + gapWidth, 1)
        let elapsed = CGFloat(date.timeIntervalSince(animationStart))
        let pointsPerSecond: CGFloat = 20
        let travel = (elapsed * pointsPerSecond).truncatingRemainder(dividingBy: cycleWidth)
        return -travel
    }

    private var repeatCount: Int {
        let cycleWidth = max(textWidth + gapWidth, 1)
        let minimumCopies = Int(ceil((containerWidth + cycleWidth * 2) / cycleWidth))
        return max(3, minimumCopies)
    }
}

private struct FlavorTickerWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
