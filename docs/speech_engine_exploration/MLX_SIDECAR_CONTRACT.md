# MLX-Audio Sidecar Contract (experimental)

Status: **exploration only.** Nothing described here is wired into production
DexDictate dictation, and nothing here may change output insertion, the
clipboard, Accessibility insertion, secure-field handling, focus matching,
audio route recovery, signing, packaging, or the default model.

## What a "sidecar" means in DexDictate

A sidecar is a *separate, non-privileged helper process* that performs speech-to-text
on behalf of the app, communicating over a narrow, explicit contract. The app
remains the owner of audio capture, post-processing, and output. The sidecar only
turns audio into text. It never touches the user's focused field, the clipboard,
or app settings.

For DexDictate the boundary is deliberately small and matches the existing
SwiftWhisper boundary:

- **Input:** a path to a mono 16 kHz PCM WAV file (the same shape the production
  resampler already produces).
- **Output:** transcript text (plus optional segment metadata and timing).

Everything outside that — focus identity, secure-field suppression, paste vs.
insert, route recovery — stays in the app and is out of scope.

## Why subprocess JSON comes before localhost HTTP

The first viable sidecar is the cheapest one that can be reasoned about:

- **Subprocess JSON** (this contract): one child process per request, arguments
  in, one JSON object out on stdout, then exit. No open ports, no listening
  socket, no lifecycle to manage, nothing to leak, nothing to authenticate.
  Trivially sandboxable and trivially killable (timeout + SIGKILL).
- **Localhost HTTP** would introduce a persistent listening server, a port, an
  auth story, a lifecycle, and a new network-surface review — all for no benefit
  at the benchmark stage. DexDictate's product shape is local-first and
  server-free; a localhost daemon is the *opposite* of that default and must be
  justified, not assumed.

So the ladder is: **subprocess JSON → (only if warranted) Unix domain socket /
XPC helper → (almost never) localhost HTTP.**

## Environment note (which interpreter runs the sidecar)

- In this repo environment, the default `python3` is **Python 3.14**.
- The MLX benchmark tooling currently requires **`python3.13`** (MLX wheels are
  not published for 3.14 yet).
- The isolated MLX environment is **`.venv_mlx_audio`** (created by
  `scripts/setup_mlx_audio_env.sh`).
- Run the sidecar wrapper with **`.venv_mlx_audio/bin/python`**, not the system
  `python3` — e.g. set
  `DEXDICTATE_MLX_AUDIO_CMD="$(pwd)/.venv_mlx_audio/bin/python $(pwd)/tools/mlx_audio_sidecar/mlx_transcribe_wrapper.py"`.
- `.venv_mlx_audio/` is git-ignored via `.venv*/`; benchmark artifacts go under
  `artifacts/`, which is also git-ignored.

## Request / response JSON

Request is argv, not a body:

```
<wrapper> --audio /abs/path/clip.wav --model <model-id>
```

Success response (stdout, exit 0):

```json
{
  "text": "recognized transcript",
  "segments": [],
  "duration_ms": 1234,
  "model": "model-id",
  "error": null
}
```

The benchmark harness also accepts a bare transcript string on stdout, and a JSON
object using `text`, `transcript`, or `result`, or a `segments[]` array of
`{ "text": ... }`. New sidecars should emit the canonical object above.

Error response (stdout, non-zero exit):

```json
{
  "text": "",
  "segments": [],
  "duration_ms": 0,
  "model": "requested model",
  "error": "MLX-Audio unavailable: explanation"
}
```

## Timeout behavior

- The caller owns the timeout (`--timeout-seconds`, default 120s per file).
- On timeout the caller terminates the child and records a per-file error; it
  never blocks dictation or the UI. A hung sidecar must be survivable.
- The sidecar itself does no retry loop; it transcribes once and exits.

## Error behavior

- The sidecar must **always** emit a JSON object, even on failure, and use a
  non-empty `error` string plus a non-zero exit code.
- Missing backend (module not importable), model-load failure, and transcription
  failure are distinct, explainable error strings — never a silent empty result.
- The benchmark harness treats any non-zero exit or `error` as a failed file and
  excludes it from WER/latency aggregates, while still recording it.

## Transcript privacy rules

- Recognized text and reference text are written **only** to explicit benchmark
  result files under the chosen `--output-dir` (which is git-ignored under
  `artifacts/`).
- No raw transcript is ever written to the app's normal diagnostics/logging.
- The sidecar writes transcripts to stdout (consumed by the harness) and nowhere
  else; it does not persist files itself.

## Model cache rules

- Models resolve through the MLX / Hugging Face local cache
  (`~/.cache/huggingface`). First use of a new model downloads it; subsequent
  runs are offline against the cache.
- A production path must **never** download a model silently. Any future
  integration must surface model download/size to the user and let them choose,
  consistent with the existing Whisper model-discovery flow.
- Benchmarks must report whether a run was cold (download) or warm (cached).

## No-cloud requirement

- The sidecar must run fully local. No request may leave the machine except the
  one-time, user-understood model download from the model host.
- A sidecar that requires a network API call at transcription time is rejected
  outright — it violates DexDictate's local-first contract.

## When to graduate to a Unix domain socket or XPC helper

Move past per-request subprocess only when *all* of these hold:

- Benchmarks justify keeping MLX (see the decision gates in
  [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md)).
- Per-request process spawn + model warm-up cost is shown to dominate latency,
  i.e. a persistent warm process measurably wins.
- There is a concrete need for cancellation/streaming that argv-in/JSON-out
  cannot express.

At that point the right shape is a **Unix domain socket or an XPC service** (a
macOS-native, sandbox-friendly IPC the app can own and lifecycle), *not* a TCP
localhost server.

## Why a LaunchAgent is deferred

A LaunchAgent means a background process that the system keeps alive across app
launches. That is a packaging, permissions, update, and trust burden, and it
contradicts the "no persistent service" constraint. It is only worth considering
if a warm helper proves necessary *and* per-session spawning is shown to be the
bottleneck — neither is established. Until then, no LaunchAgent.

## Why production app integration is still blocked

- MLX-Audio has not been benchmarked on this corpus/machine yet (the wrapper +
  module path exist and the contract is proven; numbers are pending a local
  environment).
- The decision gates in [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md) have not
  been met.
- The production output pipeline is explicitly fragile and out of scope; an
  engine swap cannot ride along with it.
- The correct next step after promising numbers is a **test-only** speech-engine
  adapter boundary (see
  [`SPEECH_ENGINE_ABSTRACTION_DRAFT.md`](SPEECH_ENGINE_ABSTRACTION_DRAFT.md)),
  not a live dictation path change.
