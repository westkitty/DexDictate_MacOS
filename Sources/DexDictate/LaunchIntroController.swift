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
    private var endObserver: Any?

    private static let animationNames: [String] = (1...8).map { String(format: "LaunchAnimation_%02d", $0) }

    private init() {}

    func playIfNeeded() {
        guard !hasPlayedThisSession else { return }
        hasPlayedThisSession = true

        let name = Self.animationNames.randomElement() ?? "LaunchAnimation_01"
        guard
            let url = Safety.resourceBundle.url(forResource: name, withExtension: "mp4"),
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
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        player.rate = 1.5

        // Hold on the final frame (brand card) for 1.5 s, then exit.
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let exitScreen = NSScreen.main ?? NSScreen.screens.first
                guard let exitScreen else { return }
                self.animateExit(on: exitScreen, duration: 0.7)
            }
        }

        // Safety fallback: exit after 10 s regardless (longest video at 1.5x is ~6.7 s).
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self, self.panel != nil else { return }
            let fallbackScreen = NSScreen.main ?? NSScreen.screens.first
            guard let fallbackScreen else { return }
            self.animateExit(on: fallbackScreen, duration: 0.7)
        }
    }

    // 16:9 panel, comfortably sized — not full-screen, centered
    private func initialFrame(on screen: NSScreen) -> NSRect {
        let width: CGFloat = 400
        let height: CGFloat = 225   // exactly 16:9
        let frame = screen.visibleFrame
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2 + 20,
            width: width,
            height: height
        )
    }

    private func animateExit(on screen: NSScreen, duration: Double) {
        guard let panel else { return }

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        let finalSize: CGFloat = 64
        let visibleFrame = screen.visibleFrame
        let finalFrame = NSRect(
            x: visibleFrame.midX - finalSize / 2,
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
        hasShadow = true
        ignoresMouseEvents = true

        contentView = NSHostingView(rootView: rootView)
    }
}

private struct LaunchIntroView: View {
    let player: AVPlayer

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            IntroPlayerRepresentable(player: player)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(6)
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
        super.init(coder: coder)
        wantsLayer = true
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
