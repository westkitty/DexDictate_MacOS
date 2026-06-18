import SwiftUI
import DexDictateKit

// MARK: - Screen State

/// All screens reachable inside the state-first popover without opening a separate window.
enum ExperimentalScreen: Equatable {
    case main
    case settingsAndHistory
    case commandPalette
    case featureHub
    case guiSwitcher
}

// MARK: - View

/// Experimental state-first compact popover.
///
/// Shown only when `AppSettings.useExperimentalStateFirstUI == true`.
/// The existing `AntiGravityMainView` remains in place and is fully reachable by
/// disabling the flag — no production behaviour is removed.
///
/// Navigation between sub-panels is handled via `screen` state so that no
/// `.sheet` presentations are used, which avoids the Dock-bounce that occurs
/// when `NSApp.activate()` is triggered by a sheet presentation.
struct DexStateFirstPopoverView: View {
    @ObservedObject var adapter: DexExperimentalUIStateAdapter
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var profileManager: ProfileManager

    @State private var screen: ExperimentalScreen = .main
    @State private var cachedWatermarkImage: NSImage? = nil

    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer

            switch screen {
            case .main:
                mainContent
            case .settingsAndHistory:
                DexLayeredRevealView(
                    settings: settings,
                    engine: engine,
                    profileManager: profileManager,
                    onBack: { screen = .main },
                    onOpenFeatureHub: { screen = .featureHub },
                    onOpenGUISwitcher: { screen = .guiSwitcher },
                    onDetachHistory: onDetachHistory,
                    onOpenHelp: onOpenHelp,
                    onRequestOnboardingDebug: onRequestOnboardingDebug
                )
                .background(overlayBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .commandPalette:
                DexCommandPaletteView(
                    engine: engine,
                    settings: settings,
                    onBack: { screen = .main },
                    onOpenFeatureHub: { screen = .featureHub },
                    onOpenGUISwitcher: { screen = .guiSwitcher },
                    onDetachHistory: onDetachHistory,
                    onOpenHelp: onOpenHelp
                )
                .background(overlayBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .featureHub:
                DexExperimentalFeatureHubView(
                    engine: engine,
                    settings: settings,
                    profileManager: profileManager,
                    onBack: { screen = .main },
                    onDetachHistory: onDetachHistory,
                    onOpenHelp: onOpenHelp,
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
                .background(overlayBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .guiSwitcher:
                DexExperimentalGUISwitcherView(
                    settings: settings,
                    onBack: { screen = .main }
                )
                .background(overlayBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 320, height: 480)
        .onAppear { cachedWatermarkImage = loadWatermarkImage() }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    titleBar
                    DexStateHero(engineState: adapter.state.engine)
                    permissionRow
                    contextChips
                    transcriptCard
                    feedbackBadge
                    outputChips
                    dexterLine
                    Spacer(minLength: 8)
                    controlButtons
                    navButtonRow
                    experimentBadge
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Backgrounds

    private var backgroundLayer: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            if let nsImage = cachedWatermarkImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .opacity(0.09)
                    .allowsHitTesting(false)
            }

            Text("DEXDICTATE")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.08))
                .rotationEffect(.degrees(-18))
                .allowsHitTesting(false)
        }
    }

    private var overlayBackground: Color {
        Color(red: 0.09, green: 0.10, blue: 0.14)
    }

    // MARK: - Title bar

    private var titleBar: some View {
        ZStack {
            Text("DexDictate")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                ChromeIconButton(
                    systemName: "questionmark.circle",
                    accessibilityText: "Open Help"
                ) {
                    onOpenHelp?()
                }
            }
        }
    }

    // MARK: - Info rows

    private var permissionRow: some View {
        DexPermissionChips(
            permissions: adapter.state.permissions,
            onFixTap: openSystemPermissions
        )
    }

    private var contextChips: some View {
        DexContextChips(
            settings: settings,
            modelCatalog: WhisperModelCatalog.shared
        )
    }

    private var transcriptCard: some View {
        DexTranscriptCard(transcript: adapter.state.transcript)
    }

    @ViewBuilder
    private var feedbackBadge: some View {
        let out = adapter.state.output
        if !out.lastFeedbackTitle.isEmpty {
            HStack {
                DexFeedbackBadge(
                    title: out.lastFeedbackTitle,
                    icon: out.lastFeedbackIcon,
                    isFailure: out.isFailure
                )
                Spacer()
            }
        }
    }

    private var outputChips: some View {
        DexOutputChips(output: adapter.state.output)
    }

    @ViewBuilder
    private var dexterLine: some View {
        if settings.showFlavorTicker {
            DexterCommentaryLine(text: adapter.state.dexterLine.text)
        }
    }

    // MARK: - Control buttons

    @ViewBuilder
    private var controlButtons: some View {
        if engine.state == .stopped {
            startDictationButton
        }
    }

    private var startDictationButton: some View {
        Button(action: startDictation) {
            HStack {
                Image(systemName: "mic.fill")
                    .accessibilityHidden(true)
                Text("Start Dictation")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.38))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start dictation system")
    }

    // MARK: - Navigation buttons

    private var navButtonRow: some View {
        VStack(spacing: 6) {
            settingsRevealButton
            allFeaturesButton
            HStack(spacing: 6) {
                if settings.useExperimentalCommandPalette {
                    commandPaletteButton
                }
                guiSwitcherButton
            }
        }
    }

    private var settingsRevealButton: some View {
        Button(action: { screen = .settingsAndHistory }) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("Settings & History")
                    .font(.caption.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .foregroundStyle(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings and history panel")
    }

    private var allFeaturesButton: some View {
        Button(action: { screen = .featureHub }) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("All Features")
                    .font(.caption.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .foregroundStyle(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open all features panel")
    }

    private var commandPaletteButton: some View {
        Button(action: { screen = .commandPalette }) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("Commands")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("⌘K")
                    .font(.caption2.monospaced())
                    .opacity(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .foregroundStyle(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open command palette")
    }

    private var guiSwitcherButton: some View {
        Button(action: { screen = .guiSwitcher }) {
            HStack(spacing: 6) {
                Image(systemName: "switch.2")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("Switch UI")
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .foregroundStyle(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch UI surface")
    }

    // MARK: - Experiment badge

    private var experimentBadge: some View {
        Text("Experimental UI · Switch UI to return to standard")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.28))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func startDictation() {
        MainActorAction.run {
            await engine.startSystem()
        }
    }

    private func openSystemPermissions() {
        if !permissionManager.accessibilityGranted {
            permissionManager.openAccessibilitySettings()
        } else if !permissionManager.microphoneGranted {
            permissionManager.openMicrophoneSettings()
        } else {
            permissionManager.openInputMonitoringSettings()
        }
    }

    private func loadWatermarkImage() -> NSImage? {
        if let url = Safety.resourceBundle.url(
            forResource: "Assets.xcassets/AppIcon.appiconset/icon",
            withExtension: "png"
        ), let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }
}
