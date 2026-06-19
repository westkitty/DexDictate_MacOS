#!/usr/bin/env python3
"""Benchmark MLX-Audio speech-to-text against a DexDictate benchmark corpus.

This is exploration/benchmark tooling ONLY. It does not import or touch any
DexDictate production code, output insertion, clipboard, or settings. Transcript
text (recognized and reference) is written exclusively to explicit benchmark
result files under the chosen --output-dir. Nothing here logs raw transcripts to
the app's normal diagnostics.

Two execution modes are supported:

  wrapper        Invoke an external command named by DEXDICTATE_MLX_AUDIO_CMD.
                 If the command template contains an "{audio}" placeholder it is
                 substituted (legacy template form, "{model}" optional). Otherwise
                 the command is treated as a base executable and called as:
                     <cmd> --audio <file.wav> --model <model>
                 The command may return plain transcript text on stdout, or a JSON
                 object with at least a "text" field (optionally "segments",
                 "duration_ms", "model").

  python-module  Transcribe in-process via a locally installed MLX module
                 (mlx_whisper preferred, then mlx_audio). Only available when the
                 interpreter running this script can import that module, i.e. when
                 invoked with the .venv_mlx_audio interpreter.

  auto           Prefer wrapper when DEXDICTATE_MLX_AUDIO_CMD is set, otherwise
                 fall back to python-module if a module is importable, otherwise
                 report a clear skipped/unavailable state.
"""
import argparse
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import time
import wave
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "2026-06-18"
MODULE_CANDIDATES = ("mlx_whisper", "mlx_audio")


# --------------------------------------------------------------------------- #
# Text scoring helpers (benchmark-only; identical normalization to benchmark.py)
# --------------------------------------------------------------------------- #
def normalize_words(text):
    text = (text or "").lower()
    text = re.sub(r"[^\w\s]", "", text)
    return text.split()


def tokenize_punctuation_aware(text):
    """Lowercase, but keep punctuation marks as their own tokens so that
    punctuation differences are penalized."""
    text = (text or "").lower()
    return re.findall(r"\w+|[^\w\s]", text)


def _edit_distance_rate(ref_tokens, hyp_tokens):
    if not ref_tokens:
        return float("inf") if hyp_tokens else 0.0
    prev = list(range(len(hyp_tokens) + 1))
    for i in range(1, len(ref_tokens) + 1):
        curr = [i] + [0] * len(hyp_tokens)
        for j in range(1, len(hyp_tokens) + 1):
            cost = 0 if ref_tokens[i - 1] == hyp_tokens[j - 1] else 1
            curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
        prev = curr
    return prev[len(hyp_tokens)] / len(ref_tokens)


def compute_wer(reference, hypothesis):
    return _edit_distance_rate(normalize_words(reference), normalize_words(hypothesis))


def compute_punctuation_aware_wer(reference, hypothesis):
    return _edit_distance_rate(
        tokenize_punctuation_aware(reference), tokenize_punctuation_aware(hypothesis)
    )


def proper_noun_hits(reference, hypothesis):
    """Proxy: capitalized tokens in the reference (excluding the sentence-initial
    word) and whether each appears in the hypothesis (case-insensitive)."""
    if not reference:
        return {}
    hyp_lower = set(normalize_words(hypothesis))
    words = re.findall(r"[A-Za-z][A-Za-z'-]*", reference)
    hits = {}
    for index, word in enumerate(words):
        if index == 0:
            continue
        if word[0].isupper():
            key = re.sub(r"[^\w]", "", word.lower())
            if key:
                hits[word] = key in hyp_lower
    return hits


def boundary_word(words, last=False):
    return words[-1] if (last and words) else (words[0] if words else None)


