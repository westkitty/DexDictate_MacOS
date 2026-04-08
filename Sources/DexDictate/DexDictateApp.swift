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
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var menuBarIconController = MenuBarIconController.shared
    @StateObject private var modelCatalog = WhisperModelCatalog.shared
    @StateObject private var adaptiveBenchmarkController = AdaptiveBenchmarkController()
    @StateObject private var benchmarkResultsStore = BenchmarkResultsStore.shared
    
    // HUD Controller
    @StateObject private var hudController = FloatingHUDController()
    // History Controller
    @StateObject private var historyController = HistoryWindowController()

    init() {
        Safety.setupDirectories()
    }

    var body: some Scene {
        MenuBarExtra {
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
                    historyController.show()
                },
                onRequestOnboardingDebug: {
                    appDelegate.presentOnboardingForDebug()
                }
            )
            .onAppear {
                // .onAppear fires every time the MenuBarExtra popover is opened.
                // Guard here so one-time setup (model load, engine start) only runs once.
                // Everything after the guard can fire on every open safely.
                permissionManager.startMonitoring(engine: engine)
                permissionManager.refreshPermissions()
                profileManager.synchronizeBundledVocabulary(with: engine.vocabularyManager)
                profileManager.refreshDynamicContent()
                ExperimentFlags.applyRuntimeSettings(settings)
                modelCatalog.refresh()

                if modelCatalog.descriptor(for: settings.activeWhisperModelID) == nil {
                    settings.activeWhisperModelID = "tiny.en"
                }

                guard engine.state == .stopped else {
                    // Engine already running — just refresh permissions on each open.
                    return
                }

                permissionManager.requestPermissions()
                permissionManager.requestMicrophoneIfNeeded()
                engine.setPermissionManager(permissionManager)

                // Load embedded Whisper model (74 MB, only load once).
                // Guard against reloading if model is already loaded (e.g. stopSystem() was
                // called which sets state=.stopped but the model remains loaded).
                if let activeModel = modelCatalog.activeDescriptor(settings: settings) {
                    engine.loadWhisperModel(descriptor: activeModel)
                }

                // Load persisted history if opt-in is enabled.
                if settings.persistHistory {
                    let saved = HistoryPersistenceManager.load()
                    if !saved.isEmpty {
                        Task { @MainActor in
                            for item in saved {
                                engine.history.insert(item)
                            }
                        }
                    }
                }

                // Auto-start: sets up event tap + moves engine to .ready state.
                Task {
                    await engine.startSystem()
                }

                // Configure HUD and History controllers (idempotent but guard anyway).
                hudController.setup(engine: engine, profileManager: profileManager)
                historyController.setup(engine: engine, vocabularyManager: engine.vocabularyManager)
                adaptiveBenchmarkController.start(engine: engine)

                if settings.showFloatingHUD {
                    hudController.show()
                }
            }
            .onChange(of: settings.showFloatingHUD) { _, newValue in
                hudController.toggle(shouldShow: newValue)
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
            .onReceive(engine.history.$items) { items in
                if settings.persistHistory {
                    HistoryPersistenceManager.save(items)
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

    var onDetachHistory: (() -> Void)?
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

            // Large app-icon watermark behind all content (visible on every theme).
            if let assetURL = profileManager.currentWatermarkAsset?.url,
               let nsImage = NSImage(contentsOf: assetURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .opacity(0.12)
                    .allowsHitTesting(false)
            } else if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
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

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 15) {
                    // App title (logo is the large watermark behind the entire UI)
                    Text("DexDictate")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.top, 4)

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
                        benchmarkResultsStore: benchmarkResultsStore
                    )

                    Spacer(minLength: 0)

                    FooterView(
                        settings: settings,
                        onHiddenDebugTrigger: {
                            onRequestOnboardingDebug?()
                        }
                    )
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 320, height: 540)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(isDroppingFile ? 0.8 : 0), lineWidth: 2)
                .animation(.easeInOut(duration: 0.15), value: isDroppingFile)
        )
        .sheet(item: importedFileResultBinding) { result in
            ImportedFileTranscriptionSheet(result: result) {
                engine.dismissImportedFileResult()
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

/// A single segment of a custom segmented control.
struct TriggerSegment: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption).fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.6) : Color.clear)
                .foregroundStyle(.white)
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
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationIcon()

        if !AppSettings.shared.hasCompletedOnboarding {
            showOnboarding()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                LaunchIntroController.shared.playIfNeeded()
            }

            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
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
