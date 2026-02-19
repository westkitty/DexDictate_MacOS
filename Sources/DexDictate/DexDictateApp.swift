import SwiftUI
import AVFoundation
import DexDictateKit

/// Application entry point. Configures the `MenuBarExtra` scene and wires together
/// `TranscriptionEngine`, `PermissionManager`, and `Settings`.
@main
struct DexDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Use shared engine to ensure Intents modify the same instance
    @StateObject private var engine = TranscriptionEngine.shared
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var scanner = AudioDeviceScanner()
    @ObservedObject var settings = AppSettings.shared
    
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
                onDetachHistory: {
                    historyController.show()
                }
            )
            .onAppear {
                // .onAppear fires every time the MenuBarExtra popover is opened.
                // Guard here so one-time setup (model load, engine start) only runs once.
                // Everything after the guard can fire on every open safely.
                permissionManager.startMonitoring(engine: engine)
                permissionManager.refreshPermissions()

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
                if !engine.isModelLoaded {
                    engine.loadEmbeddedWhisperModel()
                }

                // Auto-start: sets up event tap + moves engine to .ready state.
                Task {
                    await engine.startSystem()
                }

                // Configure HUD and History controllers (idempotent but guard anyway).
                hudController.setup(engine: engine)
                historyController.setup(engine: engine)

                if settings.showFloatingHUD {
                    hudController.show()
                }
            }
            .onChange(of: settings.showFloatingHUD) { _, newValue in
                hudController.toggle(shouldShow: newValue)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: engine.state == .listening ? "waveform.circle.fill" : "mic.fill")
                    .foregroundStyle(engine.state == .listening ? .red : .primary)
                if engine.state == .listening {
                    Text("Recording")
                        .foregroundStyle(.red)
                } else {
                    Text("DexDictate")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Main View

/// Root content view for the menu bar popover.
struct AntiGravityMainView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var scanner: AudioDeviceScanner
    @State private var expandedHistory: Bool = false
    
    var onDetachHistory: (() -> Void)?

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
            if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
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

                    PermissionBannerView(permissionManager: permissionManager)

                    HistoryView(
                        history: engine.history,
                        statusText: engine.statusText,
                        liveTranscript: engine.liveTranscript,
                        inputLevel: engine.inputLevel,
                        isListening: engine.state == .listening || engine.state == .transcribing,
                        expanded: $expandedHistory,
                        onDetach: onDetachHistory
                    )

                    ControlsView(engine: engine)

                    QuickSettingsView(
                        settings: settings, 
                        scanner: scanner,
                        vocabularyManager: engine.vocabularyManager
                    )

                    Spacer(minLength: 0)

                    FooterView(settings: settings)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 320, height: 540)
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
        if !AppSettings.shared.hasCompletedOnboarding {
             showOnboarding()
        } else {
             AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }
    
    private var onboardingWindow: NSWindow?

    private func showOnboarding() {
        // Reuse existing window if already showing
        if let existing = onboardingWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow()
        window.title = NSLocalizedString("Welcome to DexDictate", comment: "Onboarding window title")
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        let onView = OnboardingView(settings: AppSettings.shared, onboardingWindow: window)
        window.contentViewController = NSHostingController(rootView: onView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        onboardingWindow = window
    }
}
