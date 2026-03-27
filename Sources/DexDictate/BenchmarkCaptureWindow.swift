import SwiftUI
import AppKit
import AVFoundation
import Combine
import DexDictateKit

@MainActor
final class BenchmarkCaptureWindowController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var isSessionReady = false
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var sessionDirectory: URL?
    @Published private(set) var manifestURL: URL?
    @Published private(set) var transcriptsURL: URL?
    @Published private(set) var capturedCount: Int = 0
    @Published private(set) var lastErrorMessage: String?

    private let recorder = AudioRecorderService()
    private var window: NSWindow?
    private var capturedEntries: [BenchmarkCapturedEntry] = []
    private var isPreparingNewSession = false

    private struct BenchmarkCapturedEntry: Codable, Equatable {
        let id: String
        let section: String
        let spokenPrompt: String
        let instructionText: String?
        let referenceText: String
        let fileName: String
        let recordedAt: Date
    }

    private struct BenchmarkCaptureManifest: Codable, Equatable {
        let createdAt: Date
        let sessionName: String
        let prompts: [BenchmarkPrompt]
        let capturedEntries: [BenchmarkCapturedEntry]
    }

    private var corpus: [BenchmarkPrompt] { BenchmarkCorpus.strictPrompts }

    override init() {
        super.init()
        recorder.$inputLevel
            .receive(on: RunLoop.main)
            .assign(to: &$inputLevel)
    }

    var currentPrompt: BenchmarkPrompt? {
        guard currentIndex >= 0, currentIndex < corpus.count else { return nil }
        return corpus[currentIndex]
    }

    var progressText: String {
        "\(capturedCount)/\(corpus.count)"
    }

    var currentPromptDescription: String {
        currentPrompt?.spokenPrompt ?? "Capture complete."
    }

    var currentPromptDetails: String {
        guard let prompt = currentPrompt else {
            return "The corpus is complete. Open the folder to run the benchmark scripts."
        }
        return "\(prompt.section) · \(prompt.id) · \(prompt.fileName)"
    }

    var currentPromptInstructionNote: String? {
        currentPrompt?.instructionText
    }

    func show(engine: TranscriptionEngine? = nil) {
        if let engine, engine.state != .stopped {
            engine.stopSystem()
        }

        prepareNewSessionIfNeeded()

        if window == nil {
            let view = BenchmarkCaptureView(controller: self)
            let hosting = NSHostingController(rootView: view)
            let createdWindow = NSWindow(contentViewController: hosting)
            createdWindow.title = NSLocalizedString("Benchmark Capture", comment: "Benchmark window title")
            createdWindow.setContentSize(NSSize(width: 640, height: 680))
            createdWindow.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            createdWindow.center()
            createdWindow.isReleasedWhenClosed = false
            createdWindow.delegate = self
            window = createdWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        discardRecordingIfNeeded()
    }

    func startRecordingOrStop() {
        if isRecording {
            stopRecordingIfNeeded()
        } else {
            startRecording()
        }
    }

    func previousPrompt() {
        guard !isRecording, currentIndex > 0 else { return }
        currentIndex -= 1
        statusMessage = "Moved back to \(currentPrompt?.id ?? "previous prompt")."
        lastErrorMessage = nil
    }

    func restartSession() {
        discardRecordingIfNeeded()
        isPreparingNewSession = false
        capturedEntries = []
        capturedCount = 0
        currentIndex = 0
        statusMessage = "Session reset. Ready to record."
        lastErrorMessage = nil
        prepareNewSessionIfNeeded(forceNew: true)
    }

    func openCorpusFolder() {
        guard let sessionDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([sessionDirectory])
    }

    func copyCorpusPath() {
        guard let sessionDirectory else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sessionDirectory.path, forType: .string)
        statusMessage = "Copied corpus folder path."
    }

    func copyBenchmarkCommand() {
        guard let sessionDirectory else { return }
        let command = "python3 scripts/benchmark.py --corpus-dir \"\(sessionDirectory.path)\" --model tiny.en --build release"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        statusMessage = "Copied benchmark command."
    }

    private func prepareNewSessionIfNeeded(forceNew: Bool = false) {
        guard !isPreparingNewSession else { return }
        guard forceNew || sessionDirectory == nil else {
            isSessionReady = true
            return
        }

        isPreparingNewSession = true
        defer { isPreparingNewSession = false }

        let fm = FileManager.default
        let baseDirectory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let rootDirectory = baseDirectory.appendingPathComponent("DexDictate", isDirectory: true)
            .appendingPathComponent("BenchmarkCaptures", isDirectory: true)
        let sessionName = BenchmarkCorpus.createCaptureSessionName()
        let sessionURL = rootDirectory.appendingPathComponent(sessionName, isDirectory: true)

        do {
            try fm.createDirectory(at: sessionURL, withIntermediateDirectories: true)
            sessionDirectory = sessionURL
            manifestURL = sessionURL.appendingPathComponent("benchmark_manifest.json")
            transcriptsURL = sessionURL.appendingPathComponent("transcripts.json")
            isSessionReady = true
            statusMessage = "Session ready. Record the first prompt."
            lastErrorMessage = nil
            writeSessionFiles()
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Failed to prepare benchmark folder."
        }
    }

    private func startRecording() {
        guard !isStarting, !isRecording else { return }
        guard let prompt = currentPrompt else {
            statusMessage = "Benchmark capture is complete."
            return
        }

        prepareNewSessionIfNeeded()
        guard isSessionReady, sessionDirectory != nil else { return }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .notDetermined:
            statusMessage = "Waiting for microphone permission..."
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.startRecording()
                    } else {
                        self.lastErrorMessage = "Microphone permission is required to record the benchmark corpus."
                        self.statusMessage = "Microphone permission denied."
                    }
                }
            }
            return
        case .denied, .restricted:
            lastErrorMessage = "Microphone permission is required to record the benchmark corpus."
            statusMessage = "Microphone permission denied."
            return
        case .authorized:
            break
        @unknown default:
            lastErrorMessage = "Microphone permission state is unavailable."
            statusMessage = "Microphone permission unavailable."
            return
        }

        isStarting = true
        statusMessage = "Starting \(prompt.id)..."
        lastErrorMessage = nil

        recorder.startRecordingAsync(inputDeviceUID: AppSettings.shared.inputDeviceUID) { [weak self] error in
            guard let self else { return }
            let shouldActivateRecording = self.isStarting
            self.isStarting = false
            guard shouldActivateRecording else { return }
            if let error {
                self.lastErrorMessage = error.localizedDescription
                self.statusMessage = "Benchmark recording failed to start."
                self.isRecording = false
                return
            }

            self.isRecording = true
            self.statusMessage = "Recording \(prompt.id). Speak the prompt, then stop."
        }
    }

    private func stopRecordingIfNeeded() {
        guard isRecording else { return }
        guard let prompt = currentPrompt else { return }
        guard let sessionDirectory else { return }

        isRecording = false
        statusMessage = "Saving \(prompt.fileName)..."

        let outputURL = sessionDirectory.appendingPathComponent(prompt.fileName)
        let result = recorder.stopAndCollect()
        inputLevel = 0

        guard !result.samples.isEmpty else {
            statusMessage = "No audio captured for \(prompt.id). Record it again."
            lastErrorMessage = nil
            return
        }

        do {
            try BenchmarkWAVWriter.writeFloatMono(samples: result.samples, sampleRate: result.sampleRate, to: outputURL)
            let entry = BenchmarkCapturedEntry(
                id: prompt.id,
                section: prompt.section,
                spokenPrompt: prompt.spokenPrompt,
                instructionText: prompt.instructionText,
                referenceText: prompt.referenceText,
                fileName: prompt.fileName,
                recordedAt: Date()
            )
            capturedEntries.removeAll { $0.fileName == prompt.fileName }
            capturedEntries.append(entry)
            capturedCount = capturedEntries.count
            writeSessionFiles()
            advanceAfterCapture()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Failed to save \(prompt.fileName)."
        }
    }

    private func discardRecordingIfNeeded() {
        guard isRecording else { return }
        recorder.stopRecording()
        isRecording = false
        isStarting = false
        inputLevel = 0
        statusMessage = "Current take discarded."
        lastErrorMessage = nil
    }

    private func advanceAfterCapture() {
        if currentIndex + 1 < corpus.count {
            currentIndex += 1
            statusMessage = "Saved. Next: \(currentPrompt?.id ?? "done")."
        } else {
            currentIndex = corpus.count
            statusMessage = "Capture complete. Open the folder to benchmark the corpus."
        }
    }

    private func writeSessionFiles() {
        guard let sessionDirectory else { return }

        let manifest = BenchmarkCaptureManifest(
            createdAt: Date(),
            sessionName: sessionDirectory.lastPathComponent,
            prompts: corpus,
            capturedEntries: capturedEntries.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let transcriptData = try? encoder.encode(Dictionary(uniqueKeysWithValues: capturedEntries.map { ($0.fileName, $0.referenceText) })),
           let transcriptsURL {
            try? transcriptData.write(to: transcriptsURL, options: .atomic)
        }

        if let manifestData = try? encoder.encode(manifest),
           let manifestURL {
            try? manifestData.write(to: manifestURL, options: .atomic)
        }
    }
}

