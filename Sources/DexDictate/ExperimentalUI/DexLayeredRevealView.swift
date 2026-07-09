import SwiftUI
import AppKit
import DexDictateKit

/// Sparse layered reveal panel — settings, history, and Dexter feed.
/// Embedded in-popover via `DexStateFirstPopoverView`'s screen state machine.
///
/// Each layer is independent; selecting a layer reveals its content without
/// disturbing the others. Back button / Escape returns to the main popover.
/// Reduced-motion users see opacity transitions instead of slide travel.
struct DexLayeredRevealView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var profileManager: ProfileManager
    var onBack: () -> Void
    var onOpenFeatureHub: (() -> Void)?
    var onOpenGUISwitcher: (() -> Void)?
    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

    @State private var activeLayer: RevealLayer = .none
    @State private var isResettingCoreAudio = false
    @State private var coreAudioResetStatus: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let coreAudioResetService = CoreAudioResetService()

    enum RevealLayer: Equatable {
        case none, history, settings, dexter
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            layerPicker
            Divider().opacity(0.10)
            layerContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    )
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: activeLayer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                    Text("Back")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to main popover")
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text("Settings & History")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 10) {
                Button(action: { onOpenFeatureHub?() }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open all features")
                .help("All Features")
                .disabled(onOpenFeatureHub == nil)

                Button(action: { onOpenGUISwitcher?() }) {
                    Image(systemName: "switch.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch UI surface")
                .help("Switch UI")
                .disabled(onOpenGUISwitcher == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Layer picker

    private var layerPicker: some View {
        HStack(spacing: 8) {
            layerButton("History",  icon: "clock",               layer: .history)
            layerButton("Settings", icon: "slider.horizontal.3", layer: .settings)
            layerButton("Dexter",   icon: "quote.bubble",        layer: .dexter)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func layerButton(_ label: String, icon: String, layer: RevealLayer) -> some View {
        Button(action: {
            withAnimation { activeLayer = (activeLayer == layer) ? .none : layer }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(activeLayer == layer ? Color.cyan.opacity(0.22) : Color.white.opacity(0.06))
            .foregroundStyle(activeLayer == layer ? Color.cyan : Color.white.opacity(0.70))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) layer\(activeLayer == layer ? ", selected" : "")")
    }

    // MARK: - Layer content

    @ViewBuilder
    private var layerContent: some View {
        switch activeLayer {
        case .none:
            emptyState
        case .history:
            historyLayer
        case .settings:
            settingsLayer
        case .dexter:
            dexterLayer
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.3.layers.3d")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.22))
                .accessibilityHidden(true)
            Text("Select a layer above")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History layer

    private var historyLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Transcriptions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if engine.history.items.isEmpty {
                        Text("No transcriptions yet in this session.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(engine.history.items.prefix(12)) { item in
                            Text(item.text)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .padding(.horizontal, 16)
                                .accessibilityLabel(item.text)
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            Divider().opacity(0.12).padding(.horizontal, 16)

            Button(action: openFullHistory) {
                Label("Open Full History Window", systemImage: "arrow.up.forward.square")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityLabel("Open full history window")
        }
    }

    // MARK: - Settings layer

    private var settingsLayer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // -- Transcription --
                sectionHeader("Transcription")

                DexRevealToggleRow(
                    icon: "waveform.badge.mic",
                    title: "Live Transcription",
                    detail: "Live partial captions while you speak (Nemotron, then Apple Speech). Doesn't affect what actually gets typed — see Primary Dictation Engine below.",
                    isOn: $settings.liveTranscriptionEnabled
                )

                DexRevealToggleRow(
                    icon: "command",
                    title: "Command Mode",
                    detail: "Short recordings (under 2.5s) are checked against Moonshine for a recognized command phrase before falling through to the primary engine.",
                    isOn: $settings.commandModeEnabled
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Primary dictation engine: \(primaryEngineDisplayName)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    if let resolution = engine.transcriptionProviderRegistry.lastResolution {
                        Text("Live preview: \(resolution.selectedProviderDisplayName) (\(resolution.modeName))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 2)
                .onAppear {
                    engine.transcriptionProviderRegistry.resolveActiveProvider(
                        liveTranscriptionEnabled: settings.liveTranscriptionEnabled
                    )
                }

                Text("Pick which model/engine is active, and download new ones, from the \"brain\" chip in the main screen or Quick Settings → Transcription Engines.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.30))
                    .fixedSize(horizontal: false, vertical: true)

                // -- Output --
                sectionHeader("Output")

                DexRevealToggleRow(
                    icon: "doc.on.clipboard.fill",
                    title: "Auto-paste",
                    detail: "Paste transcription into the active app after recording.",
                    isOn: $settings.autoPaste
                )

                // -- Safety --
                sectionHeader("Safety")

                DexRevealToggleRow(
                    icon: "shield.lefthalf.filled",
                    title: "Safe Mode",
                    detail: "Conservative dictation output: shorter pauses, lower risk. Existing preset preserved.",
                    isOn: safeModeBinding
                )

                // -- Advanced --
                Text("Advanced")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                advancedAudioRecoveryPanel

                // -- HUD --
                sectionHeader("HUD")

                DexRevealToggleRow(
                    icon: "eye",
                    title: "Show Floating HUD",
                    detail: "Display a small floating strip showing recording state.",
                    isOn: $settings.showFloatingHUD
                )

                // -- Info footer --
                Text("Full settings available in Quick Settings → Appearance & System and other panels.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.30))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // -- Same primary-engine logic Classic and the model chip use — see `ModelSelectionActions`.
    private var primaryEngineDisplayName: String {
        let registry = engine.transcriptionProviderRegistry
        let primary = ModelSelectionActions.primaryEngineID(settings: settings, registry: registry)
        return primary == .parakeetTDT06Bv3 ? registry.parakeetProvider.displayName : registry.whisperKitProvider.displayName
    }

    // -- Safe mode binding mirrors QuickSettingsView pattern --
    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { settings.safeModeEnabled },
            set: { enabled in
                if enabled { settings.enableSafeMode() }
                else       { settings.disableSafeMode() }
            }
        )
    }

    private var advancedAudioRecoveryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advanced Audio Recovery")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange.opacity(0.9))

            Text("If microphone input keeps failing, macOS Core Audio may be stuck. Resetting Core Audio restarts the system audio service and usually fixes missing or frozen microphones.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                resetCoreAudio()
            } label: {
                HStack(spacing: 6) {
                    if isResettingCoreAudio {
                        ProgressView()
                            .scaleEffect(0.55)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "waveform.badge.exclamationmark")
                            .accessibilityHidden(true)
                    }
                    Text(isResettingCoreAudio ? "Resetting..." : "Reset Core Audio")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.orange.opacity(0.22))
            .foregroundStyle(.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isResettingCoreAudio)
            .accessibilityLabel("Reset Core Audio")

            if let coreAudioResetStatus {
                Text(coreAudioResetStatus)
                    .font(.caption2)
                    .foregroundStyle(coreAudioResetStatus.lowercased().contains("failed") ? .red.opacity(0.9) : .white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func resetCoreAudio() {
        guard !isResettingCoreAudio else { return }
        let alert = NSAlert()
        alert.messageText = "Reset Core Audio?"
        alert.informativeText = "This will restart macOS Core Audio. Your audio devices may briefly disconnect and reconnect. Continue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        isResettingCoreAudio = true
        coreAudioResetStatus = "macOS will ask for administrator permission to restart Core Audio."
        Safety.log("DexLayeredRevealView — Reset Core Audio button invoked", category: .audio)

        Task { @MainActor in
            do {
                try await coreAudioResetService.resetCoreAudio()
                try await Task.sleep(nanoseconds: 1_200_000_000)
                validatePreferredInputAfterCoreAudioReset()

                switch await engine.rebuildAudioAfterCoreAudioReset() {
                case .success(let message):
                    coreAudioResetStatus = message
                    Safety.log("DexLayeredRevealView — Core Audio reset postflight succeeded: \(message)", category: .audio)
                case .failure(let error):
                    coreAudioResetStatus = "Core Audio reset completed, but audio input restart failed: \(error.localizedDescription)"
                    Safety.log("DexLayeredRevealView — Core Audio reset postflight restart failed: \(error)", category: .audio)
                }
            } catch {
                coreAudioResetStatus = "Core Audio reset failed: \(error.localizedDescription)"
                Safety.log("DexLayeredRevealView — Core Audio reset failed: \(error)", category: .audio)
            }

            isResettingCoreAudio = false
        }
    }

    private func validatePreferredInputAfterCoreAudioReset() {
        let preferredUID = settings.inputDeviceUID
        guard !preferredUID.isEmpty else {
            Safety.log("DexLayeredRevealView — Core Audio reset postflight device validation: System Default selected", category: .audio)
            return
        }

        let devices = AudioDeviceManager.inputDevices()
        if devices.contains(where: { $0.uid == preferredUID }) {
            Safety.log("DexLayeredRevealView — Core Audio reset postflight device validation succeeded for preferredUID='\(preferredUID)'", category: .audio)
        } else {
            settings.inputDeviceUID = ""
            Safety.log("DexLayeredRevealView — Core Audio reset postflight cleared stale preferredUID='\(preferredUID)'", category: .audio)
        }
    }

    // MARK: - Dexter layer

    private var dexterLayer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                sectionHeader("Commentary")

                DexRevealToggleRow(
                    icon: "quote.bubble.fill",
                    title: "Show Dexter commentary",
                    detail: "One-liner flavor text in the popover. Muting here affects the standard and state-first popovers.",
                    isOn: $settings.showFlavorTicker
                )

                DexRevealToggleRow(
                    icon: "play.circle",
                    title: "Animate ticker",
                    detail: "Scrolls long lines in the ticker. Respects Reduce Motion.",
                    isOn: $settings.animateFlavorTicker
                )

                if settings.useExperimentalDexterFeed {
                    sectionHeader("Dexter Feed (Experimental)")
                    DexDexterFeedView(settings: settings, profileManager: profileManager)
                } else {
                    Text("Enable \"Dexter Feed\" in Experimental UI settings to access the stateful feed.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.30))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.40))
            .tracking(0.8)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func openFullHistory() {
        onDetachHistory?()
        onBack()
    }
}

// MARK: - Toggle Row Component

private struct DexRevealToggleRow: View {
    let icon: String
    let title: String
    let detail: String
    let isOn: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .frame(width: 18)
                        .foregroundStyle(.white.opacity(0.60))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .toggleStyle(.switch)
            .accessibilityLabel(title)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 26)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
