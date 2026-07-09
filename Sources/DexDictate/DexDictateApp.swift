import SwiftUI
import AVFoundation
import Combine
import DexDictateKit

/// Application entry point. Configures the `MenuBarExtra` scene and wires together
/// `TranscriptionEngine`, `PermissionManager`, and `Settings`.
@main
struct DexDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Use shared engine to ensure Intents modify the same instance
    @StateObject private var engine = TranscriptionEngine.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var scanner = AudioDeviceScanner()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var benchmarkCaptureController = BenchmarkCaptureWindowController()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var menuBarIconController = MenuBarIconController.shared
    @StateObject private var modelCatalog = WhisperModelCatalog.shared
    @StateObject private var adaptiveBenchmarkController = AdaptiveBenchmarkController()
    @StateObject private var benchmarkResultsStore = BenchmarkResultsStore.shared
    
    // HUD Controller
    @StateObject private var hudController = FloatingHUDController()
    // History Controller
    @StateObject private var historyController = HistoryWindowController()
    // Help Controller
    @StateObject private var helpController = HelpWindowController()
    // Settings Controller
    @StateObject private var settingsWindowController = SettingsWindowController()

    init() {
        Safety.setupDirectories()
        // Last-resort net: record any uncaught Obj-C exception to local diagnostics before exit.
        CrashReporter.install()
        _ = ApplicationContextTracker.shared
    }

    var body: some Scene {
        MenuBarExtra {
            Group {
                if settings.useExperimentalStateFirstUI {
                    DexExperimentalEntry(
                        engine: engine,
                        permissionManager: permissionManager,
                        settings: settings,
                        profileManager: profileManager,
                        onDetachHistory: {
                            MainActorAction.run { historyController.show() }
                        },
                        onOpenHelp: {
                            MainActorAction.run { helpController.show() }
                        },
                        onRequestOnboardingDebug: {
                            MainActorAction.run { appDelegate.presentOnboardingForDebug() }
                        }
                    )
                } else if settings.useSlimPopover {
                    // Packet 09 — new slim popover contract. Stage A: reachable only via
                    // this debug flag (default off). Stage B flips the default to true.
                    PopoverRootView(
                        engine: engine,
                        permissionManager: permissionManager,
                        settings: settings,
                        profileManager: profileManager,
                        onDetachHistory: {
                            MainActorAction.run { historyController.show() }
                        },
                        onOpenHelp: {
                            MainActorAction.run { helpController.show() }
                        },
                        onOpenSettings: {
                            MainActorAction.run {
                                settingsWindowController.show(
                                    scanner: scanner,
                                    benchmarkCaptureController: benchmarkCaptureController,
                                    historyController: historyController
                                )
                            }
                        },
                        onRequestOnboardingDebug: {
                            MainActorAction.run { appDelegate.presentOnboardingForDebug() }
                        }
                    )
                } else {
                    AntiGravityMainView(
                        engine: engine,
                        permissionManager: permissionManager,
                        settings: settings,
                        scanner: scanner,
                        profileManager: profileManager,
                        benchmarkCaptureController: benchmarkCaptureController,
                        menuBarIconController: menuBarIconController,
                        modelCatalog: modelCatalog,
                        adaptiveBenchmarkController: adaptiveBenchmarkController,
                        benchmarkResultsStore: benchmarkResultsStore,
                        onDetachHistory: {
                            MainActorAction.run { historyController.show() }
                        },
                        onOpenHelp: {
                            MainActorAction.run { helpController.show() }
                        },
                        onOpenSettings: {
                            MainActorAction.run {
                                settingsWindowController.show(
                                    scanner: scanner,
                                    benchmarkCaptureController: benchmarkCaptureController,
                                    historyController: historyController
                                )
                            }
                        },
                        onRequestOnboardingDebug: {
                            MainActorAction.run { appDelegate.presentOnboardingForDebug() }
                        }
                    )
                }
            }
            .onAppear {
                // Fires every time the MenuBarExtra popover opens.
                permissionManager.startMonitoring(engine: engine)
                permissionManager.refreshPermissions()
                profileManager.synchronizeBundledVocabulary(with: engine.vocabularyManager)
                profileManager.refreshDynamicContent()
                ExperimentFlags.applyRuntimeSettings(settings)
                modelCatalog.refresh()

                let modelResolution = modelCatalog.resolveSelection(savedID: settings.activeWhisperModelID)
                if modelResolution.resolvedID != settings.activeWhisperModelID {
                    settings.activeWhisperModelID = modelResolution.resolvedID
                }

                // UI controllers require SwiftUI-owned objects so they must be wired here
                // (not in applicationDidFinishLaunching). Idempotent — safe on every open.
                hudController.setup(
                    engine: engine,
                    profileManager: profileManager,
                    onDetachHistory: { MainActorAction.run { historyController.show() } },
                    onOpenHelp: { MainActorAction.run { helpController.show() } }
                )
                historyController.setup(engine: engine, vocabularyManager: engine.vocabularyManager)
                adaptiveBenchmarkController.start(engine: engine)

                // Engine already running (started at launch). Nothing more to do.
                guard engine.state == .stopped else { return }

                // Fallback: onboarding just completed or launch startup was skipped.
                permissionManager.requestPermissions()
                permissionManager.requestMicrophoneIfNeeded()
                engine.setPermissionManager(permissionManager)

                if let activeModel = modelCatalog.activeDescriptor(settings: settings) {
                    engine.loadWhisperModel(descriptor: activeModel)
                }

                if settings.persistHistory {
                    Task {
                        let saved = await HistoryPersistenceManager.loadAsync()
                        if !saved.isEmpty {
                            for item in saved {
                                engine.history.insert(item)
                            }
                        }
                    }
                }

                Task {
                    await engine.startSystem()
                }

                if settings.showFloatingHUD {
                    hudController.show()
                }
            }
            .onChange(of: settings.showFloatingHUD) { _, newValue in
                hudController.toggle(shouldShow: newValue)
            }
            .onChange(of: settings.useExperimentalNanoHUD) { _, _ in
                hudController.refresh()
            }
            .onChange(of: settings.localizationMode) { _, _ in
                profileManager.synchronizeFromSettings()
                profileManager.synchronizeBundledVocabulary(with: engine.vocabularyManager)
                profileManager.refreshDynamicContent()
            }
            .onChange(of: settings.activeWhisperModelID) { _, _ in
                modelCatalog.refresh()
                if engine.state == .ready || engine.state == .stopped,
                   let activeModel = modelCatalog.activeDescriptor(settings: settings) {
                    engine.loadWhisperModel(descriptor: activeModel)
                }
            }
            .onChange(of: settings.utteranceEndPreset) { _, _ in
                if engine.state == .ready || engine.state == .stopped {
                    ExperimentFlags.applyRuntimeSettings(settings)
                }
            }
            .onChange(of: settings.enableTrailingTrimExperiment) { _, _ in
                if engine.state == .ready || engine.state == .stopped {
                    ExperimentFlags.applyRuntimeSettings(settings)
                }
            }
            .onChange(of: settings.enableSilenceTrim) { _, _ in
                if engine.state == .ready || engine.state == .stopped {
                    ExperimentFlags.applyRuntimeSettings(settings)
                }
            }
            .onChange(of: engine.lastDictationCompletionAt) { _, newValue in
                if newValue != nil {
                    adaptiveBenchmarkController.noteDictationFinished()
                }
            }
            .onReceive(engine.history.$items.debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)) { items in
                if settings.persistHistory {
                    Task {
                        await HistoryPersistenceManager.saveAsync(items)
                    }
                }
            }
        } label: {
            MenuBarStatusLabel(
                engine: engine,
                settings: settings,
                menuBarIconController: menuBarIconController
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var menuBarIconController: MenuBarIconController
    @State private var isPulsing = false
    private let pulseTimer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()

    private var isActive: Bool {
        engine.state == .listening || engine.state == .transcribing
    }

    private var activeStatusText: String {
        engine.state == .transcribing ? "Processing" : "Recording"
    }

    var body: some View {
        Group {
            if isActive {
                activeLabel
            } else {
                idleLabel
            }
        }
        .onAppear { isPulsing = isActive }
        .onChange(of: isActive) { _, newValue in
            isPulsing = newValue
        }
        .onReceive(pulseTimer) { _ in
            guard isActive else {
                isPulsing = false
                return
            }

            withAnimation(.easeInOut(duration: 0.28)) {
                isPulsing.toggle()
            }
        }
    }

    @ViewBuilder
    private var idleLabel: some View {
        switch settings.menuBarDisplayMode {
        case .micAndText:
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                Text("DexDictate")
            }
        case .micOnly:
            Image(systemName: "mic.fill")
        case .customIcon:
            if let selectedIcon = menuBarIconController.selectedIcon(using: settings),
               let image = menuBarIconController.menuBarImage(for: selectedIcon) {
                MenuBarDexIcon(image: image, isActive: false, isPulsing: false)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                    Text("DexDictate")
                }
            }
        case .logoOnly:
            if let image = menuBarIconController.appLogoMenuBarImage() {
                MenuBarDexIcon(image: image, isActive: false, isPulsing: false)
            } else {
                Image(systemName: "mic.fill")
            }
        case .emojiIcon:
            MenuBarEmojiIcon(emoji: settings.selectedMenuBarEmoji, isActive: false, isPulsing: false)
        }
    }

    @ViewBuilder
    private var activeLabel: some View {
        switch settings.menuBarDisplayMode {
        case .micAndText:
            HStack(spacing: 4) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.red)
                Text(activeStatusText)
                    .foregroundStyle(.red)
            }
        case .micOnly:
            HStack(spacing: 4) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.red)
                Text(activeStatusText)
                    .foregroundStyle(.red)
            }
        case .customIcon:
            if let selectedIcon = menuBarIconController.selectedIcon(using: settings),
               let image = menuBarIconController.menuBarImage(for: selectedIcon) {
                HStack(spacing: 4) {
                    MenuBarDexIcon(image: image, isActive: true, isPulsing: isPulsing)
                    Text(activeStatusText)
                        .foregroundStyle(.red)
                }
            } else {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.red)
            }
        case .logoOnly:
            if let image = menuBarIconController.appLogoMenuBarImage() {
                HStack(spacing: 4) {
                    MenuBarDexIcon(image: image, isActive: true, isPulsing: isPulsing)
                    Text(activeStatusText)
                        .foregroundStyle(.red)
                }
            } else {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.red)
            }
        case .emojiIcon:
            HStack(spacing: 4) {
                MenuBarEmojiIcon(emoji: settings.selectedMenuBarEmoji, isActive: true, isPulsing: isPulsing)
                Text(activeStatusText)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct MenuBarDexIcon: View {
    let image: NSImage
    let isActive: Bool
    let isPulsing: Bool

    var body: some View {
        HStack(spacing: 2) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.red.opacity(isPulsing ? 0.28 : 0.14))
                        .frame(width: 22, height: 22)
                }

                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(isActive ? .red : .primary)
                    .frame(width: 19, height: 19)
                    .scaleEffect(isActive && isPulsing ? 1.06 : 1)
            }

            if isActive {
                MenuBarRecordingBadge(isPulsing: isPulsing)
            }
        }
    }
}

