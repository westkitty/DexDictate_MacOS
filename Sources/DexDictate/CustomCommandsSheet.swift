import SwiftUI
import DexDictateKit

/// Modal window content for managing user-defined voice commands.
///
/// Custom commands use the "Dex [keyword]" hot-word. Say "Dex comma" to insert a comma.
struct CustomCommandsView: View {
    @ObservedObject var manager: CustomCommandsManager

    @State private var newKeyword: String = ""
    @State private var newInsertText: String = ""
    @State private var showAddRow: Bool = false

    private let builtInCommands: [(phrase: String, description: String)] = [
        ("Scratch that", "Deletes the most recent transcription"),
        ("All caps", "UPPERCASES everything said before it"),
        ("New line / Next line", "Inserts a line break"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Commands")
                    .font(.headline)
                Text("Say **Dex [keyword]** during dictation to insert custom text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Example: say \"Dex comma\" to insert a comma character.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Built-in Commands")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ForEach(builtInCommands, id: \.phrase) { command in
                    HStack {
                        Text(command.phrase)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(width: 160, alignment: .leading)
                        Text(command.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Your Commands")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showAddRow = true
                    } label: {
                        Label("Add Command", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if manager.commands.isEmpty && !showAddRow {
                    Text("No custom commands yet. Click + to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                if showAddRow {
                    HStack(spacing: 8) {
                        Text("Dex")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextField("keyword", text: $newKeyword)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("→")
                            .foregroundStyle(.secondary)
                        TextField("text to insert", text: $newInsertText)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let keyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
                            let insertText = newInsertText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !keyword.isEmpty, !insertText.isEmpty else { return }
                            manager.add(CustomCommand(keyword: keyword, insertText: insertText))
                            newKeyword = ""
                            newInsertText = ""
                            showAddRow = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(
                            newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            newInsertText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )

                        Button("Cancel") {
                            newKeyword = ""
                            newInsertText = ""
                            showAddRow = false
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                ForEach(manager.commands) { command in
                    HStack(spacing: 8) {
                        Text("Dex \(command.keyword)")
                            .font(.caption.bold())
                            .frame(width: 160, alignment: .leading)
                        Text("→ \"\(command.insertText)\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            manager.remove(id: command.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }
            .padding(.bottom, 8)

            Spacer()
        }
        .frame(width: 460, height: 380)
    }
}
