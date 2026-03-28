import SwiftUI
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
    @State private var isHelpPresented = false
    @State private var helpGlowing = false
    @ObservedObject private var settings = AppSettings.shared

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            if engine.state == .stopped {
                // ── Stopped: offer to start the dictation system ──────────────
                Button(action: startDictation) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text(NSLocalizedString("Start Dictation", comment: "Button: Start Dictation"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .shadow(color: .green.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start dictation system")
            } else {
                // ── Running: status + shortcut hint + stop button ─────────────

                HStack {
                    Spacer()
                    Button(action: {
                        isHelpPresented = true
                        settings.hasSeenHelpTutorial = true
                        helpGlowing = false
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .scaleEffect(helpGlowing ? 1.15 : 1.0)
                            .shadow(color: helpGlowing ? Color.blue.opacity(0.8) : .clear, radius: helpGlowing ? 8 : 0)
                    }
                    .buttonStyle(.plain)
                    .help("How DexDictate works")
                }
                .onAppear {
                    if !settings.hasSeenHelpTutorial {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            helpGlowing = true
                        }
                    }
                }

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
                        .foregroundStyle(.white.opacity(0.55))
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

                        retryAffordanceView

                        if AppSettings.shared.enableCorrectionSheet, engine.latestHistoryItem != nil {
                            actionButton(
                                label: "Learn Correction",
                                icon: "text.badge.plus",
                                color: .purple.opacity(0.45),
                                action: openCorrectionSheet
                            )
                        }
                    }
                }

                if adaptiveBenchmarkController.status != .idle {
                    Text(adaptiveBenchmarkController.status.description)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }

                // Stop the whole dictation system
                VStack(spacing: 4) {
                    Button(action: stopDictation) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text(NSLocalizedString("Turn Off Dictation", comment: ""))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .red.opacity(0.3), radius: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Turn off dictation system")

                    Text(AppSettings.shared.triggerMode == .holdToTalk
                         ? NSLocalizedString("DexDictate only listens while the trigger is held.", comment: "")
                         : NSLocalizedString("DexDictate listens until you press the trigger again.", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
            }

            // ── Always visible: Quit ──────────────────────────────────────────
            Button(action: quitApp) {
                Text(NSLocalizedString("Quit App", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit DexDictate")
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
        .sheet(isPresented: $isHelpPresented) {
            HelpTutorialView()
        }
    }

    @ViewBuilder
    private var retryAffordanceView: some View {
        if engine.lastTranscriptionWasSuspect && engine.canRetryLastUtterance {
            // Suspect result inline inline prompt
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
                Text(NSLocalizedString("Didn't catch that", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(NSLocalizedString("Retry in Accuracy Mode", comment: "")) {
                    retryLastUtterance()
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 2)
        } else if engine.canRetryLastUtterance {
            actionButton(
                label: "Retry Last in Accuracy Mode",
                icon: "arrow.counterclockwise",
                color: .blue.opacity(0.45),
                action: retryLastUtterance
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

    private func quitApp() {
        NSApplication.shared.terminate(nil)
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

    /// Uniform-sized action button matching the Stop Dictation style.
    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(NSLocalizedString(label, comment: ""))
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct HelpTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(icon: String, color: Color, title: String, body: String)] = [
        ("mic.fill", .blue, "Hold to Talk (default)",
         "Hold your trigger (middle mouse or custom key) and speak. Release when done — DexDictate transcribes and types the result automatically."),
        ("arrow.triangle.2.circlepath", .orange, "Click to Toggle",
         "Press trigger once to start listening, press again to stop. Useful for longer dictations. Change this in Quick Settings."),
        ("waveform", .green, "Live Accuracy",
         "DexDictate uses Whisper AI running 100% on-device — no internet, no cloud. For difficult audio, use 'Retry in Accuracy Mode' to reprocess with higher quality settings."),
        ("text.badge.plus", .purple, "Learn Correction",
         "If Whisper mishears a word (like a name or jargon), use 'Learn Correction' to teach it the right substitution. Applied automatically on every future transcription."),
        ("doc.on.clipboard", .cyan, "Clipboard-Free Paste",
         "Enable 'Insert without clipboard' in Quick Settings to type text directly into the focused field — your clipboard stays untouched."),
        ("clock.arrow.circlepath", .yellow, "History",
         "Every transcription is saved to the history list. Click the expand arrow to see past results. Enable 'Remember history between sessions' to persist across launches."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("How DexDictate Works", comment: ""))
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.title) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundStyle(item.color)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                Text(item.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()
            Button(NSLocalizedString("Got it", comment: "")) { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .frame(width: 420, height: 500)
    }
}
