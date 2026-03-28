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
    @Published private(set) var statusMessage = "Ready."
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
            return "All prompts recorded. Run the benchmark."
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
        statusMessage = "Back to \(currentPrompt?.id ?? "previous")."
        lastErrorMessage = nil
    }

    func restartSession() {
        discardRecordingIfNeeded()
        isPreparingNewSession = false
        capturedEntries = []
        capturedCount = 0
        currentIndex = 0
        statusMessage = "Session reset. Starting from A1."
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
        statusMessage = "Corpus path copied."
    }

    func copyBenchmarkCommand() {
        guard let sessionDirectory else { return }
        let command = "python3 scripts/benchmark.py --corpus-dir \"\(sessionDirectory.path)\" --model tiny.en --build release --json-output /tmp/dexdictate-benchmark.json --csv-output /tmp/dexdictate-benchmark.csv --gate-file benchmark_baseline.json"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        statusMessage = "Benchmark command copied."
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
            statusMessage = "Session ready. Record A1 when you're ready."
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
            statusMessage = "Nothing left to record."
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
                self.statusMessage = "Recording failed to start."
                self.isRecording = false
                return
            }

            self.isRecording = true
            self.statusMessage = "Recording \(prompt.id) — speak now."
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
            statusMessage = "No audio captured for \(prompt.id). Try again."
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
        statusMessage = "Take discarded."
        lastErrorMessage = nil
    }

    private func advanceAfterCapture() {
        if currentIndex + 1 < corpus.count {
            currentIndex += 1
            statusMessage = "Saved. Up next: \(currentPrompt?.id ?? "done")."
        } else {
            currentIndex = corpus.count
            statusMessage = "All \(corpus.count) prompts captured. Open the folder."
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

    private var sectionAccent: Color {
        switch controller.currentPrompt?.section {
        case "General":        return .blue
        case "Punctuation":    return .orange
        case "Commands":       return .purple
        case "Hard Words":     return .red
        case "Voice and Style": return Color(red: 0.2, green: 0.8, blue: 0.7)
        case "Anchor":         return Color(red: 1.0, green: 0.78, blue: 0.1)
        default:               return .cyan
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.10, green: 0.10, blue: 0.14),
                    Color(red: 0.06, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Watermark
            Text("BENCHMARK")
                .font(.system(size: 120, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.025))
                .rotationEffect(.degrees(-28))
                .offset(x: 40, y: 80)
                .allowsHitTesting(false)

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
                    .foregroundStyle(sectionAccent)
                    .frame(width: 36, height: 36)
                    .background(sectionAccent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.easeInOut(duration: 0.3), value: controller.currentPrompt?.section)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Benchmark Capture")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Your voice. Exact prompts. Measurable accuracy.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How it works")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(sectionAccent.opacity(0.85))
                    .tracking(0.6)
                Text("Read each prompt aloud, exactly as written. DexDictate records your voice alongside the reference text, then runs Whisper against both to compute Word Error Rate. Lower WER is better. Run after changing models, devices, or settings — accuracy should be measured, not assumed.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(sectionAccent.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(sectionAccent.opacity(0.18), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.3), value: controller.currentPrompt?.section)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                // Section badge
                if let section = controller.currentPrompt?.section {
                    Text(section.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(sectionAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(sectionAccent.opacity(0.15))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.3), value: section)
                } else {
                    Text("COMPLETE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                // Progress counter
                Text(controller.progressText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            // The prompt text — primary focus
            Text(controller.currentPromptDescription)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Instruction note (when present)
            if let instruction = controller.currentPromptInstructionNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.85))
                        .padding(.top, 1)
                    Text(instruction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Metadata line
            Text(controller.currentPromptDetails)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(sectionAccent.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.3), value: controller.currentPrompt?.section)
    }

    private var meterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Input Level")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(0.6)
                Spacer()
                Text(controller.statusMessage)
                    .font(.caption)
                    .foregroundStyle(controller.isRecording ? .green : .white.opacity(0.6))
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: controller.statusMessage)
            }

            ProgressView(value: controller.inputLevel)
                .tint(controller.isRecording ? .green : .white.opacity(0.3))
                .animation(.linear(duration: 0.05), value: controller.inputLevel)

            HStack {
                Text("–60 dB")
                Spacer()
                Text("0 dB")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.35))

            if let lastErrorMessage = controller.lastErrorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            // Primary record/stop button
            Button(action: controller.startRecordingOrStop) {
                HStack(spacing: 8) {
                    Image(systemName: controller.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.headline)
                    Text(controller.isStarting ? "Starting…" : controller.isRecording ? "Stop & Save" : "Record Prompt")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(controller.isRecording ? Color.orange.opacity(0.5) : Color.green.opacity(0.45))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: (controller.isRecording ? Color.orange : Color.green).opacity(0.3), radius: 5)
            }
            .buttonStyle(.plain)
            .disabled(controller.isStarting || (!controller.isRecording && controller.currentPrompt == nil))

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
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.6)

            Text("Run the benchmark script against the capture folder. It compares each WAV to its reference transcript and reports Word Error Rate per section. A perfect score is 0%. Any number above 5% is worth investigating.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
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
                    .foregroundStyle(.white.opacity(0.3))
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