private struct MenuBarEmojiIcon: View {
    let emoji: String
    let isActive: Bool
    let isPulsing: Bool

    var body: some View {
        HStack(spacing: 2) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.red.opacity(isPulsing ? 0.28 : 0.14))
                        .frame(width: 22, height: 22)
                }

                Text(emoji)
                    .font(.system(size: 17))
                    .frame(width: 20, height: 20)
                    .scaleEffect(isActive && isPulsing ? 1.07 : 1)
            }

            if isActive {
                MenuBarRecordingBadge(isPulsing: isPulsing)
            }
        }
    }
}

private struct MenuBarRecordingBadge: View {
    let isPulsing: Bool

    var body: some View {
        Image(systemName: "record.circle.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.red)
            .scaleEffect(isPulsing ? 1.18 : 0.9)
            .shadow(color: .red.opacity(0.45), radius: isPulsing ? 3 : 1)
    }
}


// MARK: - UI Mode Switch

/// A prominent one-tap switch between the classic and experimental interfaces.
/// Reads/sets `AppSettings.useExperimentalStateFirstUI`; the MenuBarExtra body swaps the
/// whole UI live. Designed to sit top-left in both interfaces so you can flip either way.
struct UIModeToggleButton: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.useExperimentalStateFirstUI.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.useExperimentalStateFirstUI ? "rectangle.on.rectangle" : "sparkles")
                Text(settings.useExperimentalStateFirstUI ? "Classic" : "New UI")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help("Switch between the classic and the new interface")
    }
}

