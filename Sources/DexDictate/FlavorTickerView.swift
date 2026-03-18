import SwiftUI
import DexDictateKit

struct FlavorTickerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let animateWhenNeeded: Bool

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var isAnimating = false

    private let tickerHeight: CGFloat = 28
    private let gapWidth: CGFloat = 32

    private var shouldAnimate: Bool {
        animateWhenNeeded && !reduceMotion && textWidth > containerWidth && !text.isEmpty
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            GeometryReader { proxy in
                tickerContent
                    .frame(width: proxy.size.width, height: tickerHeight, alignment: .leading)
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
            .frame(height: tickerHeight)
        }
        .frame(height: tickerHeight)
        .mask(fadeMask)
        .onChange(of: text) { _, _ in
            resetAnimationState()
        }
        .onChange(of: shouldAnimate) { _, _ in
            resetAnimationState()
        }
        .padding(.horizontal)
        .accessibilityLabel(text.isEmpty ? "Flavor ticker" : text)
    }

    @ViewBuilder
    private var tickerContent: some View {
        if shouldAnimate {
            marqueeTicker
        } else {
            measuredTickerText
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
        }
    }

    private var marqueeTicker: some View {
        HStack(spacing: gapWidth) {
            measuredTickerText
            measuredTickerText
        }
        .offset(x: isAnimating ? -(textWidth + gapWidth) : 0)
        .onAppear {
            startAnimationIfNeeded()
        }
    }

    private var measuredTickerText: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.white.opacity(0.82))
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

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.06),
                .init(color: .white, location: 0.94),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func resetAnimationState() {
        isAnimating = false

        guard shouldAnimate else { return }

        DispatchQueue.main.async {
            startAnimationIfNeeded()
        }
    }

    private func startAnimationIfNeeded() {
        guard shouldAnimate, !isAnimating else { return }

        let duration = max(8, Double(textWidth + gapWidth) / 22)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
}

private struct FlavorTickerWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
