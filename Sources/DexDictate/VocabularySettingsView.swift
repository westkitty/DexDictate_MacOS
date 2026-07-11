import SwiftUI
import DexDictateKit

public struct VocabularySettingsView: View {
    @ObservedObject var vocabularyManager: VocabularyManager
    @State private var newOriginal = ""
    @State private var newReplacement = ""
    
    public init(vocabularyManager: VocabularyManager) {
        self.vocabularyManager = vocabularyManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Custom Vocabulary", comment: ""))
                .font(.headline)
            
            Text(NSLocalizedString("Define text replacements to automatically correct specific words or phrases.", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            List {
                ForEach(vocabularyManager.items) { item in
                    HStack {
                        Text(item.original)
                            .font(.system(.body, design: .monospaced))
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.replacement)
                            .bold()
                    }
                }
                .onDelete(perform: vocabularyManager.remove)
            }
            .listStyle(.inset)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            HStack {
                TextField(NSLocalizedString("Original (e.g. 'ADC')", comment: ""), text: $newOriginal)
                    .textFieldStyle(.roundedBorder)
                
                Image(systemName: "arrow.right")
                
                TextField(NSLocalizedString("Replacement (e.g. 'Dex's Dictation Command')", comment: ""), text: $newReplacement)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: addItem) {
                    Image(systemName: "plus")
                }
                .disabled(
                    newOriginal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    newReplacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addItem() {
        // Trim before validating/adding — a whitespace-only entry (e.g. a single space)
        // otherwise passed the non-empty check above and got added as a real correction rule.
        let original = newOriginal.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = newReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, !replacement.isEmpty else { return }
        withAnimation {
            try? vocabularyManager.add(original: original, replacement: replacement)
            newOriginal = ""
            newReplacement = ""
        }
    }
}
