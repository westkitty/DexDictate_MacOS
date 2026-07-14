import SwiftUI
import AppKit
import AVFoundation
import DexDictateKit

@MainActor
final class LaunchIntroController {
    static let shared = LaunchIntroController()

    /// Named delays for the intro's playback-hold / exit-fade / safety-net timers — grouped
    /// here purely for self-documentation of the magic numbers below.
    private struct Timing {
        var holdAfterPlaybackSeconds: Double
        var fadeOutDurationSeconds: Double
        var fallbackDeadlineSeconds: Double
        var hardDeadlineSeconds: Double

        static let production = Timing(
            holdAfterPlaybackSeconds: 1.5,
            fadeOutDurationSeconds: 0.7,
            // Safety fallback: exit regardless (longest video at 1.5x is ~6.7 s).
            fallbackDeadlineSeconds: 10.0,
            // Hard guarantee, independent of the fade animation: if its own completion
            // handler never fires (e.g. Core Animation servicing for this backgrounded
            // LSUIElement process stalls behind a fullscreen app), the panel must still
            // disappear rather than get stuck on screen indefinitely.
            hardDeadlineSeconds: 12.0
        )
    }

    private let timing = Timing.production

    private var hasPlayedThisSession = false
    private var panel: LaunchIntroPanel?
    private var player: AVPlayer?
    private var endObserver: Any?
    private var pendingExitTask: Task<Void, Never>?
    private var fallbackWorkItem: DispatchWorkItem?
    private var hardDeadlineWorkItem: DispatchWorkItem?
    /// Held for the intro's lifetime so App Nap doesn't delay the dismissal timers/animation
    /// below — DexDictate is an `LSUIElement` accessory app with no Dock-visible window, which
    /// is exactly what App Nap targets first when another app (e.g. a fullscreen game) has
    /// focus. Without this, the exit fade can stall, delaying dismissal.
    private var activityToken: NSObjectProtocol?
    /// Guards `forceDismiss()` so it's safe to call from the fade completion, either timer, or
    /// app shutdown without double-running teardown, and so any stale callback that fires after
    /// dismissal is a harmless no-op rather than mutating a dismissed (or future) panel. See
    /// `LaunchIntroDismissalGate`'s doc comment (in `DexDictateKit`) for why this idempotency
    /// guarantee is factored out as its own unit-testable type.
    private let dismissalGate = LaunchIntroDismissalGate()

    private static let animationNames: [String] = (1...8).map { String(format: "LaunchAnimation_%02d", $0) }
    // These clips have no "DexDictate" branding in the video itself.
    private static let animationsNeedingOverlay: Set<String> = ["LaunchAnimation_07", "LaunchAnimation_08"]

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

        dismissalGate.reset()
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "DexDictate launch intro animation"
        )

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.volume = 0
        player.actionAtItemEnd = .pause
        self.player = player

        let showOverlay = Self.animationsNeedingOverlay.contains(name)
        let startFrame = initialFrame(on: screen)
        let panel = LaunchIntroPanel(
            contentRect: startFrame,
            rootView: AnyView(LaunchIntroView(player: player, showNameOverlay: showOverlay))
        )
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        player.rate = 1.5

        // Hold on the final frame (brand card) for a beat, then exit.
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleExitAfterHold()
            }
        }

        scheduleSafetyNetTimers()
    }

    /// The fallback (exit regardless of playback completion) and hard-deadline (exit
    /// regardless of the fade animation completing) safety-net timers — split out of
    /// `playIfNeeded()` purely to keep that function's body within the project's length limit.
    private func scheduleSafetyNetTimers() {
        let fallback = DispatchWorkItem { [weak self] in
            guard let self, self.panel != nil else { return }
            self.fadeOutAndDismiss(duration: self.timing.fadeOutDurationSeconds)
        }
        fallbackWorkItem = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.fallbackDeadlineSeconds, execute: fallback)

        let hardDeadline = DispatchWorkItem { [weak self] in
            self?.forceDismiss()
        }
        hardDeadlineWorkItem = hardDeadline
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.hardDeadlineSeconds, execute: hardDeadline)
    }

    /// Runs on the main actor (called only from within `Task { @MainActor in }` bodies), so
    /// storing the resulting task on `pendingExitTask` here is properly isolated.
    private func scheduleExitAfterHold() {
        let holdSeconds = timing.holdAfterPlaybackSeconds
        let fadeSeconds = timing.fadeOutDurationSeconds
        pendingExitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(holdSeconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.fadeOutAndDismiss(duration: fadeSeconds)
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

    /// The intended full-panel exit: fade the still-full-size intro window to transparent,
    /// then tear it down. Deliberately does not resize or reposition the panel — it must
    /// close as the complete launch presentation, not shrink into a small badge/thumbnail
    /// first (that residual badge state is the bug this replaces).
    private func fadeOutAndDismiss(duration: Double) {
        guard let panel else { return }

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.forceDismiss()
            }
        }
    }

    /// The single teardown path for the intro panel — called from the exit fade's completion
    /// handler on the happy path, from the fallback/hard-deadline timers as guarantees, and
    /// from app shutdown. `dismissalGate` ensures whichever caller runs first does the work and
    /// every other (including any stale callback) is a no-op.
    private func forceDismiss() {
        guard dismissalGate.fireOnce() else { return }

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        pendingExitTask?.cancel()
        pendingExitTask = nil
        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
        hardDeadlineWorkItem?.cancel()
        hardDeadlineWorkItem = nil

        player?.pause()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        player = nil

        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
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
    var showNameOverlay: Bool = false

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

            if showNameOverlay {
                Text("DexDictate")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
            }
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
