import SwiftUI
import DexDictateKit

struct VocabularyCorrectionSheet: View {
    @Binding var draft: VocabularyCorrectionDraft
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Learn Correction")
                .font(.headline)

            Text("Save an explicit phrase replacement. DexDictate will not infer rules from arbitrary edits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Incorrect Phrase")
                    .font(.caption.weight(.semibold))
                TextField("Incorrect phrase", text: $draft.incorrectPhrase)
                    .textFieldStyle(.roundedBorder)

                Text("Correct Phrase")
                    .font(.caption.weight(.semibold))
                TextField("Correct phrase", text: $draft.correctPhrase)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Correction") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
        }
        .padding(18)
        .frame(width: 420)
    }
}
