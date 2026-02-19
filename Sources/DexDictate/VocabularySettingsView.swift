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
                
                TextField(NSLocalizedString("Replacement (e.g. 'Andrew's Dictation Command')", comment: ""), text: $newReplacement)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: addItem) {
                    Image(systemName: "plus")
                }
                .disabled(newOriginal.isEmpty || newReplacement.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func addItem() {
        withAnimation {
            vocabularyManager.add(original: newOriginal, replacement: newReplacement)
            newOriginal = ""
            newReplacement = ""
        }
    }
}