# --------------------------------------------------------------------------- #
# Corpus / manifest loading
# --------------------------------------------------------------------------- #
def _items_from_list(entries, base):
    items = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        if entry.get("include_in_scoring", True) is False:
            continue
        file_name = entry.get("file")
        expected = entry.get("expected")
        if not file_name or expected is None:
            continue
        items.append(
            {
                "file_name": file_name,
                "audio_path": (base / file_name),
                "expected": expected,
                "id": entry.get("id"),
                "category": entry.get("category"),
                "source": entry.get("source"),
            }
        )
    return items


def _items_from_map(mapping, base):
    return [
        {
            "file_name": name,
            "audio_path": (base / name),
            "expected": expected,
            "id": None,
            "category": None,
            "source": None,
        }
        for name, expected in sorted(mapping.items())
    ]


def load_manifest_file(manifest_path, base):
    data = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    if isinstance(data, dict):
        return _items_from_map(data, base)
    if isinstance(data, list):
        return _items_from_list(data, base)
    raise ValueError(
        "manifest JSON must be a filename->text map or a list of entries with file/expected"
    )


def load_corpus(corpus_dir, manifest):
    corpus = Path(corpus_dir)
    if manifest:
        manifest_path = Path(manifest)
        if not manifest_path.is_absolute():
            manifest_path = corpus / manifest
        if not manifest_path.is_file():
            raise FileNotFoundError(f"Manifest not found: {manifest_path}")
        return load_manifest_file(manifest_path, corpus)

    transcripts = corpus / "transcripts.json"
    if not transcripts.is_file():
        raise FileNotFoundError(f"Corpus transcripts not found: {transcripts}")
    return load_manifest_file(transcripts, corpus)


def wav_duration_seconds(path):
    try:
        with wave.open(str(path), "rb") as handle:
            rate = handle.getframerate()
            frames = handle.getnframes()
            return frames / rate if rate else None
    except (wave.Error, OSError):
        return None


# --------------------------------------------------------------------------- #
# Backend resolution
# --------------------------------------------------------------------------- #
def configured_command_template():
    template = os.environ.get("DEXDICTATE_MLX_AUDIO_CMD", "").strip()
    return template or None


def detected_modules():
    return [name for name in MODULE_CANDIDATES if importlib.util.find_spec(name) is not None]


def resolve_backend(requested_mode, command_template, modules):
    """Return (mode, status, reason). status is 'ok', 'skipped', or 'unavailable'."""
    if requested_mode == "wrapper":
        if command_template:
            return "wrapper", "ok", None
        return "wrapper", "skipped", "DEXDICTATE_MLX_AUDIO_CMD is not set"
    if requested_mode == "python-module":
        if modules:
            return "python-module", "ok", None
        return (
            "python-module",
            "unavailable",
            "no local MLX module is importable by this interpreter "
            "(expected mlx_whisper or mlx_audio); run under .venv_mlx_audio",
        )
    # auto
    if command_template:
        return "wrapper", "ok", None
    if modules:
        return "python-module", "ok", None
    return (
        "auto",
        "unavailable",
        "neither DEXDICTATE_MLX_AUDIO_CMD nor a local MLX module is available",
    )


# --------------------------------------------------------------------------- #
# Transcription
# --------------------------------------------------------------------------- #
def render_wrapper_command(template, audio_path, model):
    if "{audio}" in template:
        rendered = template.replace("{audio}", str(audio_path)).replace("{model}", model)
        return shlex.split(rendered)
    return shlex.split(template) + ["--audio", str(audio_path), "--model", model]


def extract_transcript(stdout):
    stripped = (stdout or "").strip()
    if not stripped:
        return ""
    try:
        decoded = json.loads(stripped)
    except json.JSONDecodeError:
        return stripped
    if isinstance(decoded, dict):
        for key in ("text", "transcript", "result"):
            value = decoded.get(key)
            if isinstance(value, str):
                return value.strip()
        segments = decoded.get("segments")
        if isinstance(segments, list):
            pieces = [
                seg["text"]
                for seg in segments
                if isinstance(seg, dict) and isinstance(seg.get("text"), str)
            ]
            if pieces:
                return " ".join(p.strip() for p in pieces).strip()
    return stripped


