import SwiftUI
import DexDictateKit

// MARK: - State Hero

/// Large state readout at the top of the compact popover.
struct DexStateHero: View {
    let engineState: EngineDisplayState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: engineState.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(heroColor)
                .symbolEffect(
                    .pulse,
                    isActive: engineState.isActive && !reduceMotion
                )
                .accessibilityHidden(true)

            Text(engineState.label)
                .font(.title3.weight(.bold))
                .foregroundStyle(heroColor)
                .accessibilityLabel("Engine state: \(engineState.label)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(heroColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(heroColor.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var heroColor: Color {
        switch engineState {
        case .stopped:      return .secondary
        case .initializing: return .blue
        case .ready:        return .green
        case .listening:    return .red
        case .transcribing: return .yellow
        case .error:        return .orange
        }
    }
}

// MARK: - Permission Chips

/// One chip per permission: mic, accessibility, input monitoring.
struct DexPermissionChips: View {
    let permissions: PermissionDisplayState
    let onFixTap: () -> Void

    var body: some View {
        if permissions.allGranted {
            DexStatusChip(
                icon: "checkmark.shield.fill",
                label: "Permissions OK",
                tone: .success
            )
            .accessibilityLabel("All required permissions are granted")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(permissions.missingLabels, id: \.self) { label in
                    DexStatusChip(
                        icon: "exclamationmark.triangle.fill",
                        label: "\(label) permission missing",
                        tone: .warning
                    )
                }
                Button(action: onFixTap) {
                    Text("Open System Settings →")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Open System Settings to fix missing permissions")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Output Chips

struct DexOutputChips: View {
    let output: OutputDisplayState

    var body: some View {
        HStack(spacing: 6) {
            DexStatusChip(
                icon: output.autoPaste ? "doc.on.clipboard.fill" : "tray.and.arrow.down.fill",
                label: output.autoPaste ? "Auto-paste" : "Clipboard only",
                tone: .neutral
            )
            if output.safeMode {
                DexStatusChip(
                    icon: "shield.lefthalf.filled",
                    label: "Safe Mode",
                    tone: .warning
                )
            }
            if output.isClipboardFallback {
                DexStatusChip(
                    icon: "doc.on.doc",
                    label: "Secure field — copied",
                    tone: .warning
                )
                .accessibilityLabel("Secure field detected — text was copied to clipboard")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Generic Status Chip

enum DexChipTone { case neutral, success, warning, error }

struct DexStatusChip: View {
    let icon: String
    let label: String
    let tone: DexChipTone

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBg)
        .foregroundStyle(chipFg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(chipFg.opacity(0.28), lineWidth: 0.5))
    }

    private var chipBg: Color {
        switch tone {
        case .neutral:  return Color.white.opacity(0.08)
        case .success:  return Color.green.opacity(0.15)
        case .warning:  return Color.orange.opacity(0.15)
        case .error:    return Color.red.opacity(0.15)
        }
    }

    private var chipFg: Color {
        switch tone {
        case .neutral:  return .white.opacity(0.75)
        case .success:  return .green
        case .warning:  return .orange
        case .error:    return .red
        }
    }
}

// MARK: - Trigger + Model Chips (interactive)

struct DexContextChips: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelCatalog: WhisperModelCatalog
    @State private var showingTriggerPopover = false

    var body: some View {
        HStack(spacing: 6) {
            Button { showingTriggerPopover = true } label: {
                DexInteractivePill(icon: "hand.tap", text: settings.userShortcut.displayString)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Input: \(settings.userShortcut.displayString). Tap to rebind.")
            .popover(isPresented: $showingTriggerPopover, arrowEdge: .top) {
                ShortcutRecorder(shortcut: $settings.userShortcut)
                    .padding(12)
                    .frame(width: 220)
            }

            Menu {
                ForEach(modelCatalog.availableModels) { model in
                    Button(model.displayName) { settings.activeWhisperModelID = model.id }
                }
            } label: {
                DexInteractivePill(icon: "brain", text: settings.activeWhisperModelID)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Model: \(settings.activeWhisperModelID). Tap to change.")

            Button {
                settings.triggerMode = settings.triggerMode == .holdToTalk ? .toggle : .holdToTalk
            } label: {
                DexInteractivePill(
                    icon: settings.triggerMode == .holdToTalk ? "hand.raised.fill" : "record.circle",
                    text: settings.triggerMode == .holdToTalk ? "Hold Mode" : "Toggle Mode"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trigger mode: \(settings.triggerMode.rawValue). Tap to switch.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DexInteractivePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .foregroundStyle(Color.white.opacity(0.75))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.21), lineWidth: 0.5))
    }
}

// MARK: - Transcript Card

struct DexTranscriptCard: View {
    let transcript: TranscriptDisplayState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !transcript.liveText.isEmpty {
                Text(transcript.liveText)
                    .font(.caption.italic())
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .accessibilityLabel("Live transcript: \(transcript.liveText)")
            } else if let recent = transcript.recentText {
                Text(recent)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
                    .accessibilityLabel("Last transcription: \(recent)")
            } else {
                Text("No recent transcription")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }

            if transcript.inputLevel > 0.01 {
                DexMicMeter(level: transcript.inputLevel)
            }

            if let countdown = transcript.silenceCountdown {
                Text("Auto-stop in \(Int(countdown.rounded(.up)))s")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .accessibilityLabel("Auto-stop in \(Int(countdown.rounded(.up))) seconds")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Mic Meter

struct DexMicMeter: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color.red.opacity(0.72))
                    .frame(width: geo.size.width * CGFloat(min(level, 1.0)))
                    .animation(.linear(duration: 0.08), value: level)
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Microphone level: \(Int(level * 100)) percent")
        .accessibilityHidden(level < 0.01)
    }
}

// MARK: - Feedback Badge

struct DexFeedbackBadge: View {
    let title: String
    let icon: String
    let isFailure: Bool

    var body: some View {
        guard !title.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isFailure ? Color.orange.opacity(0.18) : Color.green.opacity(0.15))
            .foregroundStyle(isFailure ? Color.orange : Color.green)
            .clipShape(Capsule())
            .accessibilityLabel(title)
        )
    }
}

// MARK: - Dexter Line

struct DexterCommentaryLine: View {
    let text: String

    var body: some View {
        guard !text.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            Text("\u{201C}\(text)\u{201D}")
                .font(.caption2.italic())
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Dexter says: \(text)")
                .accessibilityAddTraits(.isStaticText)
        )
    }
}
