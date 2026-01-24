import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @Binding var shortcut: Settings.UserShortcut
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        HStack {
            Text("Input:")
                .font(.caption).bold()
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Button(action: startRecording) {
                Text(isRecording ? "Press Key/Button..." : shortcut.displayString)
                    .font(.caption)
                    .frame(minWidth: 100)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isRecording ? Color.red.opacity(0.6) : Color.white.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }
    
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
            
            var newShortcut: Settings.UserShortcut?
            
            if event.type == .keyDown {
                newShortcut = Settings.UserShortcut(
                    keyCode: event.keyCode,
                    mouseButton: nil,
                    modifiers: UInt64(event.modifierFlags.rawValue),
                    displayString: self.keyString(for: event)
                )
            } else if event.type == .otherMouseDown || event.type == .leftMouseDown || event.type == .rightMouseDown {
                var btnString = "Mouse \(event.buttonNumber)"
                if event.buttonNumber == 2 { btnString = "Middle Mouse" }
                
                newShortcut = Settings.UserShortcut(
                    keyCode: nil,
                    mouseButton: event.buttonNumber,
                    modifiers: UInt64(event.modifierFlags.rawValue),
                    displayString: btnString
                )
            }
            
            if let sc = newShortcut {
                self.shortcut = sc
                self.stopRecording()
                return nil // Consume the event so it doesn't trigger other things
            }
            
            return event
        }
    }
    
    private func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
    
    private func keyString(for event: NSEvent) -> String {
        var str = ""
        let flags = event.modifierFlags
        if flags.contains(.command) { str += "Cmd+" }
        if flags.contains(.control) { str += "Ctrl+" }
        if flags.contains(.option) { str += "Opt+" }
        if flags.contains(.shift) { str += "Shift+" }
        
        if let chars = event.charactersIgnoringModifiers?.uppercased() {
             str += chars
        } else {
             str += "\(event.keyCode)"
        }
        return str
    }
}