def transcribe_wrapper(audio_path, model, template, timeout_seconds):
    """Return (text, error_or_None)."""
    command = render_wrapper_command(template, audio_path, model)
    try:
        completed = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout_seconds, check=False
        )
    except FileNotFoundError:
        return "", "wrapper executable not found"
    except subprocess.TimeoutExpired:
        return "", f"wrapper timed out after {timeout_seconds}s"
    if completed.returncode != 0:
        detail = (completed.stderr or "").strip().splitlines()
        tail = detail[-1] if detail else f"exit code {completed.returncode}"
        # A wrapper may still emit an error JSON with an explanation on stdout.
        text = extract_transcript(completed.stdout)
        return text, f"wrapper returned non-zero: {tail}"
    return extract_transcript(completed.stdout), None


_MODULE_CACHE = {}


def transcribe_module(audio_path, model):
    """Transcribe in-process via a locally installed MLX module. Returns
    (text, error_or_None). Imports are done lazily and defensively."""
    if "mlx_whisper" in _MODULE_CACHE or importlib.util.find_spec("mlx_whisper"):
        try:
            mod = _MODULE_CACHE.get("mlx_whisper")
            if mod is None:
                import mlx_whisper  # type: ignore

                mod = mlx_whisper
                _MODULE_CACHE["mlx_whisper"] = mod
            result = mod.transcribe(str(audio_path), path_or_hf_repo=model)
            text = result.get("text") if isinstance(result, dict) else str(result)
            return (text or "").strip(), None
        except Exception as error:  # noqa: BLE001 - report any backend failure cleanly
            return "", f"mlx_whisper error: {error}"
    if importlib.util.find_spec("mlx_audio"):
        # mlx_audio's STT entry points are less stable across versions; report
        # rather than guess at an API that may not exist.
        return "", "mlx_audio module detected but no verified STT entry point is wired"
    return "", "no MLX module importable"


# --------------------------------------------------------------------------- #
# Result assembly
# --------------------------------------------------------------------------- #
def build_result(item, text, latency_ms, error):
    expected = item["expected"]
    empty = not text.strip()
    ref_words = normalize_words(expected)
    hyp_words = normalize_words(text)
    return {
        "audio_path": str(item["audio_path"]),
        "id": item.get("id"),
        "category": item.get("category"),
        "source": item.get("source"),
        "expected": expected,
        "text": text,
        "duration_ms": round(latency_ms, 3) if latency_ms is not None else None,
        "wer": compute_wer(expected, text) if error is None else None,
        "punctuation_aware_wer": (
            compute_punctuation_aware_wer(expected, text) if error is None else None
        ),
        "proper_noun_hits": proper_noun_hits(expected, text) if error is None else {},
        "empty_output": empty,
        "missing_first_word_proxy": (
            error is None and boundary_word(ref_words) != boundary_word(hyp_words)
        ),
        "missing_last_word_proxy": (
            error is None
            and boundary_word(ref_words, last=True) != boundary_word(hyp_words, last=True)
        ),
        "error": error,
    }


def percentile(sorted_values, fraction):
    if not sorted_values:
        return 0.0
    index = max(0, min(len(sorted_values) - 1, int(round(fraction * len(sorted_values) + 0.5)) - 1))
    return sorted_values[index]


