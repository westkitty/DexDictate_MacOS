// Benchmark-only streaming-ASR tool for soniqo/speech-swift ParakeetStreamingASR.
//
// NOT production integration. Loads the Parakeet EOU streaming model once and
// runs one file or a batch of files through a streaming session, recording
// streaming-specific metrics (first-partial latency, partial count, EOU timing,
// final-vs-last-partial divergence, final latency). Emits JSON and exits. Touches
// nothing in the DexDictate production runtime.
//
// Privacy: by default the recognized transcript text is written ONLY into the
// --out JSON file (which lives under the git-ignored artifacts/ tree, exactly like
// the WhisperKit/MLX lanes) so the Python driver can score WER with the shared
// normalization. Transcripts are NEVER printed to stdout/stderr unless
// --print-transcripts is passed, and --no-store-transcripts suppresses text in the
// file entirely (privacy-max; disables WER scoring).
//
// Usage:
//   speech-swift-benchmark --audio <file.wav> --out <file.json> [options]
//   speech-swift-benchmark --audios-file <paths.txt> --out <file.json> [options]
import AudioCommon
import Foundation
import ParakeetStreamingASR

let help = """
speech-swift-benchmark (benchmark-only, streaming ASR)
  --audio <file.wav>        Transcribe a single file
  --audios-file <paths.txt> Transcribe newline-separated wav paths (model loaded once)
  --out <file.json>         Write JSON results here (required)
  --model <hf-id>           Model id (default: aufklarer/Parakeet-EOU-120M-CoreML-INT8)
  --chunk-ms <n>            Streaming chunk size in ms (default: model config)
  --warmup                  Run one silent warmup decode before timing
  --no-store-transcripts    Do not store recognized text in the JSON (disables WER)
  --print-transcripts       DEBUG: also print recognized text to stderr
  -h, --help                Show this help
"""

func stderrLine(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
func fail(_ msg: String) -> Never { stderrLine(msg); exit(2) }

var audio: String?
var audiosFile: String?
var outPath: String?
var modelId: String?
var chunkMsOverride: Int?
var warmup = false
var storeTranscripts = true
var printTranscripts = false

let argv = CommandLine.arguments
var i = 1
while i < argv.count {
    switch argv[i] {
    case "--audio": i += 1; audio = i < argv.count ? argv[i] : nil
    case "--audios-file": i += 1; audiosFile = i < argv.count ? argv[i] : nil
    case "--out": i += 1; outPath = i < argv.count ? argv[i] : nil
    case "--model": i += 1; modelId = i < argv.count ? argv[i] : nil
    case "--chunk-ms": i += 1; chunkMsOverride = i < argv.count ? Int(argv[i]) : nil
    case "--warmup": warmup = true
    case "--no-store-transcripts": storeTranscripts = false
    case "--print-transcripts": printTranscripts = true
    case "-h", "--help": print(help); exit(0)
    default: fail("unknown argument: \(argv[i])")
    }
    i += 1
}

guard let outPath else { fail("--out <file.json> is required") }

func jsonString(_ obj: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted]),
          let str = String(data: data, encoding: .utf8) else { return "{\"error\":\"json serialization failed\"}" }
    return str
}

func writeOut(_ obj: Any) {
    try? (jsonString(obj) + "\n").write(toFile: outPath, atomically: true, encoding: .utf8)
}

func nullable(_ s: String?) -> Any { s.map { $0 as Any } ?? NSNull() }
func nullable(_ d: Double?) -> Any { d.map { $0 as Any } ?? NSNull() }

// --- Load model once (this triggers download + CoreML load). ----------------
let loadStart = Date()
let model: ParakeetStreamingASRModel
do {
    model = try await ParakeetStreamingASRModel.fromPretrained(modelId: modelId)
} catch {
    writeOut([
        "backend": "speech-swift",
        "product": "ParakeetStreamingASR",
        "model": modelId ?? ParakeetStreamingASRModel.defaultModelId,
        "error": "model load failed: \(error)",
        "results": [],
    ])
    fail("model load failed: \(error)")
}
let modelLoadMs = Date().timeIntervalSince(loadStart) * 1000.0
let modelSampleRate = model.config.sampleRate
let chunkMs = chunkMsOverride ?? model.config.streaming.chunkMs

if warmup {
    // Silent warmup decode (1s of zeros) to absorb first-inference specialization.
    let silent = [Float](repeating: 0, count: modelSampleRate)
    if let session = try? model.createSession() {
        _ = try? session.pushAudio(silent)
        _ = try? session.finalize()
    }
}

