# Speech Engine Abstraction — DRAFT (design only)

> **DRAFT / NOT IMPLEMENTED.** This is a design sketch for discussion. No protocol
> in this document exists in app source, and none may be added to production
> DexDictate as part of the current exploration milestone. It changes no
> production behavior. It exists so that *if* benchmarks justify a second engine,
> we already know the shape of the seam.

## Why write this now

The benchmark work raises an obvious question: "if MLX-Audio (or WhisperKit) ever
wins, where would it plug in?" Answering that on paper now keeps the benchmark
tooling honest (we know what we're aiming at) without tempting anyone to refactor
production speech code prematurely. The answer is intentionally narrow.

## Current SwiftWhisper boundary (as-is)

Today `WhisperService` is the concrete, only speech path:

- Production captures microphone audio and resamples to **mono 16 kHz float**.
- `WhisperService` transcribes that audio **batch-after-recording** (not
  streaming) via SwiftWhisper / whisper.cpp.
- The result is transcript text, which is then post-processed and routed by the
  output pipeline (save / copy / paste / insert).

The natural seam is therefore *"mono 16 kHz audio in, transcript text out,"*
which is exactly the SwiftWhisper boundary and exactly the sidecar boundary in
[`MLX_SIDECAR_CONTRACT.md`](MLX_SIDECAR_CONTRACT.md). Everything downstream of the
transcript — and all of audio capture upstream — stays put.

## Proposed protocol (draft)

```swift
protocol DexDictateSpeechEngine {
    func transcribe(audioFile: URL, context: DictationContext) async throws -> TranscriptionResult
}
```

Supporting types (sketch):

```swift
struct DictationContext {
    let modelID: String
    let decodeProfile: DecodeProfile   // existing accuracy / balanced / speed
    let locale: Locale?
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptSegment]  // may be empty
    let isEmpty: Bool                   // engine-asserted empty vs. failure
    let engineLatency: Duration
}
```

Two illustrative conformers (neither built here):

- `WhisperServiceEngine` — wraps the existing `WhisperService`. The reference
  implementation; preserves current behavior bit-for-bit.
- `MLXSidecarEngine` — spawns the subprocess sidecar per the contract, parses the
  JSON, maps errors. Only reachable behind a benchmark/feature flag, never the
  default.

A future `WhisperKitEngine` would be a third conformer with the same boundary.

## Concerns the protocol must address (before any real adoption)

### Future WhisperKit backend
WhisperKit is in-process Swift/CoreML and would conform directly (no subprocess).
The protocol must not bake in subprocess assumptions — hence `audioFile: URL` in,
`TranscriptionResult` out, with no IPC types leaking into the interface.

### Future MLX sidecar backend
Conforms via the subprocess JSON contract. The protocol's `async throws` shape
already accommodates spawn/timeout/parse failures as thrown errors.

### Cancellation
`transcribe` is `async` and must honor Swift task cancellation: a cancelled
dictation must terminate the engine (kill the sidecar, cancel the in-process
job) promptly and throw `CancellationError`. The current batch model makes this
straightforward but it must be explicit per engine.

### Empty output behavior
Empty must be unambiguous. `TranscriptionResult.isEmpty == true` means *the engine
ran and heard nothing* (a valid outcome → no text inserted). A failure to run
must `throw`, never return empty. This distinction protects the output pipeline
from inserting garbage or silently dropping real speech.

### Warm-up
Engines differ: SwiftWhisper loads a `ggml` model; a sidecar pays process spawn +
model load per call; WhisperKit pays CoreML compile on first use. The protocol
should allow an optional `prepare()`/warm-up hook so the first real dictation is
not penalized — but only if benchmarks show cold-start hurts UX.

### Model catalog implications
DexDictate already discovers installed Whisper models from its Models directory.
A second engine has a *different* model namespace (MLX/HF repo ids vs. ggml
files). The catalog/UI would need to represent "engine × model" without implying
cross-engine equivalence, and without silently downloading models.

### Settings migration implications
Any engine selection must default to the current SwiftWhisper path. Existing
users' model/decode-profile settings must keep working unchanged; a new "engine"
setting must be additive and reversible, with a safe fallback if a selected
engine is unavailable on a given machine.

### Why output insertion is outside scope
Output insertion, clipboard delivery, Accessibility insertion, secure-field
suppression, and focus-identity matching are the fragile, high-risk parts of the
app and are explicitly out of scope. The speech-engine seam ends at *transcript
text*. The output pipeline consumes a `String` exactly as it does today and is
unaware of which engine produced it. Keeping the seam this narrow is the whole
point: it lets us evaluate engines without touching the part of the app most
likely to regress.

## Status / next step

This stays a document until the decision gates in
[`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md) are met. The first *code* step, if
ever taken, is a **test-only** adapter — `WhisperServiceEngine` conforming to this
protocol with characterization tests proving identical output — not a live
dictation path change.
