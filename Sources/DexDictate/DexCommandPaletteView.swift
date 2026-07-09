import SwiftUI
import DexDictateKit

// MARK: - Command Model

struct DexPaletteCommand: Identifiable {
    enum ActionKind {
        case live(() -> Void)   // performs an action now
        case toggle             // handled externally via binding
        case disabled(String)   // affordance with reason shown in help text
    }

    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let category: Category
    let action: ActionKind

    enum Category: String, CaseIterable {
        case dictation  = "Dictation"
        case ui         = "UI"
        case settings   = "Settings"
    }

    var isDisabled: Bool {
        if case .disabled = action { return true }
        return false
    }

    var disabledReason: String? {
        if case .disabled(let reason) = action { return reason }
        return nil
    }
}

// MARK: - Command Palette View

/// Isolated command palette.
///
/// Adopted into the standard slim popover (Packet 12A) as an unconditional feature —
/// reachable via ⌘K or the footer overflow menu, no longer flag-gated (the
/// `useExperimentalCommandPalette` flag's only reader lived in the now-retired
/// state-first popover; Packet 12B removed that reader). It lists local commands
/// only — no global hotkey listener is added, `InputMonitor` is not modified, and
/// production trigger behavior is unchanged.
///
/// Actions that cannot be safely wired (no public engine method) are shown as
/// disabled with an explanatory subtitle rather than silently hidden.
struct DexCommandPaletteView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings

    var onBack: () -> Void
    var onOpenFeatureHub: (() -> Void)?
    var onOpenGUISwitcher: (() -> Void)?
    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?

    @State private var query: String = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Commands

    private var allCommands: [DexPaletteCommand] {[
        // Dictation
        DexPaletteCommand(
            title: "Start Dictation",
            subtitle: "Start the dictation system (same as Start Dictation button).",
            icon: "mic.fill",
            category: .dictation,
            action: engine.state == .stopped
                ? .live { MainActorAction.run { await engine.startSystem() }; onBack() }
                : .disabled("Dictation system is already running.")
        ),
        DexPaletteCommand(
            title: "Stop Dictation System",
            subtitle: "Fully stop dictation. Does not discard audio in-flight.",
            icon: "stop.fill",
            category: .dictation,
            action: engine.state != .stopped
                ? .live { MainActorAction.run { engine.stopSystem() }; onBack() }
                : .disabled("Dictation system is already stopped.")
        ),
        DexPaletteCommand(
            title: "Stop Recording Early",
            subtitle: "If currently listening, stop and proceed to transcription.",
            icon: "stop.circle",
            category: .dictation,
            action: engine.state == .listening
                ? .live { MainActorAction.run { engine.toggleListening() }; onBack() }
                : .disabled("Not currently recording.")
        ),

        // UI
        DexPaletteCommand(
            title: "Toggle Nano HUD",
            subtitle: settings.useExperimentalNanoHUD
                ? "Currently ON — tap to disable."
                : "Currently OFF — tap to enable. Restart HUD to see change.",
            icon: "strip.fill",
            category: .ui,
            action: .live { settings.useExperimentalNanoHUD.toggle() }
        ),
        DexPaletteCommand(
            title: "Toggle Floating HUD",
            subtitle: settings.showFloatingHUD
                ? "Currently ON — tap to hide."
                : "Currently OFF — tap to show.",
            icon: "eye",
            category: .ui,
            action: .live { settings.showFloatingHUD.toggle() }
        ),
        DexPaletteCommand(
            title: "Open Full History",
            subtitle: "Open the detached history window.",
            icon: "clock",
            category: .ui,
            action: onDetachHistory != nil
                ? .live { onDetachHistory?(); onBack() }
                : .disabled("History window is not available here.")
        ),
        DexPaletteCommand(
            title: "Open Help",
            subtitle: "Open the help window.",
            icon: "questionmark.circle",
            category: .ui,
            action: onOpenHelp != nil
                ? .live { onOpenHelp?(); onBack() }
                : .disabled("Help is not available here.")
        ),

        // Settings
        DexPaletteCommand(
            title: "Toggle Safe Mode",
            subtitle: settings.safeModeEnabled
                ? "Currently ON — tap to disable."
                : "Currently OFF — tap to enable conservative dictation output.",
            icon: "shield.lefthalf.filled",
            category: .settings,
            action: .live {
                if settings.safeModeEnabled { settings.disableSafeMode() }
                else { settings.enableSafeMode() }
            }
        ),
        DexPaletteCommand(
            title: "Toggle Auto-paste",
            subtitle: settings.autoPaste
                ? "Currently ON — tap to disable."
                : "Currently OFF — tap to enable paste after transcription.",
            icon: "doc.on.clipboard",
            category: .settings,
            action: .live { settings.autoPaste.toggle() }
        ),
        DexPaletteCommand(
            title: "Toggle Dexter Commentary",
            subtitle: settings.showFlavorTicker
                ? "Currently ON — tap to mute."
                : "Currently OFF — tap to show commentary.",
            icon: "quote.bubble",
            category: .settings,
            action: .live { settings.showFlavorTicker.toggle() }
        ),

        // Navigation
        DexPaletteCommand(
            title: "Open All Features",
            subtitle: "Open the full feature hub with every DexDictate setting.",
            icon: "square.grid.2x2",
            category: .ui,
            action: onOpenFeatureHub != nil
                ? .live { onOpenFeatureHub?(); onBack() }
                : .disabled("Feature hub is not available from this context.")
        ),
        DexPaletteCommand(
            title: "Switch UI Surface",
            subtitle: "Change between Standard UI and experimental surfaces in-app.",
            icon: "switch.2",
            category: .ui,
            action: onOpenGUISwitcher != nil
                ? .live { onOpenGUISwitcher?(); onBack() }
                : .disabled("UI switcher is not available from this context.")
        ),
        DexPaletteCommand(
            title: "Quit DexDictate",
            subtitle: "Terminate the DexDictate application.",
            icon: "power",
            category: .ui,
            action: .live { NSApplication.shared.terminate(nil) }
        ),
    ]}

    private var filteredCommands: [DexPaletteCommand] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCommands }
        return allCommands.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            paletteHeader
            Divider().opacity(0.18)
            searchBar
            Divider().opacity(0.18)

            if filteredCommands.isEmpty {
                emptyResults
            } else {
                commandList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { searchFocused = true }
    }

    // MARK: - Sub-views

    private var paletteHeader: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                    Text("Back")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to main popover")
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text("Command Palette")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityHidden(true)

            TextField("Search commands…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .accessibilityLabel("Command search")
                .onSubmit { runFirstEnabled() }

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.20))
                .accessibilityHidden(true)
            Text("No commands match \"\(query)\"")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commandList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                let grouped = Dictionary(
                    grouping: filteredCommands,
                    by: { $0.category }
                )
                ForEach(DexPaletteCommand.Category.allCases, id: \.rawValue) { category in
                    if let commands = grouped[category], !commands.isEmpty {
                        Text(category.rawValue.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.38))
                            .tracking(0.8)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(commands) { command in
                            DexPaletteRow(command: command)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func runFirstEnabled() {
        guard let first = filteredCommands.first(where: { !$0.isDisabled }),
              case .live(let action) = first.action else { return }
        action()
    }
}

// MARK: - Palette Row

private struct DexPaletteRow: View {
    let command: DexPaletteCommand
    @State private var isHovered = false

    var body: some View {
        Button(action: runAction) {
            HStack(spacing: 10) {
                Image(systemName: command.icon)
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
                    .background(iconBg)
                    .foregroundStyle(iconFg)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(command.isDisabled ? .white.opacity(0.35) : .white.opacity(0.88))
                        .lineLimit(1)
                    Text(command.subtitle)
                        .font(.caption)
                        .foregroundStyle(command.isDisabled ? .white.opacity(0.22) : .white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()

                if command.isDisabled {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isHovered && !command.isDisabled
                ? Color.white.opacity(0.08)
                : Color.clear
            )
        }
        .buttonStyle(.plain)
        .disabled(command.isDisabled)
        .onHover { isHovered = $0 }
        .accessibilityLabel(command.title)
        .accessibilityHint(command.subtitle)
    }

    private func runAction() {
        if case .live(let action) = command.action { action() }
    }

    private var iconBg: Color {
        command.isDisabled ? Color.white.opacity(0.05) : Color.white.opacity(0.10)
    }

    private var iconFg: Color {
        command.isDisabled ? .white.opacity(0.25) : .white.opacity(0.75)
    }
}
