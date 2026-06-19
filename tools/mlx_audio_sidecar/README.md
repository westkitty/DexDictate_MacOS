# MLX-Audio Sidecar (experimental)

This directory contains an **experimental** subprocess wrapper used only for
speech-engine benchmark exploration. It is **not** wired into DexDictate's
production dictation path, and must not be.

## What this is

`mlx_transcribe_wrapper.py` is a one-shot subprocess that:

- accepts `--audio <file.wav>` and `--model <model-id>`,
- transcribes once via a locally installed `mlx_whisper`,
- prints a single JSON object to stdout, and
- exits.

It is the smallest possible "sidecar contract" — a child process invoked per
file, communicating over stdout JSON. See
[`docs/speech_engine_exploration/MLX_SIDECAR_CONTRACT.md`](../../docs/speech_engine_exploration/MLX_SIDECAR_CONTRACT.md)
for the rationale and the longer-term graduation path (Unix domain socket / XPC).

## What this is NOT

- Not a server or daemon. It transcribes one file and exits.
- Not a LaunchAgent.
- Does not read or write DexDictate settings or diagnostics.
- Does not touch output insertion, the clipboard, or Accessibility.

## Contract

Request (argv):

```
mlx_transcribe_wrapper.py --audio /abs/path/file.wav --model mlx-community/whisper-tiny
```

Success response (stdout):

```json
{"text": "recognized transcript", "segments": [], "duration_ms": 1234, "model": "mlx-community/whisper-tiny", "error": null}
```

Error response (stdout, non-zero exit):

```json
{"text": "", "segments": [], "duration_ms": 0, "model": "mlx-community/whisper-tiny", "error": "MLX-Audio unavailable: mlx_whisper is not importable by this interpreter"}
```

## Using it with the benchmark

The benchmark script appends `--audio`/`--model` to whatever
`DEXDICTATE_MLX_AUDIO_CMD` names, so point it at this wrapper. Use the
`.venv_mlx_audio` interpreter so `mlx_whisper` is importable:

```bash
# Dry run (no transcription, just plan + backend status)
DEXDICTATE_MLX_AUDIO_CMD="$(pwd)/.venv_mlx_audio/bin/python $(pwd)/tools/mlx_audio_sidecar/mlx_transcribe_wrapper.py" \
  python3 scripts/benchmark_mlx_audio.py \
    --dry-run \
    --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \
    --model mlx-community/whisper-tiny \
    --output-dir artifacts/mlx-audio/wrapper-dry-run

# 5-file smoke test (requires .venv_mlx_audio with mlx-whisper installed)
DEXDICTATE_MLX_AUDIO_CMD="$(pwd)/.venv_mlx_audio/bin/python $(pwd)/tools/mlx_audio_sidecar/mlx_transcribe_wrapper.py" \
  python3 scripts/benchmark_mlx_audio.py \
    --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \
    --model mlx-community/whisper-tiny \
    --limit 5 \
    --output-dir artifacts/mlx-audio/smoke-5
```
