// Benchmark-only WhisperKit transcription tool.
//
// NOT production integration. This executable loads a WhisperKit model once and
// transcribes either a single file or a batch of files (model resident across
// the batch, so per-file latency is "warm" and comparable to the MLX module-mode
// numbers). It emits JSON and exits. It does not touch DexDictate app settings,
// diagnostics, output insertion, the clipboard, or anything in the production
// runtime.
//
// Modes:
//   --audio <file.wav>        Transcribe a single file (JSON to stdout or --out)
//   --audios-file <paths.txt> Transcribe newline-separated paths (model loaded once); requires --out
//   --diagnose                Prewarm/compile investigation: load + N sequential
//                             inferences on a (silent) prewarm clip, each timed, so
//                             the first-inference CoreML compile cost is isolated
//                             from steady-state. Stores only booleans for any
//                             recognized text — never the transcript itself.
//
// Single mode prints (or writes) one JSON object:
//   {"text": "...", "segments": [], "duration_ms": 123, "model": "...", "error": null}
// Batch mode writes one JSON object with a results array.
// Diagnose mode writes one JSON object with inferences_ms[] and timing fields (no transcript text).
import CoreML
import Foundation
import WhisperKit

let help = """
whisperkit-transcribe (benchmark-only)
  --audio <file.wav>        Transcribe a single file (JSON to stdout or --out)
  --audios-file <paths.txt> Transcribe newline-separated paths (model loaded once); requires --out
  --diagnose                Prewarm/compile diagnostics (requires --prewarm-audio)
  --prewarm-audio <file>    Silent/synthetic clip used for diagnose-mode inferences
  --real-audio <file>       Optional real clip transcribed once AFTER prewarm (timing only)
  --inferences <n>          Diagnose: number of sequential inferences (default 3)
  --compute-units <u>       ane | gpu | cpu | all (default: WhisperKit default)
  --config-prewarm          Set WhisperKitConfig(prewarm: true) to move CoreML
                            specialization into model load (load-unload-load)
  --no-config-prewarm       Set WhisperKitConfig(prewarm: false) explicitly
  --dummy-decode            Diagnose: run ONE silent decode right after load (the
                            prep step) before timing the first real clip. Order is
                            [dummy] -> [real clip] -> [warm inferences].
  --model <name>            WhisperKit model id (default: openai_whisper-tiny)
  --download-base <dir>     Where WhisperKit caches CoreML models (default: artifacts/whisperkit-models)
  --out <file>              Write JSON here instead of stdout (avoids stdout log contamination)
  -h, --help                Show this help
"""

func stderrLine(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

func fail(_ msg: String) -> Never {
    stderrLine(msg)
    exit(2)
}

var audio: String?
var audiosFile: String?
var prewarmAudio: String?
var realAudio: String?
var diagnose = false
var inferences = 3
var computeUnitsArg: String?
var configPrewarm: Bool?
var dummyDecode = false
var model = "openai_whisper-tiny"
var downloadBase = "artifacts/whisperkit-models"
var outPath: String?

let argv = CommandLine.arguments
var i = 1
while i < argv.count {
    switch argv[i] {
    case "--audio": i += 1; audio = i < argv.count ? argv[i] : nil
    case "--audios-file": i += 1; audiosFile = i < argv.count ? argv[i] : nil
    case "--prewarm-audio": i += 1; prewarmAudio = i < argv.count ? argv[i] : nil
    case "--real-audio": i += 1; realAudio = i < argv.count ? argv[i] : nil
    case "--diagnose": diagnose = true
    case "--inferences": i += 1; inferences = i < argv.count ? (Int(argv[i]) ?? 3) : 3
    case "--compute-units": i += 1; computeUnitsArg = i < argv.count ? argv[i] : nil
    case "--config-prewarm": configPrewarm = true
    case "--no-config-prewarm": configPrewarm = false
    case "--dummy-decode": dummyDecode = true
    case "--model": i += 1; model = i < argv.count ? argv[i] : model
    case "--download-base": i += 1; downloadBase = i < argv.count ? argv[i] : downloadBase
    case "--out": i += 1; outPath = i < argv.count ? argv[i] : nil
    case "-h", "--help": print(help); exit(0)
    default: fail("unknown argument: \(argv[i])")
    }
    i += 1
}

func jsonString(_ obj: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
          let str = String(data: data, encoding: .utf8) else {
        return "{\"error\":\"json serialization failed\"}"
    }
    return str
}

func emit(_ s: String) {
    if let outPath {
        try? s.write(toFile: outPath, atomically: true, encoding: .utf8)
    } else {
        print(s)
    }
}

func nullable(_ s: String?) -> Any { s.map { $0 as Any } ?? NSNull() }

func computeUnits(_ raw: String) -> MLComputeUnits {
    switch raw.lowercased() {
    case "cpu": return .cpuOnly
    case "gpu": return .cpuAndGPU
    case "ane", "neural", "ne": return .cpuAndNeuralEngine
    case "all": return .all
    default: return .cpuAndNeuralEngine
    }
}

let downloadBaseURL = URL(fileURLWithPath: downloadBase, isDirectory: true)
try? FileManager.default.createDirectory(at: downloadBaseURL, withIntermediateDirectories: true)

// Detect whether the model variant is already present on disk BEFORE loading, so
// the diagnostics can distinguish "cold download" from "downloaded-but-uncompiled".
let modelDir = downloadBaseURL.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(model)")
let alreadyDownloaded = FileManager.default.fileExists(atPath: modelDir.path)

// Build optional compute-unit override (the suspected first-inference compile driver).
var computeOptions: ModelComputeOptions?
if let computeUnitsArg {
    let units = computeUnits(computeUnitsArg)
    computeOptions = ModelComputeOptions(audioEncoderCompute: units, textDecoderCompute: units)
}

// Load the model once. Any failure here is reported as a structured error and a
// non-zero exit, never a silent empty result.
let loadStart = Date()
let pipe: WhisperKit
do {
    let config = WhisperKitConfig(
        model: model,
        downloadBase: downloadBaseURL,
        computeOptions: computeOptions,
        verbose: false,
        logLevel: .error,
        prewarm: configPrewarm
    )
    pipe = try await WhisperKit(config)
} catch {
    let message = "WhisperKit unavailable: \(error)"
    if diagnose {
        emit(jsonString(["mode": "diagnose", "model": model, "download_base": downloadBase,
                         "model_already_downloaded": alreadyDownloaded, "error": message]))
    } else if audiosFile != nil {
        emit(jsonString(["model": model, "model_load_ms": 0, "download_base": downloadBase,
                         "results": [], "error": message]))
    } else {
        emit(jsonString(["text": "", "segments": [], "duration_ms": 0, "model": model, "error": message]))
    }
    exit(3)
}
let modelLoadMs = Date().timeIntervalSince(loadStart) * 1000.0

func transcribeOne(_ path: String) async -> (text: String, ms: Double, error: String?) {
    let start = Date()
    do {
        let results = try await pipe.transcribe(audioPath: path)
        let text = results.map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, Date().timeIntervalSince(start) * 1000.0, nil)
    } catch {
        return ("", Date().timeIntervalSince(start) * 1000.0, "transcribe failed: \(error)")
    }
}