struct BenchmarkCaptureView: View {
    @ObservedObject var controller: BenchmarkCaptureWindowController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.12, green: 0.12, blue: 0.16),
                    Color(red: 0.08, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header
                promptCard
                meterCard
                controlRow
                footerCard
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(minWidth: 640, minHeight: 680)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benchmark Capture")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Record the strict offline corpus one prompt at a time in your normal quiet-room setup. The app writes WAV files plus transcripts.json locally, ready for the benchmark scripts.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(controller.currentPrompt?.section ?? "Complete")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.cyan.opacity(0.85))
                Spacer()
                Text(controller.progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(controller.currentPromptDescription)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let instruction = controller.currentPromptInstructionNote {
                Text("Session note: \(instruction)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(controller.currentPromptDetails)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var meterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Microphone")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(controller.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }

            ProgressView(value: controller.inputLevel)
                .tint(.green)

            HStack {
                Text("Quiet")
                Spacer()
                Text("Hot")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))

            if let lastErrorMessage = controller.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            Button(controller.isRecording ? "Stop & Save" : "Record") {
                controller.startRecordingOrStop()
            }
            .buttonStyle(.borderedProminent)
            .tint(controller.isRecording ? .orange : .green)
            .disabled(controller.isStarting || (!controller.isRecording && controller.currentPrompt == nil))

            Button("Previous") {
                controller.previousPrompt()
            }
            .buttonStyle(.bordered)
            .disabled(controller.isRecording || controller.currentIndex == 0)

            Button("Restart Session") {
                controller.restartSession()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Copy Path") {
                controller.copyCorpusPath()
            }
            .buttonStyle(.bordered)
            .disabled(controller.sessionDirectory == nil)
        }
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Open Corpus Folder") {
                    controller.openCorpusFolder()
                }
                .buttonStyle(.bordered)
                .disabled(controller.sessionDirectory == nil)

                Button("Copy Benchmark Command") {
                    controller.copyBenchmarkCommand()
                }
                .buttonStyle(.bordered)
                .disabled(controller.sessionDirectory == nil)

                Spacer()

                if let sessionDirectory = controller.sessionDirectory {
                    Text(sessionDirectory.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Text("When the corpus is complete, run the existing benchmark scripts against the folder contents. No network calls, no cloud, no invented noise conditions.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .background(.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