struct ClipResult {
    var audioPath: String
    var audioSeconds: Double
    var firstPartialMs: Double?
    var finalMs: Double
    var numPartials: Int
    var numSegments: Int
    var eouDetected: Bool
    var eouMs: Double?
    var finalDiffersFromLastPartial: Bool
    var emptyOutput: Bool
    var text: String
    var error: String?
}

func benchmarkClip(_ path: String) -> ClipResult {
    var r = ClipResult(audioPath: path, audioSeconds: 0, firstPartialMs: nil, finalMs: 0,
                       numPartials: 0, numSegments: 0, eouDetected: false, eouMs: nil,
                       finalDiffersFromLastPartial: false, emptyOutput: true, text: "", error: nil)
    let url = URL(fileURLWithPath: path)
    let loaded: (samples: [Float], sampleRate: Int)
    do { loaded = try AudioFileLoader.loadWAV(url: url) }
    catch { r.error = "wav load failed: \(error)"; return r }

    var samples = loaded.samples
    if loaded.sampleRate != modelSampleRate {
        samples = AudioFileLoader.resample(samples, from: loaded.sampleRate, to: modelSampleRate)
    }
    r.audioSeconds = Double(samples.count) / Double(modelSampleRate)

    let session: StreamingSession
    do { session = try model.createSession() } catch { r.error = "createSession failed: \(error)"; return r }

    let chunkSamples = max(1, chunkMs * modelSampleRate / 1000)
    let t0 = Date()
    var lastPartialText = ""
    var finalSegments: [String] = []

    func consume(_ partials: [ParakeetStreamingASRModel.PartialTranscript]) {
        let now = Date().timeIntervalSince(t0) * 1000.0
        for p in partials {
            r.numPartials += 1
            if r.firstPartialMs == nil, !p.text.isEmpty { r.firstPartialMs = now }
            if p.eouDetected, r.eouMs == nil { r.eouDetected = true; r.eouMs = now }
            if p.isFinal { r.numSegments += 1; finalSegments.append(p.text) }
            else { lastPartialText = p.text }
        }
    }

    var offset = 0
    do {
        while offset < samples.count {
            let end = min(offset + chunkSamples, samples.count)
            consume(try session.pushAudio(Array(samples[offset..<end])))
            offset = end
        }
        consume(try session.finalize())
    } catch {
        r.error = "streaming failed: \(error)"
        r.finalMs = Date().timeIntervalSince(t0) * 1000.0
        return r
    }
    r.finalMs = Date().timeIntervalSince(t0) * 1000.0

    let joined = finalSegments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    r.text = joined.isEmpty ? lastPartialText.trimmingCharacters(in: .whitespacesAndNewlines) : joined
    r.emptyOutput = r.text.isEmpty
    func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " } }
    r.finalDiffersFromLastPartial = norm(r.text) != norm(lastPartialText)
    if printTranscripts { stderrLine("[transcript] \(path): \(r.text)") }
    return r
}

func resultDict(_ r: ClipResult) -> [String: Any] {
    var d: [String: Any] = [
        "audio_path": r.audioPath,
        "audio_seconds": r.audioSeconds,
        "first_partial_ms": nullable(r.firstPartialMs),
        "final_ms": r.finalMs,
        "num_partials": r.numPartials,
        "num_segments": r.numSegments,
        "eou_detected": r.eouDetected,
        "eou_ms": nullable(r.eouMs),
        "final_differs_from_last_partial": r.finalDiffersFromLastPartial,
        "empty_output": r.emptyOutput,
        "error": nullable(r.error),
    ]
    if storeTranscripts { d["text"] = r.text }
    return d
}

var paths: [String] = []
if let audio { paths = [audio] }
else if let audiosFile {
    let content = (try? String(contentsOfFile: audiosFile, encoding: .utf8)) ?? ""
    paths = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
} else { fail("provide --audio or --audios-file") }

var results: [[String: Any]] = []
var processed = 0
var failed = 0
for path in paths {
    let r = benchmarkClip(path)
    results.append(resultDict(r))
    if r.error == nil { processed += 1 } else { failed += 1 }
}

writeOut([
    "backend": "speech-swift",
    "product": "ParakeetStreamingASR",
    "streaming": true,
    "experimental": true,
    "production_path_changed": false,
    "model": modelId ?? ParakeetStreamingASRModel.defaultModelId,
    "model_load_ms": modelLoadMs,
    "model_sample_rate": modelSampleRate,
    "chunk_ms": chunkMs,
    "stored_transcripts": storeTranscripts,
    "audio_count": paths.count,
    "processed_count": processed,
    "failed_count": failed,
    "results": results,
    "error": NSNull(),
])
stderrLine("SPEECH_SWIFT_DONE files=\(paths.count) processed=\(processed) failed=\(failed) load_ms=\(Int(modelLoadMs))")
