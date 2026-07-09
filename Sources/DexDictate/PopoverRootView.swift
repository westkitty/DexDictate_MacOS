import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DexDictateKit

/// Packet 09 slim popover contract: Header, Ticker, State hero (or error banner), Last
/// result, History teaser, Status line, Footer. Selected behind `settings.useSlimPopover`
/// (Stage A: default off, old `AntiGravityMainView` stays default; Stage B flips it).
///
/// REMOVED vs. the classic popover: Quick Settings remnants, the giant red "Turn Off
/// Dictation" button styling, the always-visible Transcribe File button (now in overflow),
/// "Restore Defaults" (now in Settings → General), the floating TRIGGER/Scheduled label
/// stack, and all benchmark traces. Ticker and watermark logic/timing are untouched —
/// only their container placement changed, per this packet's forbidden-file rules.
struct PopoverRootView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    @State private var cachedWatermarkImage: NSImage? = nil
    @State private var isQuitConfirmPresented = false

    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

    private var popoverHeight: CGFloat { PopoverSizing.cappedHeight(preferred: 480) }

    var body: some View {
        VStack(spacing: 0) {
            header

            if settings.showFlavorTicker {
                FlavorTickerView(
                    text: profileManager.currentFlavorLine?.text ?? "",
                    animateWhenNeeded: settings.animateFlavorTicker
                )
            }

            Divider().opacity(0.2).padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 12) {
                    if !permissionManager.allPermissionsGranted {
                        errorBanner
                    } else {
                        PopoverHeroView(engine: engine, settings: settings, watermarkImage: cachedWatermarkImage)
                    }

                    PopoverResultView(engine: engine, settings: settings)

                    Divider().opacity(0.2).padding(.horizontal, 12)

                    PopoverHistoryTeaser(history: engine.history, onOpenHistory: onDetachHistory)

                    statusLine
                }
                .padding(.vertical, 10)
            }

            Divider().opacity(0.2).padding(.horizontal, 12)

            footer
        }
        .frame(width: 320, height: popoverHeight)
        .onAppear {
            cachedWatermarkImage = loadWatermarkImage()
        }
        .onChange(of: profileManager.currentWatermarkAsset?.url) { _, _ in
            cachedWatermarkImage = loadWatermarkImage()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("DexDictate")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                ChromeIconButton(systemName: "power", accessibilityText: "Quit DexDictate") {
                    isQuitConfirmPresented = true
                }
                Spacer()
                ChromeIconButton(systemName: "gearshape", accessibilityText: "Open Settings") {
                    onOpenSettings?()
                }
                .help(NSLocalizedString("Settings…", comment: ""))
                ChromeIconButton(systemName: "questionmark.circle", accessibilityText: "Open Help") {
                    onOpenHelp?()
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .confirmationDialog(
            "Quit DexDictate?",
            isPresented: $isQuitConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Error banner (replaces the hero on permission/mic failure)

    private var errorBanner: some View {
        let (message, fixTitle, fixAction): (String, String, () -> Void) = {
            if !permissionManager.microphoneGranted {
                return (permissionManager.permissionsSummary, "Open Microphone Settings", permissionManager.openMicrophoneSettings)
            } else if !permissionManager.accessibilityGranted {
                return (permissionManager.permissionsSummary, "Open Accessibility Settings", permissionManager.openAccessibilitySettings)
            } else {
                return (permissionManager.permissionsSummary, "Open Input Monitoring Settings", permissionManager.openInputMonitoringSettings)
            }
        }()

        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(fixTitle) { fixAction() }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(SurfaceTokens.cardPadding)
        .background(Color.orange.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
        .padding(.horizontal)
    }

    // MARK: - Status line

    private var statusLine: some View {
        Button {
            onOpenSettings?()
        } label: {
            Text("Mic: \(engine.routeHealthSnapshot.activeInputLabel) · \(settings.activeWhisperModelID)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Settings…") { onOpenSettings?() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .keyboardShortcut(",", modifiers: [.command])

                Spacer()

                Menu {
                    Button("Transcribe File…") { importAudioFile() }
                    Toggle("Safe Mode", isOn: safeModeBinding)
                    Button("Pause Dictation") { pauseDictation() }
                    Divider()
                    Button("Quit App") { isQuitConfirmPresented = true }
                } label: {
                    Text("⋯")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(.horizontal, 16)

            Button(action: registerVersionTapForOnboarding) {
                Text(String(format: NSLocalizedString("DexDictate macOS v%@", comment: ""),
                             Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
        .padding(.top, 6)
    }

    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { settings.safeModeEnabled },
            set: { enabled in
                if enabled {
                    settings.enableSafeMode()
                } else {
                    settings.disableSafeMode()
                }
            }
        )
    }

    @State private var onboardingDebugTapCount = 0

    private func registerVersionTapForOnboarding() {
        onboardingDebugTapCount += 1
        if onboardingDebugTapCount >= 5 {
            onboardingDebugTapCount = 0
            onRequestOnboardingDebug?()
        }
    }

    /// "Pause Dictation" has no distinct engine state from Stop today (`EngineState` has no
    /// `.paused` case, and adding one would mean editing the forbidden
    /// `TranscriptionEngine.swift`). Calls the same `stopSystem()` as Stop/Quit-adjacent
    /// controls — same behavior, wireframe-requested label. Documented in the packet report.
    private func pauseDictation() {
        MainActorAction.run { engine.stopSystem() }
    }

    private func importAudioFile() {
        MainActorAction.run {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.audio]
            panel.prompt = NSLocalizedString("Transcribe", comment: "Open panel button label")
            panel.message = NSLocalizedString("Select an audio file to transcribe", comment: "Open panel message")
            guard panel.runModal() == .OK, let url = panel.url else { return }
            engine.transcribeAudioFile(url: url)
        }
    }

    private func loadWatermarkImage() -> NSImage? {
        if let assetURL = profileManager.currentWatermarkAsset?.url,
           let nsImage = NSImage(contentsOf: assetURL) {
            return nsImage
        }
        if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return nsImage
        }
        return nil
    }
}