def summarize(results):
    ok = [r for r in results if r.get("error") is None]
    wers = [r["wer"] for r in ok if isinstance(r.get("wer"), (int, float))]
    paws = [
        r["punctuation_aware_wer"]
        for r in ok
        if isinstance(r.get("punctuation_aware_wer"), (int, float))
    ]
    latencies = [r["duration_ms"] for r in ok if isinstance(r.get("duration_ms"), (int, float))]
    empties = [1 for r in ok if r.get("empty_output")]
    return {
        "avg_wer": (sum(wers) / len(wers)) if wers else None,
        "avg_punctuation_aware_wer": (sum(paws) / len(paws)) if paws else None,
        "avg_latency_ms": (sum(latencies) / len(latencies)) if latencies else None,
        "p95_latency_ms": percentile(sorted(latencies), 0.95) if latencies else None,
        "empty_output_rate": (len(empties) / len(ok)) if ok else None,
    }


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main():
    parser = argparse.ArgumentParser(
        description=(
            "Benchmark MLX-Audio against a DexDictate corpus. Exploration-only; "
            "never wired into production dictation."
        )
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--audio", help="Single audio file to transcribe")
    source.add_argument("--corpus-dir", help="Corpus directory containing transcripts.json")
    parser.add_argument("--manifest", help="Explicit manifest file (overrides corpus transcripts.json)")
    parser.add_argument("--reference-text", help="Reference transcript for a single --audio file")
    parser.add_argument("--model", default="mlx-community/whisper-tiny", help="Model identifier")
    parser.add_argument("--output-dir", default="artifacts/mlx-audio/run", help="Result directory")
    parser.add_argument("--limit", type=int, help="Process at most N audio files")
    parser.add_argument("--timeout-seconds", type=float, default=120.0, help="Timeout per file (wrapper mode)")
    parser.add_argument(
        "--backend-mode",
        choices=("wrapper", "python-module", "auto"),
        default="auto",
        help="How to invoke MLX-Audio",
    )
    parser.add_argument(
        "--fail-on-zero",
        action="store_true",
        help="Exit non-zero if no audio files are processed",
    )
    parser.add_argument("--dry-run", action="store_true", help="Report the plan and backend status only")
    args = parser.parse_args()

    command_template = configured_command_template()
    modules = detected_modules()
    mode, status, reason = resolve_backend(args.backend_mode, command_template, modules)

    started_at = datetime.now(timezone.utc).isoformat()
    output_dir = Path(args.output_dir)

    base_payload = {
        "schema_version": SCHEMA_VERSION,
        "backend": "mlx-audio",
        "backend_mode": mode,
        "experimental": True,
        "production_path_changed": False,
        "model": args.model,
        "corpus_dir": args.corpus_dir,
        "manifest": args.manifest,
        "detected_modules": modules,
        "command_configured": bool(command_template),
        "started_at": started_at,
    }

    # ---- dry run ------------------------------------------------------------
    if args.dry_run:
        print("MLX_AUDIO_DRY_RUN:1")
        print(f"MLX_AUDIO_BACKEND_MODE:{mode}")
        print(f"MLX_AUDIO_STATUS:{status}")
        print(f"MLX_AUDIO_MODEL:{args.model}")
        print(f"MLX_AUDIO_OUTPUT_DIR:{args.output_dir}")
        print(f"MLX_AUDIO_DETECTED_MODULES:{','.join(modules) if modules else 'none'}")
        print(f"MLX_AUDIO_COMMAND_CONFIGURED:{1 if command_template else 0}")
        if reason:
            print(f"MLX_AUDIO_REASON:{reason}")
        if command_template:
            sample = render_wrapper_command(command_template, args.audio or "{corpus-audio-file}", args.model)
            print("MLX_AUDIO_COMMAND_SAMPLE:" + " ".join(sample))
        # Resolve item count when a corpus/manifest is supplied so a dry run can
        # surface the zero-file guard without transcribing anything.
        if args.corpus_dir or args.manifest:
            try:
                items = load_corpus(args.corpus_dir or ".", args.manifest)
                print(f"MLX_AUDIO_PLANNED_FILES:{len(items)}")
            except Exception as error:  # noqa: BLE001
                print(f"MLX_AUDIO_CORPUS_ERROR:{error}")
        return 0

    # ---- backend unavailable / skipped -------------------------------------
    if status != "ok":
        payload = {
            **base_payload,
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "status": status,
            "skip_reason": reason,
            "audio_count": 0,
            "processed_count": 0,
            "failed_count": 0,
            "skipped_count": 0,
            "results": [],
            "summary": summarize([]),
        }
        write_json(output_dir / "summary.json", payload)
        print(f"MLX_AUDIO_{status.upper()}:{reason}")
        print(f"MLX_AUDIO_SUMMARY:{output_dir / 'summary.json'}")
        return 2

    # ---- gather items ------------------------------------------------------
    if args.audio:
        items = [
            {
                "file_name": Path(args.audio).name,
                "audio_path": Path(args.audio),
                "expected": args.reference_text,
                "id": None,
                "category": None,
                "source": None,
            }
        ]
    else:
        if not args.corpus_dir and not args.manifest:
            parser.error("Provide --audio, --corpus-dir, or --manifest (or use --dry-run).")
        try:
            items = load_corpus(args.corpus_dir or ".", args.manifest)
        except Exception as error:  # noqa: BLE001
            parser.error(str(error))

    if args.limit is not None:
        items = items[: max(0, args.limit)]

    audio_count = len(items)

    # ---- zero-file guard ---------------------------------------------------
    if audio_count == 0:
        payload = {
            **base_payload,
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "status": "no-files",
            "skip_reason": "no audio files matched the corpus/manifest/limit selection",
            "audio_count": 0,
            "processed_count": 0,
            "failed_count": 0,
            "skipped_count": 0,
            "results": [],
            "summary": summarize([]),
        }
        write_json(output_dir / "summary.json", payload)
        print("MLX_AUDIO_NO_FILES:0 audio files selected")
        print(f"MLX_AUDIO_SUMMARY:{output_dir / 'summary.json'}")
        return 1 if args.fail_on_zero else 0

    # ---- run ---------------------------------------------------------------
    results = []
    processed = 0
    failed = 0
    skipped = 0
    for item in items:
        audio_path = item["audio_path"]
        if not audio_path.is_file():
            skipped += 1
            results.append(build_result(item, "", None, "audio file not found"))
            continue
        started = time.perf_counter()
        if mode == "wrapper":
            text, error = transcribe_wrapper(audio_path, args.model, command_template, args.timeout_seconds)
        else:
            text, error = transcribe_module(audio_path, args.model)
        latency_ms = (time.perf_counter() - started) * 1000.0
        result = build_result(item, text, latency_ms, error)
        results.append(result)
        if error is None:
            processed += 1
        else:
            failed += 1
        safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", item["file_name"])
        write_json(output_dir / "files" / f"{safe_name}.json", {**base_payload, "result": result})

    payload = {
        **base_payload,
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "status": "ok",
        "skip_reason": None,
        "audio_count": audio_count,
        "processed_count": processed,
        "failed_count": failed,
        "skipped_count": skipped,
        "results": results,
        "summary": summarize(results),
    }
    write_json(output_dir / "summary.json", payload)
    print(f"MLX_AUDIO_SUMMARY:{output_dir / 'summary.json'}")
    print(f"MLX_AUDIO_FILES:{audio_count}")
    print(f"MLX_AUDIO_PROCESSED:{processed}")
    print(f"MLX_AUDIO_FAILED:{failed}")
    print(f"MLX_AUDIO_SKIPPED:{skipped}")
    summary = payload["summary"]
    if summary["avg_wer"] is not None:
        print(f"MLX_AUDIO_AVG_WER:{summary['avg_wer']}")
        print(f"MLX_AUDIO_AVG_LATENCY_MS:{summary['avg_latency_ms']}")
        print(f"MLX_AUDIO_P95_LATENCY_MS:{summary['p95_latency_ms']}")

    if processed == 0 and args.fail_on_zero:
        return 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
