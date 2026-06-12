import SwiftUI
import DexDictateKit

// MARK: - Feature Hub

/// Full-feature access panel embedded in the state-first popover.
///
/// Wraps `QuickSettingsView` along with top-level actions (Quit, Help, History).
/// Owns scanner / benchmark state objects so the parent views don't need to thread them.
/// Accessible from `DexStateFirstPopoverView` via `ExperimentalScreen.featureHub`.
struct DexExperimentalFeatureHubView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    var onBack: () -> Void
    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onQuit: () -> Void

    @StateObject private var scanner = AudioDeviceScanner()
    @StateObject private var benchmarkCaptureController = BenchmarkCaptureWindowController()
    @StateObject private var adaptiveBenchmarkController = AdaptiveBenchmarkController()
    @ObservedObject private var menuBarIconController = MenuBarIconController.shared
    @ObservedObject private var modelCatalog = WhisperModelCatalog.shared
    @ObservedObject private var benchmarkResultsStore = BenchmarkResultsStore.shared

    @State private var isQuickSettingsExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
            Divider().opacity(0.18)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    hubActions
                    QuickSettingsView(
                        engine: engine,
                        settings: settings,
                        scanner: scanner,
                        profileManager: profileManager,
                        benchmarkCaptureController: benchmarkCaptureController,
                        vocabularyManager: engine.vocabularyManager,
                        menuBarIconController: menuBarIconController,
                        modelCatalog: modelCatalog,
                        adaptiveBenchmarkController: adaptiveBenchmarkController,
                        benchmarkResultsStore: benchmarkResultsStore,
                        isExpanded: $isQuickSettingsExpanded
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var hubHeader: some View {
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

            Text("All Features")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onQuit) {
                HStack(spacing: 3) {
                    Image(systemName: "power")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text("Quit")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit DexDictate")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Quick actions

    private var hubActions: some View {
        HStack(spacing: 8) {
            if let onDetachHistory {
                Button(action: { onDetachHistory(); onBack() }) {
                    Label("History", systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open full history window")
            }

            if let onOpenHelp {
                Button(action: { onOpenHelp(); onBack() }) {
                    Label("Help", systemImage: "questionmark.circle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Help")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - GUI Switcher

/// In-popover surface switcher — lets Andrew switch between experimental surfaces
/// without using shell `defaults write` commands.
///
/// Accessible from `DexStateFirstPopoverView` via `ExperimentalScreen.guiSwitcher`.
struct DexExperimentalGUISwitcherView: View {
    @ObservedObject var settings: AppSettings
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switcherHeader
            Divider().opacity(0.18)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    mainSurfaceSection
                    addOnSection
                    switcherFootnote
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var switcherHeader: some View {
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

            Text("Switch UI Surface")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Main surface section

    private var mainSurfaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Main Popover Surface")

            surfaceRow(
                title: "Standard UI",
                subtitle: "Original DexDictate popover with Quick Settings.",
                icon: "macwindow",
                isActive: !settings.useExperimentalStateFirstUI
            ) {
                settings.useExperimentalStateFirstUI = false
                onBack()
            }

            surfaceRow(
                title: "State-first Popover",
                subtitle: "Compact experimental popover. Currently active.",
                icon: "rectangle.compress.vertical",
                isActive: settings.useExperimentalStateFirstUI
            ) {
                settings.useExperimentalStateFirstUI = true
            }
        }
    }

    // MARK: - Add-on section

    private var addOnSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Add-on Surfaces")

            toggleRow(
                title: "Nano HUD",
                subtitle: "Floating strip showing recording state. Shown alongside any popover.",
                icon: "strip.fill",
                isOn: $settings.useExperimentalNanoHUD
            )

            toggleRow(
                title: "Command Palette",
                subtitle: "⌘K shortcut and palette button in state-first popover.",
                icon: "magnifyingglass",
                isOn: $settings.useExperimentalCommandPalette
            )

            toggleRow(
                title: "Dexter Feed",
                subtitle: "Stateful commentary feed in Settings & History panel.",
                icon: "quote.bubble",
                isOn: $settings.useExperimentalDexterFeed
            )
        }
    }

    // MARK: - Footnote

    private var switcherFootnote: some View {
        Text("Changes take effect immediately. Selecting Standard UI closes this surface.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.28))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: - Components

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.40))
            .tracking(0.8)
            .accessibilityAddTraits(.isHeader)
    }

    private func surfaceRow(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(isActive ? Color.cyan.opacity(0.22) : Color.white.opacity(0.06))
                    .foregroundStyle(isActive ? .cyan : .white.opacity(0.60))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(2)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                        .font(.system(size: 14))
                        .accessibilityHidden(true)
                }
            }
            .padding(10)
            .background(isActive ? Color.cyan.opacity(0.08) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isActive ? Color.cyan.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(isActive ? ", active" : "")")
        .accessibilityHint(subtitle)
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .frame(width: 18)
                        .foregroundStyle(.white.opacity(0.60))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .toggleStyle(.switch)
            .accessibilityLabel(title)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 26)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
