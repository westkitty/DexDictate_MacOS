#!/usr/bin/env python3
"""Experimental MLX-Audio subprocess wrapper for DexDictate benchmark exploration.

THIS IS NOT PRODUCTION INTEGRATION. It exists to prove a single, testable
subprocess JSON contract:

    mlx_transcribe_wrapper.py --audio /path/to/file.wav --model <model-id>

On success it prints a JSON object to stdout:

    {"text": "...", "segments": [], "duration_ms": 1234, "model": "<model-id>"}

If MLX-Audio is unavailable (no module importable), or transcription fails, it
prints a JSON object with a non-empty "error" field and exits non-zero:

    {"text": "", "segments": [], "duration_ms": 0, "model": "<model-id>",
     "error": "MLX-Audio unavailable: <explanation>"}

Constraints honored by design:
  * Reads only --audio and --model.
  * Returns JSON on stdout; diagnostics go to stderr.
  * Never starts a server or daemon.
  * Never touches DexDictate app settings or diagnostics.
  * One audio file in, one JSON object out, then exits.
"""
import argparse
import importlib.util
import json
import sys
import time


def emit(payload, exit_code):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()
    return exit_code


def main():
    parser = argparse.ArgumentParser(description="Experimental MLX-Audio transcription wrapper")
    parser.add_argument("--audio", required=True, help="Path to a wav file")
    parser.add_argument("--model", default="mlx-community/whisper-tiny", help="MLX model id")
    args = parser.parse_args()

    base = {"text": "", "segments": [], "duration_ms": 0, "model": args.model}

    if importlib.util.find_spec("mlx_whisper") is None:
        return emit(
            {**base, "error": "MLX-Audio unavailable: mlx_whisper is not importable by this interpreter"},
            3,
        )

    try:
        import mlx_whisper  # type: ignore
    except Exception as error:  # noqa: BLE001
        return emit({**base, "error": f"MLX-Audio unavailable: import failed ({error})"}, 3)

    started = time.perf_counter()
    try:
        result = mlx_whisper.transcribe(args.audio, path_or_hf_repo=args.model)
    except Exception as error:  # noqa: BLE001
        return emit({**base, "error": f"MLX-Audio transcription failed: {error}"}, 4)
    duration_ms = (time.perf_counter() - started) * 1000.0

    text = result.get("text", "") if isinstance(result, dict) else str(result)
    segments = result.get("segments", []) if isinstance(result, dict) else []
    return emit(
        {
            "text": (text or "").strip(),
            "segments": segments,
            "duration_ms": round(duration_ms, 3),
            "model": args.model,
            "error": None,
        },
        0,
    )


if __name__ == "__main__":
    raise SystemExit(main())
