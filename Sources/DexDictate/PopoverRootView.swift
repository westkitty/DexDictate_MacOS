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
    @ObservedObject var livePreviewController: LivePreviewController
    @State private var cachedWatermarkImage: NSImage? = nil
    /// Packet 12A adoption: re-hosts `DexCommandPaletteView` (unchanged, from
    /// `ExperimentalUI/`) as a full-content screen-swap — same technique the experimental
    /// popover itself uses to avoid sheet-triggered Dock bounce. `onOpenFeatureHub`/
    /// `onOpenGUISwitcher` are nil here (no equivalent screens in this popover), which the
    /// palette already renders as disabled affordances rather than requiring changes.
    @State private var isCommandPaletteShown = false

    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

    private var popoverHeight: CGFloat { PopoverSizing.cappedHeight(preferred: 480) }

    var body: some View {
        ZStack {
            if settings.appearanceTheme == .system {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            } else {
                settings.themeBackgroundColor
                    .ignoresSafeArea()
            }

            // The undo footer is a sibling of the screen swap, not a child of either branch,
            // so entering the command palette cannot take it away — see `PopoverUndoFooter`.
            VStack(spacing: 0) {
                Group {
                    if isCommandPaletteShown {
                        commandPaletteScreen
                    } else {
                        mainScreen
                    }
                }
                .frame(maxHeight: .infinity)

                Divider().opacity(0.2).padding(.horizontal, 12)
                PopoverUndoFooter(engine: engine)
            }

            // Invisible ⌘K shortcut for the command palette (Packet 12A adoption).
            Button("") { isCommandPaletteShown = true }
                .keyboardShortcut("k", modifiers: [.command])
                .opacity(0)
                .allowsHitTesting(false)
        }
        .frame(width: 320, height: popoverHeight)
        .onAppear {
            cachedWatermarkImage = loadWatermarkImage()
            logResolvedRoute()
        }
        .onChange(of: isCommandPaletteShown) { _, _ in
            logResolvedRoute()
        }
        .onChange(of: profileManager.currentWatermarkAsset?.url) { _, _ in
            cachedWatermarkImage = loadWatermarkImage()
        }
    }

    private var commandPaletteScreen: some View {
        DexCommandPaletteView(
            engine: engine,
            settings: settings,
            onBack: { isCommandPaletteShown = false },
            onOpenFeatureHub: nil,
            onOpenGUISwitcher: nil,
            onDetachHistory: onDetachHistory,
            onOpenHelp: onOpenHelp
        )
    }

    /// Records which interface actually mounted, which settings selected it, and the undo
    /// state at that moment. Added because the absent-undo-control defect survived several
    /// repairs that each assumed the wrong route from an `@AppStorage` default; the log makes
    /// the live answer readable instead of inferred. Carries no transcript or field content.
    private func logResolvedRoute() {
        let diagnostic = PopoverRouteDiagnostic(
            route: PopoverRoute.resolve(useSlimPopover: settings.useSlimPopover),
            screen: isCommandPaletteShown ? .commandPalette : .main,
            useSlimPopover: settings.useSlimPopover,
            useExperimentalStateFirstUI: settings.useExperimentalStateFirstUI,
            useExperimentalCommandPalette: settings.useExperimentalCommandPalette,
            engineIdentity: String(UInt(bitPattern: ObjectIdentifier(engine).hashValue), radix: 16),
            undoAvailability: engine.undoAvailability
        )
        Safety.log(diagnostic.summary, category: .general)
    }

    private var mainScreen: some View {
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
                        PopoverHeroView(engine: engine, settings: settings, livePreviewController: livePreviewController, watermarkImage: cachedWatermarkImage)
                        compactControlsRow
                        if engine.state == .listening {
                            DexTranscriptCard(transcript: liveTranscriptState)
                                .padding(.horizontal)
                        }
                    }

                    PopoverResultView(
                        engine: engine,
                        history: engine.history,
                        settings: settings,
                        profileManager: profileManager,
                        onOpenHistory: onDetachHistory
                    )

                    Divider().opacity(0.2).padding(.horizontal, 12)

                    PopoverHistoryTeaser(history: engine.history)

                    statusLine
                }
                .padding(.vertical, 10)
            }

            if engine.state != .stopped {
                stopDictationButton
            }

            Divider().opacity(0.2).padding(.horizontal, 12)

            footer
        }
    }

    /// Fixes the Minimalist theme seam (Packet 11) — same pattern as the classic popover's
    /// `headerForegroundColor` in `DexDictateApp.swift`.
    private var headerForegroundColor: Color {
        settings.appearanceTheme == .minimalist ? .black : .white
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("DexDictate")
                .font(.headline)
                .foregroundStyle(headerForegroundColor)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                ChromeIconButton(systemName: "power", accessibilityText: "Quit DexDictate", tint: headerForegroundColor) {
                    confirmAndQuit()
                }
                Spacer()
                ChromeIconButton(systemName: "gearshape", accessibilityText: "Open Settings", tint: headerForegroundColor) {
                    onOpenSettings?()
                }
                .help(NSLocalizedString("Settings…", comment: ""))
                ChromeIconButton(systemName: "questionmark.circle", accessibilityText: "Open Help", tint: headerForegroundColor) {
                    onOpenHelp?()
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// Uses a native `NSAlert` rather than SwiftUI's `.confirmationDialog` — the latter is
    /// unreliable inside a `MenuBarExtra(.window)` popover (the popover can lose key status
    /// and dismiss the instant the dialog tries to present, so the confirmation silently
    /// never appears and Quit does nothing). Same fix already proven in this codebase for
    /// `DiagnosticsPage`'s "Reset Core Audio?" confirmation.
    private func confirmAndQuit() {
        let alert = NSAlert()
        alert.messageText = "Quit DexDictate?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSApplication.shared.terminate(nil)
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
                    Button("Command Palette") { isCommandPaletteShown = true }
                    Divider()
                    Button("Quit App") { confirmAndQuit() }
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

    // MARK: - Stop Dictation (BUG-006B)

    /// Moved here from `PopoverHeroView` — this used to be the "Stop Dictation" half of a single
    /// combined Start/Stop button sitting at the top of the hero, where it visually competed with
    /// `compactControlsRow`'s model/trigger/status chips directly below it. Pinned outside the
    /// scrollable content (between the ScrollView and the footer divider) rather than inside it,
    /// so it stays visible without scrolling regardless of how much result/history content is
    /// showing. Same condition the old combined button used to show "Stop Dictation" under
    /// (`engine.state != .stopped`) and the same `engine.stopSystem()` call — only the control's
    /// position changed, not what it does.
    private var stopDictationButton: some View {
        Button(action: stopDictation) {
            HStack {
                Image(systemName: "stop.fill")
                Text("Stop Dictation")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.45))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop dictation system")
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func stopDictation() {
        MainActorAction.run { engine.stopSystem() }
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

    // MARK: - Packet 12A-B adoption: compact controls + live transcript

    /// "Daily six" one-tap pills (trigger/model/mode + auto-paste/safe-mode/clipboard-
    /// fallback status), flagged MISSING from the default popover in Packet 12A's
    /// inventory. Re-hosts `DexContextChips`/`DexOutputChips` unchanged from
    /// `ExperimentalUI/DexStateFirstComponents.swift` — zero edits to either view, only
    /// the params they already declare (`settings`, `WhisperModelCatalog.shared`,
    /// `engine.transcriptionProviderRegistry`), all already available in this popover
    /// without new threading.
    private var compactControlsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            DexContextChips(
                settings: settings,
                modelCatalog: WhisperModelCatalog.shared,
                registry: engine.transcriptionProviderRegistry
            )
            DexOutputChips(output: outputDisplayState)
        }
        .padding(.horizontal)
    }

    private var outputDisplayState: OutputDisplayState {
        let feedback = engine.resultFeedback
        let isClipboardFallback: Bool
        if case .copiedOnlySensitiveContext = feedback { isClipboardFallback = true } else { isClipboardFallback = false }
        let isFailure: Bool
        if case .noSpeechDetected = feedback { isFailure = true } else { isFailure = false }
        return OutputDisplayState(
            autoPaste: settings.autoPaste,
            safeMode: settings.safeModeEnabled,
            lastFeedbackTitle: feedback.title,
            lastFeedbackIcon: feedback.symbolName,
            isFailure: isFailure,
            isClipboardFallback: isClipboardFallback
        )
    }

    /// Live partial transcript + mic level while actively listening — the other item
    /// Packet 12A's inventory flagged MISSING. Reads `engine.liveTranscript` /
    /// `engine.inputLevel`, both already-`@Published` properties on the existing
    /// `TranscriptionEngine` singleton (no new audio tap, no forbidden-file edits — the
    /// same read-only-consumer pattern `DiagnosticsPage` already uses for
    /// `engine.routeHealthSnapshot`). `recentText: nil` keeps this card strictly to
    /// "what's happening right now"; the completed-result display stays
    /// `PopoverResultView`'s job, avoiding a duplicate "last transcription" line.
    private var liveTranscriptState: TranscriptDisplayState {
        TranscriptDisplayState(
            liveText: engine.liveTranscript,
            recentText: nil,
            inputLevel: engine.inputLevel,
            silenceCountdown: engine.silenceCountdown,
            unavailableReason: liveTranscriptUnavailableReason
        )
    }

    /// Honest explanation for why no live words are appearing, shown only once we actually
    /// know this session resolved to a non-streaming engine — never guessed or shown before
    /// the resolver has run. `nil` (the card falls back to "No recent transcription") whenever
    /// Live Transcription is off entirely, so this stays specific to the "the feature is on
    /// but this engine can't stream" case Phase 6 asks to make honest.
    private var liveTranscriptUnavailableReason: String? {
        guard settings.liveTranscriptionEnabled,
              let resolution = engine.transcriptionProviderRegistry.lastResolution,
              !resolution.usesLiveStreaming else {
            return nil
        }
        return "Live text is unavailable with the selected transcription engine (\(resolution.selectedProviderDisplayName)). Final transcription will still appear when recording ends."
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
