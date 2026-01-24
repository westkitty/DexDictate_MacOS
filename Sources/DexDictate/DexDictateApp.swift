import SwiftUI
import AVFoundation
import Speech

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
struct AntiGravityMainView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: Settings
    @State private var expandedHistory: Bool = false
    
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
                    // INJECTION: REMOVE GREEN GEAR
                    // Button(action: { /* Open full settings window if needed */ }) {
                    //    Image(systemName: "gearshape.fill")
                    //        .font(.system(size: 18))
                    //        .foregroundStyle(.white.opacity(0.6))
                    // }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Permission Status Banner
                if !permissionManager.allPermissionsGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(permissionManager.permissionsSummary)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .font(.caption2)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Upper Middle: Expandable History Feed
                VStack(spacing: 5) {
                    HStack {
                        Text("Transcription History")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Button(action: { withAnimation { expandedHistory.toggle() } }) {
                            Image(systemName: expandedHistory ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if engine.history.isEmpty {
                                Text(engine.statusText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(4)
                            } else {
                                ForEach(Array(engine.history.enumerated()), id: \.offset) { index, text in
                                    HStack(alignment: .top) {
                                        Text(text)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(text, forType: .string)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(6)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: expandedHistory ? 300 : 100) // Expansion Logic
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

                    // Input Status Text Removed (Replaced by Quick Settings)
                    
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
                            // INJECTION: Sound Picker UI
                            VStack(alignment: .leading, spacing: 12) {
                                // 1. Feedback Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Feedback (Sound Effects)").font(.caption).bold().foregroundStyle(.white.opacity(0.7))
                                    
                                    HStack {
                                        Text("Play Start:")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                        Spacer()
                                        Picker("", selection: $settings.selectedStartSound) {
                                            ForEach(Settings.SystemSound.allCases) { sound in
                                                Text(sound.rawValue).tag(sound)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 120)
                                        .fixedSize()
                                        .onChange(of: settings.selectedStartSound) { newValue in
                                            engine.playSound(newValue)
                                        }
                                    }
                                    
                                    HStack {
                                        Text("Play Stop:")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                        Spacer()
                                        Picker("", selection: $settings.selectedStopSound) {
                                            ForEach(Settings.SystemSound.allCases) { sound in
                                                Text(sound.rawValue).tag(sound)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 120)
                                        .fixedSize()
                                        .onChange(of: settings.selectedStopSound) { newValue in
                                            engine.playSound(newValue)
                                        }
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.3))
                                
                                // 2. Output Section (Stacked Below)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Output").font(.caption).bold().foregroundStyle(.white.opacity(0.7))
                                    
                                    Toggle("Auto-Paste", isOn: $settings.autoPaste)
                                    Text("Automatically pastes text into the active app.")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.leading, 20) // Indent to align with toggle text
                                        .padding(.bottom, 2)
                                        
                                    Toggle("Filter Profanity", isOn: $settings.profanityFilter)
                                }
                                
                                Divider().background(Color.white.opacity(0.3))
                                
                                // 3. Input Configuration
                                ShortcutRecorder(shortcut: $settings.userShortcut)
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
                VStack(spacing: 6) {
                    Button(action: { settings.restoreDefaults() }) {
                        Text("Restore Defaults")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { NSWorkspace.shared.open(URL(string: "https://github.com/WestKitty/DexDictate_MacOS")!) }) {
                        Text("About")
                            .font(.caption2)
                            .underline()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Text("DexDictate macOS v1.0")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                        .fixedSize()
                        .padding(.bottom, 10)
                }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 320, height: 540)
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