// MARK: - Main View

/// Root content view for the menu bar popover.
struct AntiGravityMainView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var scanner: AudioDeviceScanner
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    @ObservedObject var menuBarIconController: MenuBarIconController
    @ObservedObject var modelCatalog: WhisperModelCatalog
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController
    @ObservedObject var benchmarkResultsStore: BenchmarkResultsStore
    @State private var expandedHistory: Bool = false
    @State private var isDroppingFile: Bool = false
    @State private var cachedWatermarkImage: NSImage? = nil
    @State private var isQuickSettingsExpanded: Bool = false

    // MenuBarExtra(.window) ignores runtime .frame(height:) changes — the window size is
    // fixed at first presentation. A single constant avoids any attempted resize that macOS
    // silently drops, which was causing the ScrollView to believe no scrolling was needed.
    // The preferred 560 is capped to the usable screen height so the window (and its
    // scrollbar) always stays on-screen on short displays, keeping every panel reachable.
    private var popoverHeight: CGFloat { PopoverSizing.cappedHeight(preferred: 560) }

    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

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

            // Large app-icon watermark behind all content — cached to avoid disk I/O on every body re-render.
            if let nsImage = cachedWatermarkImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .opacity(0.12)
                    .allowsHitTesting(false)
            }
            Text("DEXDICTATE")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(
                    settings.appearanceTheme == .minimalist
                    ? Color.black.opacity(0.12)
                    : Color.white.opacity(0.12)
                )
                .rotationEffect(.degrees(-18))
                .allowsHitTesting(false)

            // Three-region layout:
            //   1. Pinned title bar (never scrolls off)
            //   2. Scrollable body (dictation OR settings depending on state)
            //   3. Pinned status strip
            // The outer frame is a static constant — MenuBarExtra(.window) ignores runtime
            // height changes, so there is no dynamic sizing here.
            VStack(spacing: 0) {

                // ── REGION 1: PINNED TITLE ─────────────────────────────────────
                ZStack {
                    Text("DexDictate")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 6) {
                        ChromeIconButton(
                            systemName: "power",
                            accessibilityText: "Quit DexDictate"
                        ) {
                            NSApplication.shared.terminate(nil)
                        }
                        UIModeToggleButton(settings: settings)
                        Spacer()
                        ChromeIconButton(
                            systemName: "gearshape",
                            accessibilityText: "Open Settings"
                        ) {
                            onOpenSettings?()
                        }
                        .help(NSLocalizedString("Settings…", comment: ""))
                        ChromeIconButton(
                            systemName: "questionmark.circle",
                            accessibilityText: "Open Help"
                        ) {
                            onOpenHelp?()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 6)

                Divider().opacity(0.2).padding(.horizontal, 12)

                // ── REGION 2: SCROLLABLE BODY ──────────────────────────────────
                // When Quick Settings is collapsed this shows dictation content.
                // When expanded it shows only the settings panels. The two together
                // are taller than the screen, so we swap — same pattern as the
                // experimental UI's screen enum. Both regions scroll independently
                // within the fixed window.
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        if !isQuickSettingsExpanded {
                            VStack(spacing: 15) {
                                if settings.showFlavorTicker {
                                    FlavorTickerView(
                                        text: profileManager.currentFlavorLine?.text ?? "",
                                        animateWhenNeeded: settings.animateFlavorTicker
                                    )
                                }

                                if settings.showDictationStats {
                                    StatsTickerView(
                                        history: engine.history,
                                        animateWhenNeeded: settings.animateFlavorTicker
                                    )
                                }

                                PermissionBannerView(permissionManager: permissionManager)

                                HistoryView(
                                    history: engine.history,
                                    statusText: engine.statusText,
                                    liveTranscript: engine.liveTranscript,
                                    inputLevel: engine.inputLevel,
                                    isListening: engine.state == .listening || engine.state == .transcribing,
                                    expanded: $expandedHistory,
                                    onDetach: onDetachHistory,
                                    silenceCountdown: engine.silenceCountdown
                                )

                                ControlsView(
                                    engine: engine,
                                    adaptiveBenchmarkController: adaptiveBenchmarkController
                                )

                                FooterView(
                                    settings: settings,
                                    onHiddenDebugTrigger: {
                                        onRequestOnboardingDebug?()
                                    }
                                )
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)

                            Divider().opacity(0.3)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                        }

                        QuickSettingsView(
                            engine: engine,
                            settings: settings,
                            scanner: scanner,
                            profileManager: profileManager,
                            benchmarkCaptureController: benchmarkCaptureController,
                            vocabularyManager: engine.vocabularyManager,
                            menuBarIconController: menuBarIconController,
                            modelCatalog: modelCatalog,
                            adaptiveBenchmarkController: adaptiveBenchmarkController,
                            benchmarkResultsStore: benchmarkResultsStore,
                            isExpanded: $isQuickSettingsExpanded
                        )
                    }
                }

            }
        }
        .frame(width: 320, height: popoverHeight)
        .animation(.none, value: isQuickSettingsExpanded)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(isDroppingFile ? 0.8 : 0), lineWidth: 2)
                .animation(.easeInOut(duration: 0.15), value: isDroppingFile)
        )
        .sheet(item: importedFileResultBinding) { result in
            ImportedFileTranscriptionSheet(result: result) {
                MainActorAction.run {
                    engine.dismissImportedFileResult()
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDroppingFile) { providers in
            guard engine.state == .ready else { return false }
            providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    engine.transcribeAudioFile(url: url)
                }
            }
            return true
        }
        .onAppear {
            cachedWatermarkImage = loadWatermarkImage()
        }
        .onChange(of: profileManager.currentWatermarkAsset?.url) { _, _ in
            cachedWatermarkImage = loadWatermarkImage()
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

    private var importedFileResultBinding: Binding<ImportedFileTranscriptionResult?> {
        Binding(
            get: { engine.importedFileResult },
            set: { newValue in
                if newValue == nil {
                    engine.dismissImportedFileResult()
                }
            }
        )
    }
}

