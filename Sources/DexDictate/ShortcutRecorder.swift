import SwiftUI
import DexDictateKit
import Carbon

/// An inline SwiftUI control for recording a custom keyboard or mouse shortcut.
///
/// Tapping the button enters *recording mode*. A local `NSEvent` monitor intercepts the
/// next key or mouse press and commits it as the new shortcut. `flagsChanged` events
/// (modifier-only presses) are ignored — a full key or click is required.
struct ShortcutRecorder: View {

    /// Owner of the trigger shortcut. Captured shortcuts are applied through
    /// `AppSettings.applyTriggerShortcut(_:)` rather than written directly, so every recorder
    /// surface in the app shares one validation path and a trigger that shadows the fixed
    /// Undo Last Dictation chord (⌃⌥⌘Z) can never be persisted silently.
    @ObservedObject var settings: AppSettings
    @State private var isRecording = false
    /// Conflict copy from the last capture attempt; `nil` when the last capture was clean.
    @State private var conflictMessage: String?
    @State private var conflictWasRejected = false

    /// Retained handle for the `NSEvent` local monitor; `nil` when not recording.
    @State private var monitor: Any?

    private var shortcut: AppSettings.UserShortcut { settings.userShortcut }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            if let conflictMessage {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: conflictWasRejected
                          ? "exclamationmark.octagon.fill"
                          : "exclamationmark.triangle.fill")
                    Text(conflictMessage)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption2)
                .foregroundStyle(conflictWasRejected ? .red : .orange)
                .accessibilityLabel(
                    conflictWasRejected
                    ? "Shortcut not saved. \(conflictMessage)"
                    : "Shortcut warning. \(conflictMessage)"
                )
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

            // Escape cancels recording instead of being captured as the shortcut itself —
            // this is the only way to back out once recording starts. Without it, any click
            // anywhere else in the same window (e.g. a "Back"/"Next" button during onboarding,
            // or a different Settings tab) was silently consumed and reassigned as the new
            // shortcut instead of performing its own action, with no way to escape that.
            if event.type == .keyDown, event.keyCode == 53 {
                self.stopRecording()
                return nil
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
                self.apply(sc)
                self.stopRecording()
                return nil // Consume the event so it doesn't trigger other things
            }
            
            return event
        }
    }
    
    /// Routes a captured shortcut through the shared validation path and surfaces whatever
    /// it reports. A rejected shortcut is never written, so the previous trigger stays live.
    private func apply(_ candidate: AppSettings.UserShortcut) {
        let outcome = settings.applyTriggerShortcut(candidate)
        conflictWasRejected = !outcome.didApply
        conflictMessage = outcome.conflict?.message
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
