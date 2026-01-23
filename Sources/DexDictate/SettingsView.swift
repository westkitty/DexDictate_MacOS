import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Interaction")) {
                Picker("Trigger Mode", selection: $settings.triggerMode) {
                    ForEach(Settings.TriggerMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Input Button", selection: $settings.inputButton) {
                    ForEach(Settings.InputButton.allCases) { btn in
                        Text(btn.rawValue).tag(btn)
                    }
                }
                
                Toggle("Launch at Login (Requires Service)", isOn: $settings.launchAtLogin)
                    .disabled(true) // Placeholder for now
            }
            
            Section(header: Text("Feedback")) {
                Toggle("Play Start Sound", isOn: $settings.playStartSound)
                Toggle("Play Stop Sound", isOn: $settings.playStopSound)
                Toggle("Visual HUD (Overlay)", isOn: $settings.showVisualHUD)
            }
            
            Section(header: Text("Output")) {
                Toggle("Auto-Paste Text", isOn: $settings.autoPaste)
                Toggle("Filter Profanity", isOn: $settings.profanityFilter)
            }
            
            Section(header: Text("About")) {
                Text("DexDictate macOS v1.0")
                Text("Native SFSpeech Engine")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}
