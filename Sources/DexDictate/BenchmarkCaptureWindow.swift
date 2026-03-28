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
            createdWindow.setContentSize(NSSize(width: 640, height: 760))
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
        let command = "python3 scripts/benchmark.py --corpus-dir \"\(sessionDirectory.path)\" --model tiny.en --build release --json-output /tmp/dexdictate-benchmark.json --csv-output /tmp/dexdictate-benchmark.csv --gate-file benchmark_baseline.json"
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
        .frame(minWidth: 640, minHeight: 760)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.mic")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Benchmark Capture")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Build a reference corpus to measure transcription accuracy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("What is this?")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.cyan.opacity(0.8))
                    .tracking(0.6)
                Text("Record each prompt exactly as written. DexDictate saves your voice alongside the correct text, then runs Whisper against both to measure how accurately it transcribes your voice in your environment. Run the benchmark after any model, device, or settings change to see if accuracy improved.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.cyan.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        VStack(spacing: 8) {
            // Primary record/stop button — full width, matches Stop Dictation style
            Button(action: controller.startRecordingOrStop) {
                HStack {
                    Image(systemName: controller.isRecording ? "stop.circle.fill" : "mic.fill")
                    Text(controller.isStarting ? "Starting…" : controller.isRecording ? "Stop & Save" : "Record Prompt")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(controller.isRecording ? Color.orange.opacity(0.5) : Color.green.opacity(0.45))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: (controller.isRecording ? Color.orange : Color.green).opacity(0.3), radius: 5)
            }
            .buttonStyle(.plain)
            .disabled(controller.isStarting || (!controller.isRecording && controller.currentPrompt == nil))

            // Secondary actions
            HStack(spacing: 8) {
                Button(action: controller.previousPrompt) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(controller.isRecording || controller.currentIndex == 0)

                Button(action: controller.restartSession) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Restart")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: controller.copyCorpusPath) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Path")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(controller.sessionDirectory == nil)
            }
        }
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After Capture")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.6))
                .tracking(0.6)

            Text("When all prompts are recorded, run the benchmark script against the folder. It compares each WAV file to the reference transcript and reports a Word Error Rate (WER). Lower WER = better accuracy for your voice and setup.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: controller.openCorpusFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Open Folder")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(controller.sessionDirectory == nil)

                Button(action: controller.copyBenchmarkCommand) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Text("Copy Run Command")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(controller.sessionDirectory == nil)
            }

            if let sessionDirectory = controller.sessionDirectory {
                Text(sessionDirectory.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
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