// MARK: - Custom Views

private struct QuickSettingsStatusStrip: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Settings Status")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 8) {
                statusPill(
                    title: "Route",
                    value: engine.routeHealthSnapshot.activeInputLabel,
                    detail: "Recoveries \(engine.routeHealthSnapshot.recoveryCount)"
                )
                statusPill(
                    title: "Latency",
                    value: latencyValue,
                    detail: latencyDetail
                )
            }

            HStack(spacing: 8) {
                statusPill(
                    title: "Model",
                    value: settings.activeWhisperModelID,
                    detail: settings.utteranceEndPreset.rawValue
                )
                statusPill(
                    title: "Retry",
                    value: settings.autoRetrySuspiciousResults ? "Smart" : "Manual",
                    detail: settings.adaptiveTailDelayEnabled ? "Adaptive tail on" : "Adaptive tail off"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var latencyValue: String {
        guard let snapshot = engine.performanceSnapshot else { return "No run yet" }
        return "\(snapshot.totalMs)ms"
    }

    private var latencyDetail: String {
        guard let snapshot = engine.performanceSnapshot else { return "Capture and transcribe timing appears here" }
        return "Cap \(snapshot.captureStopMs) · Res \(snapshot.resampleMs) · Tx \(snapshot.transcriptionMs)"
    }

    private func statusPill(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// A single segment of a custom segmented control.
struct TriggerSegment: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(isSelected ? Color.blue.opacity(0.70) : Color.clear)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.60))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A `ToggleStyle` that renders as a tappable checkbox.
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? .blue : .white.opacity(0.3))
                configuration.label
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Handles early app-lifecycle callbacks.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfDuplicateInstance() { return }
        configureApplicationIcon()

        if !AppSettings.shared.hasCompletedOnboarding {
            showOnboarding()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                LaunchIntroController.shared.playIfNeeded()
            }

            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            startEngineAtLaunch()
        }
    }

    /// Starts the engine immediately at launch so the trigger works before the
    /// user opens the menu bar popover for the first time.
    /// UI-owned objects (hudController, historyController, etc.) are wired later
    /// in .onAppear when SwiftUI has initialised them.
    private func startEngineAtLaunch() {
        let engine = TranscriptionEngine.shared
        let permissionManager = PermissionManager.shared
        let settings = AppSettings.shared
        let modelCatalog = WhisperModelCatalog.shared

        permissionManager.startMonitoring(engine: engine)
        permissionManager.refreshPermissions()
        engine.setPermissionManager(permissionManager)

        modelCatalog.refresh()
        let resolution = modelCatalog.resolveSelection(savedID: settings.activeWhisperModelID)
        if resolution.resolvedID != settings.activeWhisperModelID {
            settings.activeWhisperModelID = resolution.resolvedID
        }
        if let activeModel = modelCatalog.activeDescriptor(settings: settings) {
            engine.loadWhisperModel(descriptor: activeModel)
        }

        Task {
            if settings.persistHistory {
                let saved = await HistoryPersistenceManager.loadAsync()
                if !saved.isEmpty {
                    for item in saved { engine.history.insert(item) }
                }
            }
            await engine.startSystem()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    /// If another DexDictate instance is already running, activate it and terminate this one.
    /// Prevents the duplicate menu-bar item / popover that occurs when more than one copy of
    /// the app is launched (most commonly: two installed bundles sharing one bundle id).
    /// Returns true if this process is terminating as a duplicate.
    private func terminateIfDuplicateInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let pids = running.map { $0.processIdentifier }
        let currentPID = ProcessInfo.processInfo.processIdentifier

        guard let existingPID = InstanceGuard.existingInstancePID(allInstancePIDs: pids, currentPID: currentPID) else {
            return false
        }

        Safety.log(
            "Duplicate DexDictate instance detected (existing pid \(existingPID)); activating it and terminating this launch.",
            category: .lifecycle
        )
        running.first { $0.processIdentifier == existingPID }?.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
        return true
    }
    
    private var onboardingWindow: NSWindow?

    private func configureApplicationIcon() {
        let iconCandidates: [URL?] = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.resourceURL?.appendingPathComponent("AppIcon.icns"),
        ]

        for iconURL in iconCandidates.compactMap({ $0 }) {
            guard let icon = NSImage(contentsOf: iconURL) else { continue }
            NSApp.applicationIconImage = icon
            return
        }
    }

    private func showOnboarding() {
        // Reuse existing window if already showing
        if let existing = onboardingWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("Welcome to DexDictate", comment: "Onboarding window title")
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 480))
        let onView = OnboardingView(
            settings: AppSettings.shared,
            permissionManager: PermissionManager.shared,
            onboardingWindow: window
        )
        window.contentViewController = NSHostingController(rootView: onView)
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        onboardingWindow = window
    }

    func presentOnboardingForDebug() {
        showOnboarding()
    }
}
