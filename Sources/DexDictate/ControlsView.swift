import SwiftUI
import UniformTypeIdentifiers
import DexDictateKit

/// Start/Stop Dictation and Quit buttons shown in the main popover.
///
/// Displays a **Start Dictation** button when the engine is `.stopped`.
/// When the engine is running, shows a status label (colour-coded by state),
/// the current trigger shortcut, and a **Stop Dictation** button.
/// The "Start Listening / Stop Listening" toggle has been removed — the trigger
/// shortcut or the Start/Stop Dictation buttons are the only controls.
struct ControlsView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController
    @State private var isCorrectionSheetPresented = false
    @State private var correctionDraft = VocabularyCorrectionDraft()

    // MARK: - Hover States
    @State private var isStartHovered = false
    @State private var isStopHovered = false
    @State private var isImportHovered = false

    // MARK: - Derived

    /// Colour that reflects the current engine state.
    private var statusColor: Color {
        switch engine.state {
        case .listening:    return .red
        case .transcribing: return .yellow
        case .ready:        return .green
        case .error:        return .orange
        default:            return .white
        }
    }

    // MARK: - Sub-views

    private var startDictationButton: some View {
        Button(action: startDictation) {
            HStack {
                Image(systemName: "mic.fill")
                Text(NSLocalizedString("Start Dictation", comment: "Button: Start Dictation"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(isStartHovered ? 0.55 : 0.4))
            .foregroundStyle(.white.opacity(isStartHovered ? 1.0 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(isStartHovered ? 0.45 : 0.3), lineWidth: 1))
            .shadow(color: .green.opacity(isStartHovered ? 0.45 : 0.3), radius: isStartHovered ? 8 : 5)
            .animation(.easeInOut(duration: 0.15), value: isStartHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isStartHovered = hovering } }
        .accessibilityLabel("Start dictation system")
    }

    private var stopDictationButton: some View {
        Button(action: stopDictation) {
            HStack {
                Image(systemName: "stop.fill")
                Text(NSLocalizedString("Turn Off Dictation", comment: ""))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red.opacity(isStopHovered ? 0.65 : 0.5))
            .foregroundStyle(.white.opacity(isStopHovered ? 1.0 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(isStopHovered ? 0.4 : 0.0), lineWidth: 1))
            .shadow(color: .red.opacity(isStopHovered ? 0.45 : 0.3), radius: isStopHovered ? 8 : 5)
            .animation(.easeInOut(duration: 0.15), value: isStopHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isStopHovered = hovering } }
        .accessibilityLabel("Turn off dictation system")
    }

    private var importFileButton: some View {
        Button(action: importAudioFile) {
            HStack(spacing: 6) {
                Image(systemName: "doc.badge.plus")
                Text(NSLocalizedString("Transcribe File...", comment: "Button: Import audio file"))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(isImportHovered ? 0.25 : 0.15))
            .foregroundStyle(Color.cyan.opacity(isImportHovered ? 1.0 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(isImportHovered ? 0.45 : 0.3), lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isImportHovered)
        }
        .buttonStyle(.plain)
        .disabled(engine.state != .ready)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isImportHovered = hovering } }
        .accessibilityLabel("Import audio file for transcription")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            if engine.state == .stopped {
                // ── Stopped: offer to start the dictation system ──────────────
                startDictationButton
            } else {
                // ── Running: status + shortcut hint + stop button ─────────────

                // Colour-coded status label (Listening / Transcribing / Ready / …)
                Text(engine.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                // Remind user which shortcut triggers dictation
                VStack(spacing: 6) {
                    Text("Trigger")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(AppSettings.shared.userShortcut.displayString)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, SurfaceTokens.capsuleHorizontal)
                        .padding(.vertical, SurfaceTokens.capsuleVertical)
                        .background(Color.white.opacity(0.08))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(.white.opacity(0.9))
                }

                if engine.resultFeedback != .idle {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: engine.resultFeedback.symbolName)
                                .font(.caption)
                            Text(engine.resultFeedback.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(feedbackBackgroundColor)
                        .foregroundStyle(feedbackForegroundColor)
                        .clipShape(Capsule())
                        .help(engine.resultFeedback.detail)
                        .accessibilityLabel(engine.resultFeedback.title)

                        if engine.resultFeedback == .deletedPreviousHistory && engine.canUndoLastHistoryRemoval {
                            Button("Undo removal") {
                                undoLastHistoryRemoval()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Restore the most recently removed history entry")
                        }

                        if engine.canRetryLastUtterance {
                            Button("Retry Last in Accuracy Mode") {
                                retryLastUtterance()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Retry the last utterance in accuracy mode")
                        }

                        if AppSettings.shared.enableCorrectionSheet, engine.latestHistoryItem != nil {
                            Button("Learn Correction") {
                                openCorrectionSheet()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Create a custom vocabulary correction")
                        }
                    }
                }

                if adaptiveBenchmarkController.status != .idle {
                    Text(adaptiveBenchmarkController.status.description)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }

                importFileButton

                // Stop the whole dictation system (returns to .stopped)
                stopDictationButton
            }
        }
        .padding(SurfaceTokens.cardPadding)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
        .padding(.horizontal)
        .sheet(isPresented: $isCorrectionSheetPresented) {
            VocabularyCorrectionSheet(
                draft: $correctionDraft,
                onSave: saveCorrection
            )
        }
    }

    private var feedbackBackgroundColor: Color {
        switch engine.resultFeedback.tone {
        case .neutral:
            return Color.white.opacity(0.12)
        case .success:
            return Color.green.opacity(0.18)
        case .warning:
            return Color.orange.opacity(0.18)
        }
    }

    private var feedbackForegroundColor: Color {
        switch engine.resultFeedback.tone {
        case .neutral:
            return .white.opacity(0.8)
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }

    // MARK: - Helper Methods

    /// Starts the dictation system asynchronously on the MainActor.
    ///
    /// Using named functions (rather than inline closures) avoids the SIGSEGV crash
    /// caused by SwiftUI's button gesture machinery calling `MainActor.assumeIsolated`
    /// when `engine` is `@MainActor`-isolated. This applies to ALL buttons that call
    /// methods on `@MainActor` types, including synchronous ones like `stopSystem()`.
    private func startDictation() {
        Task { @MainActor in
            await engine.startSystem()
        }
    }

    private func stopDictation() {
        engine.stopSystem()
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = NSLocalizedString("Transcribe", comment: "Open panel button label")
        panel.message = NSLocalizedString("Select an audio file to transcribe", comment: "Open panel message")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        engine.transcribeAudioFile(url: url)
    }

    private func undoLastHistoryRemoval() {
        engine.undoLastHistoryRemoval()
    }

    private func retryLastUtterance() {
        engine.retryLastUtteranceInAccuracyMode()
    }

    private func openCorrectionSheet() {
        correctionDraft = VocabularyCorrectionDraft(
            incorrectPhrase: engine.latestHistoryItem?.text ?? "",
            correctPhrase: ""
        )
        isCorrectionSheetPresented = true
    }

    private func saveCorrection() {
        let incorrect = correctionDraft.incorrectPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let corrected = correctionDraft.correctPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incorrect.isEmpty, !corrected.isEmpty else { return }
        engine.vocabularyManager.add(original: incorrect, replacement: corrected)
        isCorrectionSheetPresented = false
    }
}
