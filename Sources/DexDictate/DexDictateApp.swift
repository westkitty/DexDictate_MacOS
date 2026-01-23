import SwiftUI
import AVFoundation
import Speech

@main
struct DexDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = TranscriptionEngine()
    
    // Permission State
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var speechAuth = SFSpeechRecognizer.authorizationStatus()
    
    // Settings (Shared)
    @ObservedObject var settings = Settings.shared
    
    init() { 
        Safety.setupDirectories() 
    }

    var body: some Scene {
        MenuBarExtra {
            AntiGravityMainView(engine: engine, axTrusted: $axTrusted, speechAuth: $speechAuth, settings: settings)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: engine.state == .listening ? "waveform.circle.fill" : "mic.fill")
                    .foregroundStyle(engine.state == .listening ? .red : .primary)
                if engine.state == .listening {
                    Text("Listening")
                } else {
                    Text("DexDictate")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Main View
struct AntiGravityMainView: View {
    @ObservedObject var engine: TranscriptionEngine
    @Binding var axTrusted: Bool
    @Binding var speechAuth: SFSpeechRecognizerAuthorizationStatus
    @ObservedObject var settings: Settings
    
    var body: some View {
        ZStack {
            // 2. Main Window & Background Constraint
            Color.clear
                .background(.ultraThinMaterial) // Translucency
                .ignoresSafeArea()
            
            // Logo Background (Blue Glow Mask Attempt)
            Image("dog_background", bundle: Bundle.main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(20)
                .blendMode(.screen) // Makes black transparent, colors glowing
                .opacity(0.2) // Low transparency for readability
                .allowsHitTesting(false)
            
            VStack(spacing: 15) {
                // Top Right: Gear Icon
                HStack {
                    Spacer()
                    Button(action: { /* Open full settings window if needed */ }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Upper Middle: Status Feed
                VStack(spacing: 5) {
                    Text("Status Feed")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.statusText)
                        Text(engine.debugLog).font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal)
                
                // Middle Section: Controls
                VStack(spacing: 12) {
                    
                    // MAIN ACTIONS (Start/Stop) - Restored
                    if engine.state == .stopped {
                        Button(action: { Task { await engine.startSystem() } }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Start Dictation")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.4)) // More opaque
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                            .shadow(color: .green.opacity(0.3), radius: 5)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { engine.stopSystem() }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Dictation")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.5)) // More opaque
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: .red.opacity(0.3), radius: 5)
                        }
                        .buttonStyle(.plain)
                    }

                    // Input Button (Visual Only for now)
                    HStack {
                        Text("Input: \(Settings.shared.inputButton.rawValue)")
                            .font(.caption).bold()
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // Quit Button (Restored)
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Text("Quit App")
                            .font(.subheadline).fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4)) // More opaque
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Lower Section: Settings Toggles (Reduced Prominence)
                DisclosureGroup("Quick Settings") {
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Feedback").font(.caption).bold().foregroundStyle(.white.opacity(0.7))
                                Toggle("Play Start", isOn: $settings.playStartSound)
                                Toggle("Play Stop", isOn: $settings.playStopSound)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Output").font(.caption).bold().foregroundStyle(.white.opacity(0.7))
                                Toggle("Auto-Paste", isOn: $settings.autoPaste)
                                Toggle("Filter Profanity", isOn: $settings.profanityFilter)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                .accentColor(.white)
                .padding(.horizontal)

                
                Spacer()
                
                // Footer
                VStack(spacing: 2) {
                    Text("About").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    Text("DexDictate macOS v1.0").font(.caption2).foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 320, height: 480)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if !axTrusted { axTrusted = AXIsProcessTrusted() }
        }
    }
}

// MARK: - Custom Views

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

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
