import SwiftUI
import AppKit
import AVFoundation
import DexDictateKit

@MainActor
final class LaunchIntroController {
    static let shared = LaunchIntroController()

    private var hasPlayedThisSession = false
    private var panel: LaunchIntroPanel?
    private var player: AVPlayer?

    private init() {}

    func playIfNeeded() {
        guard !hasPlayedThisSession else { return }
        hasPlayedThisSession = true

        guard
            let url = Safety.resourceBundle.url(
                forResource: "IntroAnimation",
                withExtension: "mp4"
            ),
            let screen = NSScreen.main ?? NSScreen.screens.first
        else {
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.volume = 0
        player.actionAtItemEnd = .pause
        self.player = player

        let startFrame = initialFrame(on: screen)
        let panel = LaunchIntroPanel(
            contentRect: startFrame,
            rootView: AnyView(LaunchIntroView(player: player))
        )
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        player.play()

        let duration = 6.0
        let exitDelay = max(0.9, duration - 1.1)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) { [weak self] in
            self?.animateExit(on: screen, duration: min(1.0, max(0.75, duration * 0.18)))
        }
    }

    private func initialFrame(on screen: NSScreen) -> NSRect {
        let size: CGFloat = 220
        let frame = screen.visibleFrame
        return NSRect(
            x: frame.midX - (size / 2),
            y: frame.midY - (size / 2) + 24,
            width: size,
            height: size
        )
    }

    private func animateExit(on screen: NSScreen, duration: Double) {
        guard let panel else { return }

        let finalSize: CGFloat = 68
        let visibleFrame = screen.visibleFrame
        let finalFrame = NSRect(
            x: visibleFrame.midX - (finalSize / 2),
            y: visibleFrame.maxY - finalSize - 4,
            width: finalSize,
            height: finalSize
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.player?.pause()
                self?.panel?.orderOut(nil)
                self?.panel = nil
                self?.player = nil
            }
        }
    }
}

private final class LaunchIntroPanel: NSPanel {
    init(contentRect: NSRect, rootView: AnyView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true

        contentView = NSHostingView(rootView: rootView)
    }
}

private struct LaunchIntroView: View {
    let player: AVPlayer

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            IntroPlayerRepresentable(player: player)
                .clipShape(Circle())
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

private struct IntroPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> IntroPlayerView {
        let view = IntroPlayerView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: IntroPlayerView, context: Context) {
        nsView.player = player
    }
}

private final class IntroPlayerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    var player: AVPlayer? {
        get { playerLayer?.player }
        set {
            playerLayer?.player = newValue
            playerLayer?.videoGravity = .resizeAspectFill
            playerLayer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }
}
