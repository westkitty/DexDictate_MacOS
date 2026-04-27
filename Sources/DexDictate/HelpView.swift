import SwiftUI
import DexDictateKit

// MARK: - Section Model

/// All sections shown in the Help sidebar.
enum HelpSection: String, CaseIterable, Identifiable, Hashable {
    case welcome
    case gettingStarted
    case permissions
    case triggerSetup
    case recordingAudio
    case transcription
    case outputPasting
    case history
    case vocabulary
    case voiceCommands
    case profiles
    case appearance
    case floatingHUD
    case safeMode
    case benchmarking
    case shortcuts
    case diagnostics
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .welcome:        return "Welcome"
        case .gettingStarted: return "Getting Started"
        case .permissions:    return "Permissions"
        case .triggerSetup:   return "Trigger Setup"
        case .recordingAudio: return "Recording & Audio"
        case .transcription:  return "Transcription"
        case .outputPasting:  return "Output & Pasting"
        case .history:        return "Transcription History"
        case .vocabulary:     return "Custom Vocabulary"
        case .voiceCommands:  return "Voice Commands"
        case .profiles:       return "Profiles"
        case .appearance:     return "Appearance & Menu Bar"
        case .floatingHUD:    return "Floating HUD"
        case .safeMode:       return "Safe Mode"
        case .benchmarking:   return "Benchmarking & Models"
        case .shortcuts:      return "Shortcuts & Siri"
        case .diagnostics:    return "Diagnostics"
        case .about:          return "About"
        }
    }

    var icon: String {
        switch self {
        case .welcome:        return "hand.wave"
        case .gettingStarted: return "flag.checkered"
        case .permissions:    return "lock.shield"
        case .triggerSetup:   return "keyboard"
        case .recordingAudio: return "waveform"
        case .transcription:  return "text.bubble"
        case .outputPasting:  return "doc.on.clipboard"
        case .history:        return "clock.arrow.circlepath"
        case .vocabulary:     return "book.closed"
        case .voiceCommands:  return "mic.badge.plus"
        case .profiles:       return "person.2"
        case .appearance:     return "paintbrush"
        case .floatingHUD:    return "rectangle.on.rectangle"
        case .safeMode:       return "shield.lefthalf.filled"
        case .benchmarking:   return "chart.bar"
        case .shortcuts:      return "sparkles"
        case .diagnostics:    return "stethoscope"
        case .about:          return "info.circle"
        }
    }

    /// Keywords used for search matching beyond the section title.
    var searchAliases: [String] {
        switch self {
        case .welcome:        return ["what is", "intro", "overview", "start", "dexdictate"]
        case .gettingStarted: return ["setup", "first run", "onboarding", "begin", "new"]
        case .permissions:    return ["accessibility", "input monitoring", "microphone", "privacy", "permission denied", "not working"]
        case .triggerSetup:   return ["shortcut", "hotkey", "button", "hold", "toggle", "middle mouse", "key", "bind"]
        case .recordingAudio: return ["mic", "microphone", "input", "audio", "record", "silence", "timeout", "device", "file import", "zoom", "audio route", "route change", "device switch"]
        case .transcription:  return ["whisper", "model", "accuracy", "local", "offline", "wer", "utterance", "preset", "retry"]
        case .outputPasting:  return ["paste", "copy", "insert", "secure", "password", "auto-paste", "clipboard", "per app", "profanity", "zoom", "zoom chat", "electron", "not pasting", "no text", "wrong app"]
        case .history:        return ["history", "log", "export", "search", "detach", "previous", "transcript", "save"]
        case .vocabulary:     return ["words", "replacements", "vocabulary", "correction", "learn", "custom", "phrase"]
        case .voiceCommands:  return ["scratch that", "dex", "new line", "all caps", "commands", "voice", "command"]
        case .profiles:       return ["canadian", "aussie", "standard", "flavor", "watermark", "ticker", "region", "locale"]
        case .appearance:     return ["theme", "icon", "emoji", "minimalist", "cyberpunk", "menu bar", "color", "dark", "style"]
        case .floatingHUD:    return ["hud", "floating", "panel", "overlay", "status", "window", "indicator"]
        case .safeMode:       return ["safe", "defaults", "restore", "low risk", "conservative", "troubleshoot"]
        case .benchmarking:   return ["benchmark", "wer", "latency", "model", "tiny.en", "accuracy", "corpus", "promote", "auto"]
        case .shortcuts:      return ["siri", "shortcuts", "app intents", "automation", "voice control"]
        case .diagnostics:    return ["logs", "debug", "troubleshoot", "not working", "error", "crash", "broken", "fix", "zoom", "zoom call", "electron", "coreaudiod", "-10868", "core audio", "audio stuck", "microphone blocked", "capability"]
        case .about:          return ["version", "github", "credits", "license", "source"]
        }
    }

    /// Sections to list as "Related" at the bottom of content.
    var relatedSections: [HelpSection] {
        switch self {
        case .welcome:        return [.gettingStarted, .triggerSetup, .outputPasting]
        case .gettingStarted: return [.permissions, .triggerSetup]
        case .permissions:    return [.gettingStarted, .diagnostics]
        case .triggerSetup:   return [.recordingAudio, .gettingStarted]
        case .recordingAudio: return [.triggerSetup, .transcription, .history]
        case .transcription:  return [.benchmarking, .recordingAudio, .outputPasting]
        case .outputPasting:  return [.history, .transcription, .safeMode]
        case .history:        return [.vocabulary, .outputPasting]
        case .vocabulary:     return [.voiceCommands, .transcription, .profiles]
        case .voiceCommands:  return [.vocabulary, .triggerSetup, .recordingAudio]
        case .profiles:       return [.appearance, .vocabulary]
        case .appearance:     return [.profiles, .floatingHUD]
        case .floatingHUD:    return [.appearance, .recordingAudio]
        case .safeMode:       return [.diagnostics, .outputPasting]
        case .benchmarking:   return [.transcription, .diagnostics]
        case .shortcuts:      return [.triggerSetup, .gettingStarted]
        case .diagnostics:    return [.permissions, .safeMode, .outputPasting]
        case .about:          return [.gettingStarted, .diagnostics]
        }
    }

    func matches(_ query: String) -> Bool {
        let q = query.localizedLowercase
        if title.localizedLowercase.contains(q) { return true }
        return searchAliases.contains { $0.localizedLowercase.contains(q) }
    }
}

