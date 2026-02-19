import SwiftUI
import AppKit
import DexDictateKit

/// A dedicated window for viewing transcription history.
@MainActor
class HistoryWindowController: ObservableObject {
    private var window: NSWindow?
    private var engine: TranscriptionEngine?
    
    init() {}
    
    func setup(engine: TranscriptionEngine) {
        self.engine = engine
    }
    
    func show() {
        guard let engine = engine else { return }
        if window == nil {
            let view = FullHistoryView(history: engine.history)
            let hosting = NSHostingController(rootView: view)
            window = NSWindow(contentViewController: hosting)
            window?.title = NSLocalizedString("Transcription History", comment: "")
            window?.setContentSize(NSSize(width: 400, height: 500))
            window?.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window?.center()
            window?.isReleasedWhenClosed = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

struct FullHistoryView: View {
    @ObservedObject var history: TranscriptionHistory
    @State private var isExporting = false
    @State private var document: TextDocument?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("History", comment: ""))
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    let content = history.items.map { $0.text }.joined(separator: "\n\n")
                    document = TextDocument(text: content)
                    isExporting = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help(NSLocalizedString("Export History", comment: ""))
                .disabled(history.isEmpty)
                
                Button(action: history.clear) {
                    Image(systemName: "trash")
                }
                .help(NSLocalizedString("Clear History", comment: ""))
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // List
            List {
                if history.items.isEmpty {
                    Text(NSLocalizedString("No transcription history.", comment: ""))
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(history.items) { item in
                        HistoryItemRow(item: item)
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
        .fileExporter(
            isPresented: $isExporting,
            document: document,
            contentType: .plainText,
            defaultFilename: "Transcription Export"
        ) { result in
            #if DEBUG
            switch result {
            case .success(let url): print("Saved to \(url)")
            case .failure(let error): print("Export failed: \(error.localizedDescription)")
            }
            #endif
        }
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    
    var body: some View {
        HStack(alignment: .top) {
            Text(item.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
