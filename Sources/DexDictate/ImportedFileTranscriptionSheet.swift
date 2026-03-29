import SwiftUI
import AppKit
import DexDictateKit

struct ImportedFileTranscriptionSheet: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let result: ImportedFileTranscriptionResult
    let onClose: () -> Void

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color.black.opacity(0.94)
            } else {
                LinearGradient(
                    colors: [Color.black.opacity(0.92), Color(red: 0.08, green: 0.1, blue: 0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "waveform.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Imported File Transcript")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.95))
                        Text(result.fileName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(2)
                        Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.42))
                    }

                    Spacer()

                    ChromeIconButton(systemName: "xmark", accessibilityText: "Close imported transcript") {
                        onClose()
                    }
                }

                if result.wasModified {
                    Text("Processed with vocabulary or profanity filtering before saving.")
                        .font(.caption2)
                        .foregroundStyle(.cyan.opacity(0.88))
                } else {
                    Text("Saved to history without auto-pasting.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                ScrollView {
                    Text(result.transcript)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Button("Copy Transcript") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.transcript, forType: .string)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Close") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
        }
        .frame(width: 360, height: 320)
    }
}