// MARK: - Root Help View

struct HelpView: View {
    @State private var selectedSection: HelpSection? = .welcome
    @State private var searchText = ""

    private var searchResults: [HelpSection] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return HelpSection.allCases
        }
        return HelpSection.allCases.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search help…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Section list
                List(searchResults, selection: $selectedSection) { section in
                    Label(section.title, systemImage: section.icon)
                        .font(.callout)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .onChange(of: searchText) { _, _ in
                    if let first = searchResults.first {
                        selectedSection = first
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.88), Color(red: 0.11, green: 0.12, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } detail: {
            ScrollView {
                if let section = selectedSection {
                    HelpContentView(section: section) { target in
                        withAnimation { selectedSection = target }
                    }
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Select a topic from the sidebar.")
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.88), Color(red: 0.11, green: 0.12, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

// MARK: - Content View

struct HelpContentView: View {
    let section: HelpSection
    var onNavigate: (HelpSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text(section.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Section body
            sectionBody

            // Related sections
            if !section.relatedSections.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Related")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(section.relatedSections) { related in
                            HelpNavButton(section: related, action: { onNavigate(related) })
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
        case .welcome:        WelcomeContent()
        case .gettingStarted: GettingStartedContent()
        case .permissions:    PermissionsContent()
        case .triggerSetup:   TriggerSetupContent()
        case .recordingAudio: RecordingAudioContent()
        case .transcription:  TranscriptionContent()
        case .outputPasting:  OutputPastingContent()
        case .history:        HistoryContent()
        case .vocabulary:     VocabularyContent()
        case .voiceCommands:  VoiceCommandsContent()
        case .profiles:       ProfilesContent()
        case .appearance:     AppearanceContent()
        case .floatingHUD:    FloatingHUDContent()
        case .safeMode:       SafeModeContent()
        case .benchmarking:   BenchmarkingContent()
        case .shortcuts:      ShortcutsContent()
        case .diagnostics:    DiagnosticsContent()
        case .about:          AboutContent()
        }
    }
}

// MARK: - Animated Related Nav Button

private struct HelpNavButton: View {
    let section: HelpSection
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(section.title, systemImage: section.icon)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHovered ? Color.cyan.opacity(0.18) : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(isHovered ? .cyan : Color.cyan.opacity(0.8))
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared Helpers

private func helpBody(_ text: String) -> some View {
    Text(text)
        .font(.callout)
        .foregroundStyle(.white.opacity(0.88))
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(3)
}

private func helpHeading(_ text: String) -> some View {
    Text(text)
        .font(.callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.top, 4)
}

private func helpCallout(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Image(systemName: "lightbulb")
            .font(.caption)
            .foregroundStyle(.yellow)
            .padding(.top, 1)
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(Color.yellow.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}

private func helpWarning(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.top, 1)
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(Color.orange.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}

private struct HelpRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
    }
}

/// Loads a screenshot from the Help assets folder. Shows a styled placeholder when the
/// PNG isn't present yet so the view compiles and displays cleanly before screenshots
/// are captured.
private struct HelpScreenshot: View {
    let name: String
    let caption: String

    init(_ name: String, caption: String = "") {
        self.name = name
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = Safety.resourceBundle.url(
                forResource: "Assets.xcassets/Help/\(name)",
                withExtension: "png"
            ), let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            } else {
                // Placeholder while screenshot hasn't been captured yet
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.20))
                            Text(name)
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.20))
                        }
                    )
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
    }
}