if diagnose {
    guard let prewarmAudio else { fail("--diagnose requires --prewarm-audio") }
    var diagError: String?

    // Prep sequence is strictly ordered so the first REAL clip's latency reflects
    // exactly the prep that preceded it:
    //   stage 1: model load (config prewarm happens here if enabled, above)
    //   stage 2: optional ONE silent dummy decode (the prep probe)
    //   stage 3: first real public clip (the key user-facing measurement)
    //   stage 4: warm silent inferences (steady-state)

    // Stage 2 — silent dummy decode (only when requested).
    var dummyMs: Double?
    var dummyEmpty = true
    if dummyDecode {
        let (text, ms, err) = await transcribeOne(prewarmAudio)
        dummyMs = ms
        dummyEmpty = text.isEmpty  // privacy: store only the boolean
        if err != nil { diagError = err }
    }

    // Stage 3 — first real clip after prep.
    var realMs: Double?
    var realEmpty: Bool?
    if let realAudio {
        let (text, ms, err) = await transcribeOne(realAudio)
        realMs = ms
        realEmpty = text.isEmpty  // privacy: boolean only
        if err != nil, diagError == nil { diagError = err }
    }

    // Stage 4 — warm steady-state silent inferences (may be 0).
    var inferenceMs: [Double] = []
    var warmEmpty = true
    for _ in 0 ..< max(0, inferences) {
        let (text, ms, err) = await transcribeOne(prewarmAudio)
        inferenceMs.append(ms)
        if !text.isEmpty { warmEmpty = false }  // privacy: boolean only
        if err != nil, diagError == nil { diagError = err }
    }

    var obj: [String: Any] = [
        "mode": "diagnose",
        "model": model,
        "download_base": downloadBase,
        "compute_units": computeUnitsArg ?? "default",
        "config_prewarm": configPrewarm.map { $0 as Any } ?? "default",
        "dummy_decode": dummyDecode,
        "model_already_downloaded": alreadyDownloaded,
        "model_load_ms": modelLoadMs,
        // WhisperKit's own timing split: prewarm specialization vs. model loading.
        "whisperkit_prewarm_load_ms": pipe.currentTimings.prewarmLoadTime * 1000.0,
        "whisperkit_model_loading_ms": pipe.currentTimings.modelLoading * 1000.0,
        "model_state": "\(pipe.modelState)",
        "dummy_decode_ms": dummyMs.map { $0 as Any } ?? NSNull(),
        "dummy_decode_output_empty": dummyDecode ? (dummyEmpty as Any) : NSNull(),
        "inferences_ms": inferenceMs,
        "warm_output_empty": warmEmpty,
        "error": nullable(diagError),
    ]
    if let realMs {
        obj["real_after_prep_ms"] = realMs
        obj["real_after_prewarm_ms"] = realMs  // back-compat key for existing parsers
        obj["real_after_prep_output_empty"] = realEmpty ?? true
    }
    emit(jsonString(obj))
    exit(diagError == nil ? 0 : 4)
} else if let audiosFile {
    guard outPath != nil else { fail("--audios-file requires --out") }
    let content = (try? String(contentsOfFile: audiosFile, encoding: .utf8)) ?? ""
    let paths = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    var resultsArray: [[String: Any]] = []
    for path in paths {
        let (text, ms, err) = await transcribeOne(path)
        resultsArray.append([
            "audio_path": path,
            "text": text,
            "duration_ms": ms,
            "error": nullable(err),
        ])
    }
    emit(jsonString([
        "model": model,
        "model_load_ms": modelLoadMs,
        "download_base": downloadBase,
        "results": resultsArray,
        "error": NSNull(),
    ]))
    exit(0)
} else if let audio {
    let (text, ms, err) = await transcribeOne(audio)
    emit(jsonString([
        "text": text,
        "segments": [],
        "duration_ms": ms,
        "model": model,
        "error": nullable(err),
    ]))
    exit(err == nil ? 0 : 4)
} else {
    fail("provide --audio, --audios-file, or --diagnose (see --help)")
}
