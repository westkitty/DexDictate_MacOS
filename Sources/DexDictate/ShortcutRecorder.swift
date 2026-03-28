import SwiftUI
import DexDictateKit
import Carbon

/// An inline SwiftUI control for recording a custom keyboard or mouse shortcut.
///
/// Tapping the button enters *recording mode*. A local `NSEvent` monitor intercepts the
/// next key or mouse press and commits it as the new shortcut. `flagsChanged` events
/// (modifier-only presses) are ignored — a full key or click is required.
struct ShortcutRecorder: View {

    /// The shortcut being configured. Written when a new key/button is captured.
    @Binding var shortcut: AppSettings.UserShortcut
    @State private var isRecording = false

    /// Retained handle for the `NSEvent` local monitor; `nil` when not recording.
    @State private var monitor: Any?

    @State private var pendingShortcut: AppSettings.UserShortcut? = nil
    @State private var detectedConflicts: [ShortcutConflict] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(NSLocalizedString("Input:", comment: ""))
                    .font(.caption).bold()
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button(action: startRecording) {
                    Text(isRecording ? NSLocalizedString("Press Key/Button...", comment: "") : shortcut.displayString)
                        .font(.caption)
                        .frame(minWidth: 100)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(isRecording ? Color.red.opacity(0.6) : Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? "Recording shortcut" : "Shortcut recorder")
            }

            if let pending = pendingShortcut, !detectedConflicts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(NSLocalizedString("Conflict detected", comment: ""))
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.yellow)
                    }

                    ForEach(Array(detectedConflicts.enumerated()), id: \.offset) { _, conflict in
                        Text("• \(conflict.description)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button(NSLocalizedString("Use Anyway", comment: "")) {
                            shortcut = pending
                            pendingShortcut = nil
                            detectedConflicts = []
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.orange)

                        Button(NSLocalizedString("Try Again", comment: "")) {
                            pendingShortcut = nil
                            detectedConflicts = []
                            startRecording()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)

                        Button(NSLocalizedString("Keep Current", comment: "")) {
                            pendingShortcut = nil
                            detectedConflicts = []
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .onDisappear { stopRecording() }
    }
    
    /// Installs a local `NSEvent` monitor and enters recording mode.
    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        // Monitor KeyDown and MouseDown locally
        let mask: NSEvent.EventTypeMask = [.keyDown, .otherMouseDown, .leftMouseDown, .rightMouseDown, .flagsChanged]
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            // Must be on main thread
            
            // Ignore flagsChanged alone (wait for key/click)
            if event.type == .flagsChanged {
                 // We don't capture just modifiers usually, but we could dynamic update text?
                 // For now, wait for a real key/click
                 return event
            }
            
            var newShortcut: AppSettings.UserShortcut?
            
            if event.type == .keyDown {
                newShortcut = AppSettings.UserShortcut(
                    keyCode: event.keyCode,
                    mouseButton: nil,
                    modifiers: UInt64(event.modifierFlags.rawValue),
                    displayString: self.keyString(for: event)
                )
            } else if event.type == .otherMouseDown || event.type == .leftMouseDown || event.type == .rightMouseDown {
                var btnString = String(format: NSLocalizedString("Mouse %ld", comment: ""), event.buttonNumber)
                if event.buttonNumber == 0 { btnString = NSLocalizedString("Left Mouse", comment: "") }
                if event.buttonNumber == 1 { btnString = NSLocalizedString("Right Mouse", comment: "") }
                if event.buttonNumber == 2 { btnString = NSLocalizedString("Middle Mouse", comment: "") }

                newShortcut = AppSettings.UserShortcut(
                    keyCode: nil,
                    mouseButton: event.buttonNumber,
                    modifiers: UInt64(event.modifierFlags.rawValue),
                    displayString: self.modifierPrefix(for: event.modifierFlags) + btnString
                )
            }
            
            if let sc = newShortcut {
                let conflicts = ShortcutConflictDetector.conflicts(for: sc)
                if conflicts.isEmpty {
                    self.shortcut = sc
                    self.stopRecording()
                } else {
                    self.pendingShortcut = sc
                    self.detectedConflicts = conflicts
                    self.stopRecording()
                }
                return nil // Consume the event so it doesn't trigger other things
            }
            
            return event
        }
    }
    
    /// Removes the `NSEvent` monitor and exits recording mode.
    private func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
    
    /// Builds a human-readable label for a keyboard event (e.g. "Cmd+Shift+K").
    ///
    /// Falls back to the raw key code string when `charactersIgnoringModifiers` is
    /// unavailable (e.g. for function keys that produce no printable character).
    private func keyString(for event: NSEvent) -> String {
        var str = modifierPrefix(for: event.modifierFlags)
        
        if let chars = event.charactersIgnoringModifiers?.uppercased() {
             str += chars
        } else {
             str += "\(event.keyCode)"
        }
        return str
    }

    private func modifierPrefix(for flags: NSEvent.ModifierFlags) -> String {
        var str = ""
        if flags.contains(.command) { str += "Cmd+" }
        if flags.contains(.control) { str += "Ctrl+" }
        if flags.contains(.option) { str += "Opt+" }
        if flags.contains(.shift) { str += "Shift+" }
        return str
    }
}