/// Large SF Symbol rendered at very low opacity as a section background watermark.
private struct SectionWatermark: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 130, weight: .ultraLight))
            .foregroundStyle(.white.opacity(0.05))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

// MARK: - Section Content Views

// ─────────────────────────────────────────────────────────────────────────────
// WELCOME
// ─────────────────────────────────────────────────────────────────────────────

private struct WelcomeContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "hand.wave")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("DexDictate lives in your menu bar and converts speech to text using a local Whisper AI model. No internet connection is required — your audio never leaves your Mac.")
                helpBody("Press your configured trigger to start speaking. DexDictate transcribes what you say and types it into whatever app is in focus.")
                helpHeading("Key ideas")
                VStack(alignment: .leading, spacing: 6) {
                    Label("Runs entirely on your Mac — Apple Silicon optimized", systemImage: "cpu")
                    Label("Works in any app: code editors, documents, chat, terminals", systemImage: "rectangle.on.rectangle")
                    Label("Hold your trigger to talk, release to transcribe", systemImage: "hand.raised")
                    Label("Every transcription is saved in-session for review", systemImage: "clock.arrow.circlepath")
                }
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                HelpScreenshot("help-welcome-overview",
                               caption: "The main DexDictate popover in idle state.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// GETTING STARTED
// ─────────────────────────────────────────────────────────────────────────────

private struct GettingStartedContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpHeading("First launch")
            helpBody("The onboarding flow guides you through three required permissions:")
            VStack(alignment: .leading, spacing: 8) {
                Label("Accessibility — lets DexDictate detect your trigger key/button", systemImage: "1.circle.fill")
                Label("Input Monitoring — lets DexDictate listen for your trigger globally", systemImage: "2.circle.fill")
                Label("Microphone — macOS will ask on your first dictation", systemImage: "3.circle.fill")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.85))
            HelpScreenshot("help-onboarding-permissions",
                           caption: "The onboarding permissions page.")
            helpHeading("After onboarding")
            helpBody("Click the DexDictate icon in your menu bar → hold your trigger → speak → release to transcribe. Text appears in your active app.")
            helpCallout("Tap the version string in the footer five times to reopen the onboarding screen at any time.")
            HelpScreenshot("help-onboarding-shortcut",
                           caption: "Setting a custom trigger shortcut in onboarding.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERMISSIONS
// ─────────────────────────────────────────────────────────────────────────────

private struct PermissionsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpBody("DexDictate requires three macOS permissions. All are standard and can be revoked any time in System Settings → Privacy & Security.")
            helpHeading("Accessibility")
            helpBody("Detects your trigger key or button press system-wide.\n\nGrant at: System Settings → Privacy & Security → Accessibility → DexDictate\n\nIf missing: trigger won't fire; warning banner appears in DexDictate.")
            helpHeading("Input Monitoring")
            helpBody("Reads keyboard and mouse button events globally.\n\nGrant at: System Settings → Privacy & Security → Input Monitoring → DexDictate\n\nIf missing: same symptom as missing Accessibility — trigger doesn't fire.")
            helpHeading("Microphone")
            helpBody("Records your voice. macOS prompts automatically on first dictation.\n\nGrant at: System Settings → Privacy & Security → Microphone → DexDictate\n\nIf missing: recording starts but captures silence.")
            HelpScreenshot("help-permissions-banner",
                           caption: "The permission warning banner inside DexDictate.")
            helpHeading("Troubleshooting")
            helpBody("If the banner persists after granting permissions:\n1. Fully quit DexDictate (right-click menu bar icon → Quit)\n2. Reopen DexDictate\n3. If still missing: remove DexDictate from the permission list, re-add it, then relaunch")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER SETUP
// ─────────────────────────────────────────────────────────────────────────────

private struct TriggerSetupContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpBody("The trigger is the key or button you hold (or click) to start and stop dictation. It fires globally — even when another app is in focus.")
            helpCallout("Default trigger: Middle mouse button")
            helpHeading("Changing your trigger")
            helpBody("Open the popover → expand Quick Settings → scroll to the Input section → click the shortcut recorder field → press your desired key or button combination.")
            helpBody("Supported triggers: any keyboard key (with optional Cmd/Shift/Ctrl/Option modifiers), mouse buttons (middle, back, forward), or combinations.")
            helpHeading("Hold to Talk (default)")
            helpBody("Hold trigger → recording starts. Release → recording stops, transcription begins immediately. Best for short utterances.")
            helpHeading("Click to Toggle")
            helpBody("Press once to start. Press again to stop. Better for long-form dictation where holding is tiring.")
            helpBody("Switch mode: Quick Settings → Input → Trigger Mode (segmented control: Hold / Toggle).")
            HelpScreenshot("help-trigger-settings",
                           caption: "The Input section of Quick Settings showing Trigger Mode and shortcut recorder.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECORDING & AUDIO
// ─────────────────────────────────────────────────────────────────────────────

private struct RecordingAudioContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpHeading("Microphone selection")
            helpBody("Quick Settings → Input → Input Device.\n\nShows all audio input devices macOS detects: built-in mic, USB mics, Bluetooth headsets, audio interfaces.")
            helpHeading("Silence timeout")
            helpBody("Auto-stops recording after N seconds of silence, even if you haven't released the trigger.\n\nEnable: Quick Settings → Input → Silence Timeout → drag the slider (0 = Disabled).\n\nA countdown appears in the history panel: \"Auto-stopping in Xs…\"")
            helpHeading("File import")
            helpBody("Drag and drop an audio file onto the DexDictate popover to transcribe it. Supported: WAV, MP3, M4A, and other formats supported by macOS AVFoundation.")
            helpHeading("Live preview")
            helpBody("While recording, a partial transcription appears in the history panel with a green \"Live\" label and a mic level bar. The final result may differ slightly.")
            HelpScreenshot("help-recording-active",
                           caption: "The popover during active dictation — Mic Active badge, live preview, and mic level bar.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSCRIPTION
// ─────────────────────────────────────────────────────────────────────────────

private struct TranscriptionContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "text.bubble")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("DexDictate uses OpenAI's Whisper model running entirely on your Mac. No audio or text is sent to any server.")
                helpHeading("Bundled model: tiny.en")
                helpBody("A compact English-only model that balances speed and accuracy on Apple Silicon. Loaded automatically on first launch.")
                helpHeading("Active model & selection")
                helpBody("Quick Settings → Benchmark → Optimization → Active Model.\n\nThe Model Selection picker below it controls whether DexDictate manages the model automatically (Auto Idle Benchmark) or lets you pick manually.")
                helpHeading("End Preset")
                helpBody("Controls how aggressively DexDictate trims silence at the end of a recording. Found at: Quick Settings → Benchmark → Optimization → End Preset.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Stable", value: "Conservative; least likely to clip sentence endings")
                    HelpRow(key: "Fast", value: "More aggressive; may clip very last words")
                    HelpRow(key: "Conservative", value: "Generous; waits longer before closing")
                }
                helpHeading("Accuracy Retry (opt-in)")
                helpBody("Found at: Quick Settings → Benchmark → Optimization → Accuracy Retry toggle.\n\nWhen on, DexDictate re-transcribes at higher accuracy if confidence is low. Items retried this way are tagged \"Accuracy retry\" in history.")
                helpWarning("Accuracy depends on microphone quality and background noise. Very short phrases (under ~1 second) may not transcribe reliably. Non-English speech will produce unpredictable results with the default tiny.en model.")
                HelpScreenshot("help-transcription-model",
                               caption: "The Benchmark Optimization section showing model and preset controls.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTPUT & PASTING
// ─────────────────────────────────────────────────────────────────────────────

private struct OutputPastingContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpBody("DexDictate picks the best delivery method based on your settings and the focused app:")
            VStack(alignment: .leading, spacing: 4) {
                HelpRow(key: "Auto-paste (default)", value: "Copies to clipboard, then simulates Cmd+V in the active app")
                HelpRow(key: "Password/secure field", value: "Copies to clipboard only — no keystroke simulation")
                HelpRow(key: "Per-app: clipboard only", value: "Always copies, never pastes")
                HelpRow(key: "Per-app: Accessibility API", value: "Inserts directly via the macOS Accessibility API")
                HelpRow(key: "Auto-paste off", value: "Saves to history only; nothing is delivered to the app")
            }
            helpHeading("Auto-paste")
            helpBody("Quick Settings → Output → Auto-Paste. On by default. Turn off to save text to history only.")
            helpHeading("Copy-only in sensitive fields")
            helpBody("Quick Settings → Output → Copy Only in Sensitive Fields. On by default. Detects password fields via Accessibility API and switches to clipboard-only automatically.")
            helpHeading("Accessibility API insertion")
            helpBody("Quick Settings → Output → Use Accessibility API for Insertion. Inserts text directly into the focused element. More reliable in some apps; may not work in all.")
            helpHeading("Per-app rules")
            helpBody("Quick Settings → Output → Per-App Insertion Rules → Manage...\n\nSet clipboard-only or Accessibility API mode for specific apps by bundle ID.")
            helpHeading("Profanity filter")
            helpBody("Quick Settings → Output → Filter Profanity. Replaces matched words before delivery. Add or remove words using the fields that appear when the filter is enabled.")
            HelpScreenshot("help-output-settings",
                           caption: "The Output section of Quick Settings with all delivery toggles visible.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSCRIPTION HISTORY
// ─────────────────────────────────────────────────────────────────────────────

private struct HistoryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpHeading("Inline history panel")
            helpBody("Every transcription is logged in the panel at the top of the main popover. Each item shows timestamp, full text, copy button, and an \"Accuracy retry\" badge when applicable.\n\nClick the chevron to toggle between 100pt (collapsed) and 300pt (expanded).")
            HelpScreenshot("help-history-inline-expanded",
                           caption: "The history panel expanded, showing transcription items and the detach button.")
            helpHeading("Detached history window")
            helpBody("Click the expand icon (↗) in the panel header to open a full-size window with:")
            VStack(alignment: .leading, spacing: 6) {
                Label("Search across all history items", systemImage: "magnifyingglass")
                Label("Export all history to a plain text file", systemImage: "square.and.arrow.up")
                Label("Clear all history", systemImage: "trash")
                Label("Correction icon on each item — opens vocabulary fix sheet", systemImage: "character.book.closed")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.85))
            HelpScreenshot("help-history-window",
                           caption: "The detached history window with search, export, and clear controls.")
            helpHeading("History persistence")
            helpBody("History clears when you close the popover by default. Enable persistence at:\nQuick Settings → Mode → Persist History Across Sessions.\n\nWhen on, history is saved to disk and restored on next launch.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM VOCABULARY
// ─────────────────────────────────────────────────────────────────────────────

private struct VocabularyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpBody("Custom vocabulary teaches DexDictate to automatically replace transcribed words or phrases with your preferred versions. Useful for proper nouns, technical terms, and consistently mis-transcribed words.")
            helpCallout("Example: If Whisper transcribes \"Dex Dictate\" instead of \"DexDictate\", add an entry: Dex Dictate → DexDictate")
            helpHeading("Adding a replacement")
            helpBody("Option A — From the detached history window: click the correction icon (📖) on any history item → enter the correct version in the sheet. This button only appears when Quick Settings → Benchmark → Optimization → Correction Sheet is enabled.")
            helpBody("Option B — From Quick Settings: Quick Settings → Input → Custom Vocabulary → Manage...")
            HelpScreenshot("help-vocabulary-correction-sheet",
                           caption: "The vocabulary correction sheet with both fields filled.")
            helpHeading("How replacements work")
            helpBody("Word-boundary regex match, case-insensitive. Applied after transcription, before output delivery. Profile-specific bundled vocabulary merges with your custom entries; custom entries win on conflicts.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOICE COMMANDS
// ─────────────────────────────────────────────────────────────────────────────

private struct VoiceCommandsContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "mic.badge.plus")
            VStack(alignment: .leading, spacing: 12) {
                helpHeading("Built-in commands")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "\"Scratch That\"", value: "Deletes the most recent transcription")
                    HelpRow(key: "\"All Caps\"", value: "UPPERCASES everything said before it")
                    HelpRow(key: "\"New Line\" / \"Next Line\"", value: "Inserts a line break")
                }
                helpHeading("Custom commands")
                helpBody("Quick Settings → Input → Voice Commands → Manage...\n\nCustom commands use the prefix \"Dex\" followed by your keyword:")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "\"Dex comma\"", value: "Inserts ,")
                    HelpRow(key: "\"Dex period\"", value: "Inserts .")
                    HelpRow(key: "\"Dex tab\"", value: "Inserts a tab character")
                }
                helpBody("Custom commands are matched first; built-in commands are the fallback.")
                HelpScreenshot("help-voice-commands-sheet",
                               caption: "The Voice Commands sheet with example entries.")
                helpWarning("Command recognition depends on Whisper transcribing the trigger phrase accurately. Very short phrases may be clipped by an aggressive silence timeout.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILES
// ─────────────────────────────────────────────────────────────────────────────

private struct ProfilesContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "person.2")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("Profiles adjust bundled vocabulary, flavor ticker quotes, and the watermark icon for different regional English variants.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Standard", value: "US English defaults")
                    HelpRow(key: "Canadian", value: "Canadian English spelling and terms")
                    HelpRow(key: "Aussie", value: "Australian English spelling and terms")
                }
                helpHeading("Switching profiles")
                helpBody("Quick Settings → Mode → Profile selector. Click \"Return to Standard\" to go back to the default.")
                helpHeading("Flavor ticker")
                helpBody("Rotating motivational text shown below the app title, sourced from the active profile.\n\nToggle: Quick Settings → Mode → Show Flavor Ticker.")
                helpHeading("Stats ticker")
                helpBody("Current session word count, duration, and WPM.\n\nToggle: Quick Settings → Mode → Show Dictation Stats.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPEARANCE & MENU BAR
// ─────────────────────────────────────────────────────────────────────────────

private struct AppearanceContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "paintbrush")
            VStack(alignment: .leading, spacing: 12) {
                helpHeading("Themes")
                helpBody("Quick Settings → Appearance section → theme picker.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "System", value: "Follows macOS light/dark mode; material background")
                    HelpRow(key: "Cyberpunk", value: "Dark with cyan accents")
                    HelpRow(key: "Minimalist", value: "Softer, reduced chrome")
                    HelpRow(key: "High Contrast", value: "Enhanced contrast for accessibility")
                }
                helpHeading("Menu bar icon style")
                helpBody("Quick Settings → Menu Bar Style section.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Mic + Text", value: "Waveform icon with status text")
                    HelpRow(key: "Mic Only", value: "Waveform icon alone")
                    HelpRow(key: "Custom Icon", value: "Choose from 18 bundled icons")
                    HelpRow(key: "Logo Only", value: "DexDictate logo")
                    HelpRow(key: "Emoji", value: "Any emoji you enter")
                }
                HelpScreenshot("help-appearance-settings",
                               caption: "The Appearance and Menu Bar Style sections of Quick Settings.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING HUD
// ─────────────────────────────────────────────────────────────────────────────

private struct FloatingHUDContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "rectangle.on.rectangle")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("A small floating panel that shows DexDictate's status independently of the menu bar. Useful when dictating into full-screen apps where the popover is hidden.")
                helpHeading("Status colors")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Red", value: "Actively recording")
                    HelpRow(key: "Yellow", value: "Transcribing")
                    HelpRow(key: "Green", value: "Ready / idle")
                    HelpRow(key: "Orange", value: "Error state")
                }
                helpHeading("Enabling")
                helpBody("Quick Settings → Output → Show Floating HUD.")
                helpHeading("Moving")
                helpBody("Drag it by its background. Position is saved automatically and restored on next launch.")
                helpHeading("Hiding")
                helpBody("Toggle off in Quick Settings, or close the window. It will reopen on next launch if the setting is on.")
                HelpScreenshot("help-floating-hud-states",
                               caption: "The Floating HUD in recording (red) and idle (green) states.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE MODE
// ─────────────────────────────────────────────────────────────────────────────

private struct SafeModeContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            helpBody("Safe Mode applies a low-risk preset: Hold to Talk trigger, clipboard-only output (no auto-paste), and no sound effects.")
            helpCallout("Use Safe Mode when troubleshooting, testing in sensitive apps, or when normal dictation is behaving unexpectedly.")
            helpHeading("Enabling Safe Mode")
            helpBody("Quick Settings → Output → Safe Mode toggle.\n\nWhen on, your current settings are snapshotted. Turning it off restores them exactly.")
            HelpScreenshot("help-safe-mode-toggle",
                           caption: "The Safe Mode toggle in the Output section of Quick Settings.")
            helpHeading("Stable Dictation Defaults")
            helpBody("Resets transcription-specific settings (model, end preset, trim) to known-good values without affecting output or appearance preferences.\n\nLocation: Quick Settings → Benchmark → Restore Stable Defaults button.")
            helpHeading("Restore Defaults")
            helpBody("Footer → Restore Defaults resets all settings to factory defaults. Custom vocabulary and voice commands are not affected.")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// BENCHMARKING & MODELS
// ─────────────────────────────────────────────────────────────────────────────

private struct BenchmarkingContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "chart.bar")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("DexDictate can benchmark available Whisper models on your hardware and measure accuracy and speed.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "WER", value: "Word Error Rate — transcription accuracy vs. a reference transcript")
                    HelpRow(key: "Latency (avg/p95)", value: "How fast transcription completes")
                }
                helpHeading("Bundled corpus")
                helpBody("DexDictate ships with reference audio samples. You can also capture your own corpus — this reflects your voice and environment more accurately.")
                helpHeading("Benchmark Capture")
                helpBody("Quick Settings → Benchmark → Open Benchmark Capture.\n\nRead on-screen prompts aloud. DexDictate saves your recordings as a WAV corpus for future benchmarks.")
                HelpScreenshot("help-benchmark-capture",
                               caption: "The Benchmark Capture window showing a reference prompt and recording controls.")
                helpHeading("Model selection")
                helpBody("Quick Settings → Benchmark → Optimization → Active Model picks the current model.\n\nModel Selection below it controls auto vs manual: set it to your preferred model or leave it on Auto Idle Benchmark to let DexDictate benchmark and pick during idle time.")
                HelpScreenshot("help-model-settings",
                               caption: "The Benchmark Optimization section showing model and selection controls.")
                helpHeading("Restore Stable Defaults")
                helpBody("Quick Settings → Benchmark → Restore Stable Defaults resets transcription-specific settings to known-good values.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHORTCUTS & SIRI
// ─────────────────────────────────────────────────────────────────────────────

private struct ShortcutsContent: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SectionWatermark(systemName: "sparkles")
            VStack(alignment: .leading, spacing: 12) {
                helpBody("DexDictate supports three Siri Shortcuts / App Intents on macOS 13 and later.")
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Start Dictation", value: "\"Start dictation with DexDictate\"")
                    HelpRow(key: "Stop Dictation", value: "\"Stop listening in DexDictate\"")
                    HelpRow(key: "Toggle Dictation", value: "\"Toggle dictation with DexDictate\"")
                }
                helpHeading("Using Shortcuts")
                helpBody("Open the Shortcuts app → search \"DexDictate\" → add actions to a shortcut or assign Siri phrases.")
                helpCallout("App Intents require DexDictate to be running. If it is not running, Siri will attempt to launch it first.")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIAGNOSTICS
