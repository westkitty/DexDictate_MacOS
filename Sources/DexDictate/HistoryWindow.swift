import SwiftUI
import AppKit
import DexDictateKit

/// A dedicated window for viewing transcription history.
@MainActor
class HistoryWindowController: ObservableObject {
    private var window: NSWindow?
    private var engine: TranscriptionEngine?
    private var vocabularyManager: VocabularyManager?
    
    init() {}
    
    func setup(engine: TranscriptionEngine, vocabularyManager: VocabularyManager) {
        self.engine = engine
        self.vocabularyManager = vocabularyManager
    }
    
    func show() {
        guard let engine = engine, let vocabularyManager else { return }
        if window == nil {
            let view = FullHistoryView(history: engine.history, vocabularyManager: vocabularyManager)
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
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

struct FullHistoryView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var history: TranscriptionHistory
    @ObservedObject var vocabularyManager: VocabularyManager
    @State private var isExporting = false
    @State private var document: TextDocument?
    @State private var searchText = ""
    @State private var draft = VocabularyCorrectionDraft()
    @State private var isCorrectionSheetPresented = false

    private var filteredItems: [HistoryItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return history.items
        }

        let query = searchText.localizedLowercase
        return history.items.filter { $0.text.localizedLowercase.contains(query) }
    }
    
    var body: some View {
        ZStack {
            if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .opacity(0.08)
                    .allowsHitTesting(false)
            }

            Text("DEXDICTATE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color.white.opacity(0.08))
                .rotationEffect(.degrees(-15))
                .allowsHitTesting(false)

        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text(NSLocalizedString("History", comment: ""))
                        .font(.headline)
                    Spacer()

                    ChromeIconButton(systemName: "square.and.arrow.up", accessibilityText: "Export history") {
                        let content = filteredItems.map { item in
                            let timestamp = item.createdAt.formatted(date: .abbreviated, time: .shortened)
                            return "[\(timestamp)]\n\(item.text)"
                        }.joined(separator: "\n\n")
                        document = TextDocument(text: content)
                        isExporting = true
                    }
                    .help(NSLocalizedString("Export History", comment: ""))
                    .disabled(filteredItems.isEmpty)

                    ChromeIconButton(systemName: "trash", accessibilityText: "Clear history") {
                        history.clear()
                    }
                    .help(NSLocalizedString("Clear History", comment: ""))
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search history", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search history")
                    Text("\(filteredItems.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.black.opacity(reduceTransparency ? 0.94 : 0.78))
            
            Divider()
            
            // List
            List {
                if history.items.isEmpty {
                    Text(NSLocalizedString("No transcription history.", comment: ""))
                        .foregroundStyle(.secondary)
                        .padding()
                } else if filteredItems.isEmpty {
                    Text(NSLocalizedString("No history matches your search.", comment: ""))
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(filteredItems) { item in
                        HistoryItemRow(item: item) {
                            draft = VocabularyCorrectionDraft(incorrectPhrase: item.text, correctPhrase: "")
                            isCorrectionSheetPresented = true
                        }
                    }
                }
            }
        }
        }
        .background(
            reduceTransparency
            ? AnyShapeStyle(Color.black.opacity(0.94))
            : AnyShapeStyle(
                LinearGradient(
                    colors: [Color.black.opacity(0.88), Color(red: 0.11, green: 0.12, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
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
        .sheet(isPresented: $isCorrectionSheetPresented) {
            VocabularyCorrectionSheet(draft: $draft) {
                vocabularyManager.add(
                    original: draft.incorrectPhrase.trimmingCharacters(in: .whitespacesAndNewlines),
                    replacement: draft.correctPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                isCorrectionSheetPresented = false
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    var onLearnCorrection: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(item.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if item.isAccuracyRetry {
                    Text("Accuracy retry")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                ChromeIconButton(systemName: "doc.on.doc", accessibilityText: "Copy history item") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.text, forType: .string)
                }

                if AppSettings.shared.enableCorrectionSheet {
                    ChromeIconButton(systemName: "character.book.closed", accessibilityText: "Learn correction from history item") {
                        onLearnCorrection()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
