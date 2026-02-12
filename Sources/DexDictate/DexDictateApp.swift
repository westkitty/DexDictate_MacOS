import SwiftUI
import AVFoundation
import Speech

/// Application entry point. Configures the `MenuBarExtra` scene and wires together
/// `TranscriptionEngine`, `PermissionManager`, and `Settings`.
@main
struct DexDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = TranscriptionEngine()
    @StateObject private var permissionManager = PermissionManager()
    @ObservedObject var settings = Settings.shared

    init() {
        Safety.setupDirectories()
    }

    var body: some Scene {
        MenuBarExtra {
            AntiGravityMainView(
                engine: engine,
                permissionManager: permissionManager,
                settings: settings
            )
            .onAppear {
                permissionManager.startMonitoring(engine: engine)
                permissionManager.refreshPermissions()
                permissionManager.requestPermissions()
                engine.setPermissionManager(permissionManager)
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
///
/// Composes all sub-views in a fixed 320×540 pt frosted-glass window. The decorative
/// dog silhouette is rendered with `.blendMode(.screen)` at low opacity so it never
/// obscures interactive elements.
struct AntiGravityMainView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: Settings
    @State private var expandedHistory: Bool = false

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            Image("dog_background", bundle: Bundle.main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(20)
                .blendMode(.screen)
                .opacity(0.2)
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 15) {
                    PermissionBannerView(permissionManager: permissionManager)

                    HistoryView(
                        history: engine.history,
                        statusText: engine.statusText,
                        liveTranscript: engine.liveTranscript,
                        inputLevel: engine.inputLevel,
                        isListening: engine.state == .listening || engine.state == .transcribing,
                        expanded: $expandedHistory
                    )

                    ControlsView(engine: engine)

                    QuickSettingsView(settings: settings)

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

/// A single segment of a custom segmented control, used for trigger-mode selection.
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

/// A `ToggleStyle` that renders as a tappable checkbox icon with a caption-sized label.
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

/// Handles early app-lifecycle callbacks that are not available in the SwiftUI `App` protocol.
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Triggers the microphone, speech recognition, and accessibility permission prompts at
    /// launch so the user sees them before attempting to start dictation.
    func applicationDidFinishLaunching(_ notification: Notification) {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        if #available(macOS 10.15, *) {
            CGRequestListenEventAccess()
        }
    }
}