// ─────────────────────────────────────────────────────────────────────────────

private struct DiagnosticsContent: View {
    @ObservedObject private var permissions = PermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: Live capability status

            helpHeading("Live Capability Status")
            helpBody("Shows current macOS permission grants and live API probes. Probes are skipped when the corresponding permission is not granted.")
            VStack(alignment: .leading, spacing: 2) {
                HelpRow(key: "Accessibility (TCC)", value: permissions.accessibilityGranted ? "✓ Granted" : "✗ Not granted")
                HelpRow(key: "Microphone (TCC)", value: permissions.microphoneGranted ? "✓ Granted" : "✗ Not granted")
                HelpRow(key: "Input Monitoring (TCC)", value: permissions.inputMonitoringGranted ? "✓ Granted" : "✗ Not granted")
                if let report = permissions.capabilityReport {
                    HelpRow(key: "AX element read (live)", value: capabilityStatusLabel(report.accessibilityElementRead))
                    HelpRow(key: "Event tap preflight (live)", value: capabilityStatusLabel(report.eventTapPreflight))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // MARK: Existing troubleshooting

            helpHeading("Trigger not firing")
            helpBody("1. Check Permissions — Accessibility and Input Monitoring must both be granted.\n2. Fully quit DexDictate and relaunch.\n3. Confirm your shortcut is set in Quick Settings → Input → Trigger Mode and the shortcut recorder field.")
            helpHeading("Transcription is empty or wrong")
            helpBody("1. Confirm Microphone permission is granted.\n2. Check Input Device in Quick Settings → Input → Input Device.\n3. Enable Safe Mode (clipboard-only) to rule out output issues.\n4. Try the bundled tiny.en model in Quick Settings → Benchmark → Optimization → Active Model.")
            helpHeading("Text pasting in wrong place / not pasting")
            helpBody("1. Ensure the target app is in focus when you release the trigger.\n2. Check per-app rules in Quick Settings → Output → Per-App Insertion Rules → Manage...\n3. Try enabling Accessibility API insertion.")

            // MARK: Zoom compatibility

            helpHeading("Zoom Compatibility")

            helpBody("DexDictate works while Zoom is open. Different failure modes have different causes:")

            VStack(alignment: .leading, spacing: 4) {
                HelpRow(key: "Microphone fails during Zoom call", value: "Zoom may change the selected audio device. Check Route Health in Quick Settings. If recovery doesn't resume automatically, check the Input Device setting.")
                HelpRow(key: "Zoom chat doesn't receive text", value: "Click directly inside the Zoom chat box before triggering dictation. If text still doesn't appear, set a per-app rule for Zoom (us.zoom.xos) to use Clipboard Paste. Zoom's Electron-based chat may not support Accessibility API insertion.")
                HelpRow(key: "Works in TextEdit but not Zoom", value: "This is a target-app insertion issue, not a global failure. Set a per-app Clipboard Paste rule for Zoom. Quick Settings → Output → Per-App Insertion Rules → Manage…")
                HelpRow(key: "Works outside calls but not during", value: "Probable audio route switch during the call. Zoom typically changes the input device when joining. DexDictate's route recovery should resume automatically — check Route Health for recovery count and status.")
                HelpRow(key: "Password / OTP / verification fields", value: "DexDictate intentionally does not insert into detected secure fields. Text is copied to clipboard instead. This is expected safety behaviour.")
            }

            helpCallout("For Zoom chat specifically: Quick Settings → Output → Per-App Insertion Rules → Manage… → add bundle ID \"us.zoom.xos\" → Clipboard Paste.")

            // MARK: CoreAudio -10868

            helpHeading("Core Audio Error (-10868)")
            helpBody("If DexDictate repeatedly reports a Core Audio error, macOS Core Audio may be stuck. This can happen after system sleep, audio device changes, or when Zoom or another audio app disrupts the audio session.")
            helpWarning("Save your work first. The following command briefly interrupts all system audio.")
            helpBody("Open Terminal and run:")
            Text("sudo killall coreaudiod")
                .font(.caption.monospaced())
                .foregroundStyle(.cyan.opacity(0.9))
                .padding(8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            helpBody("If that does not work:")
            Text("sudo killall -9 coreaudiod")
                .font(.caption.monospaced())
                .foregroundStyle(.cyan.opacity(0.9))
                .padding(8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            helpBody("DexDictate does not run these commands automatically.")

            // MARK: Diagnostics log

            helpHeading("Diagnostics log")
            helpBody("DexDictate writes logs to:")
            Text("~/Library/Application Support/DexDictate/debug.log")
                .font(.caption.monospaced())
                .foregroundStyle(.cyan.opacity(0.9))
                .padding(8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            HelpScreenshot("help-permissions-banner",
                           caption: "Check the permissions banner first when something isn't working.")
            helpCallout("Enable Safe Mode when troubleshooting. If dictation works in Safe Mode but not normally, the issue is likely an output setting or per-app rule.")
        }
    }

    private func capabilityStatusLabel(_ status: PermissionCapabilityChecker.Status) -> String {
        switch status {
        case .passed:               return "✓ Working"
        case .failed(let reason):   return "✗ Failed — \(reason)"
        case .skipped:              return "— Skipped (permission not granted)"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABOUT
// ─────────────────────────────────────────────────────────────────────────────

private struct AboutContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                if let url = Safety.resourceBundle.url(
                    forResource: "ProfileAssets/Icons/dexdictate-icon-standard-04",
                    withExtension: "png"
                ), let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why Dexter?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    helpBody("Dexter is a small, tricolor Phalene dog with floppy ears and a perpetually unimpressed expression... ungovernable, sharp-nosed and convinced he’s the quality bar. Alert, picky, dependable and devoted to doing things exactly his way: if he’s staring at you, assume you’ve made a mistake. If he approves, it means it works.")
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            helpBody("DexDictate is a local-first macOS dictation app built for speed, privacy, and reliability on Apple Silicon.")

            VStack(alignment: .leading, spacing: 6) {
                Label("All transcription runs on-device using OpenAI's open-source Whisper model", systemImage: "cpu")
                Label("No audio or text is sent to external servers", systemImage: "lock.shield")
                Label("Source code available on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.85))

            helpBody("Version information is displayed in the footer of the main popover.")
        }
    }
}
