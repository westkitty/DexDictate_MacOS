#!/usr/bin/env python3
"""Benchmark WhisperKit speech-to-text against a DexDictate benchmark corpus.

Exploration/benchmark tooling ONLY. It does not import or touch any DexDictate
production code, output insertion, clipboard, or settings, and it is never wired
into live dictation. Transcript text (recognized and reference) is written
exclusively to explicit benchmark result files under --output-dir.

This driver shells out to the isolated benchmark Swift tool
`tools/whisperkit_sidecar` (built via `scripts/benchmark_whisperkit.sh`). The Swift
tool loads a WhisperKit model once and transcribes the whole corpus in one
process, so per-file latency is "warm" and directly comparable to the MLX
module-mode numbers. The scoring helpers and JSON result shape are intentionally
identical to `scripts/benchmark_mlx_audio.py` so SwiftWhisper, MLX, and WhisperKit
results line up field-for-field.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import wave
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "2026-06-18"


# --------------------------------------------------------------------------- #
# Text scoring helpers (identical to benchmark_mlx_audio.py for comparability)
# --------------------------------------------------------------------------- #
def normalize_words(text):
    text = (text or "").lower()
    text = re.sub(r"[^\w\s]", "", text)
    return text.split()


def tokenize_punctuation_aware(text):
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
# Corpus / manifest loading (identical semantics to benchmark_mlx_audio.py)
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
    raise ValueError("manifest JSON must be a filename->text map or a list of entries with file/expected")


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


# --------------------------------------------------------------------------- #
# Result assembly (identical shape to benchmark_mlx_audio.py)
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
        "punctuation_aware_wer": compute_punctuation_aware_wer(expected, text) if error is None else None,
        "proper_noun_hits": proper_noun_hits(expected, text) if error is None else {},
        "empty_output": empty,
        "missing_first_word_proxy": (error is None and boundary_word(ref_words) != boundary_word(hyp_words)),
        "missing_last_word_proxy": (
            error is None and boundary_word(ref_words, last=True) != boundary_word(hyp_words, last=True)
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
    paws = [r["punctuation_aware_wer"] for r in ok if isinstance(r.get("punctuation_aware_wer"), (int, float))]
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
# WhisperKit tool invocation
# --------------------------------------------------------------------------- #
def run_whisperkit_batch(tool, items, model, download_base, timeout_seconds):
    """Invoke the Swift tool once with all audio paths. Returns
    (text_by_path, model_load_ms, error_or_None)."""
    with tempfile.TemporaryDirectory(prefix="whisperkit-bench-") as tmp:
        paths_file = os.path.join(tmp, "paths.txt")
        out_file = os.path.join(tmp, "out.json")
        with open(paths_file, "w", encoding="utf-8") as handle:
            for item in items:
                handle.write(str(Path(item["audio_path"]).resolve()) + "\n")
        command = [
            tool,
            "--audios-file", paths_file,
            "--model", model,
            "--download-base", str(Path(download_base).resolve()),
            "--out", out_file,
        ]
        try:
            completed = subprocess.run(
                command, capture_output=True, text=True, timeout=timeout_seconds, check=False
            )
        except subprocess.TimeoutExpired:
            return {}, None, f"WhisperKit tool timed out after {timeout_seconds}s"
        if not os.path.isfile(out_file):
            tail = (completed.stderr or completed.stdout or "no output").strip().splitlines()
            return {}, None, f"WhisperKit tool produced no output (exit {completed.returncode}): {tail[-1] if tail else ''}"
        payload = json.loads(Path(out_file).read_text(encoding="utf-8"))
    if payload.get("error"):
        return {}, payload.get("model_load_ms"), payload["error"]
    text_by_path = {}
    for entry in payload.get("results", []):
        text_by_path[entry["audio_path"]] = entry
    return text_by_path, payload.get("model_load_ms"), None


def main():
    parser = argparse.ArgumentParser(
        description="Benchmark WhisperKit against a DexDictate corpus. Exploration-only; never wired into production."
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--audio", help="Single audio file (debug; uses single-file tool mode)")
    source.add_argument("--corpus-dir", help="Corpus directory containing transcripts.json")
    parser.add_argument("--manifest", help="Explicit manifest file (overrides corpus transcripts.json)")
    parser.add_argument("--reference-text", help="Reference transcript for a single --audio file")
    parser.add_argument("--model", default="openai_whisper-tiny", help="WhisperKit model id")
    parser.add_argument("--whisperkit-tool", help="Path to the built whisperkit-transcribe binary")
    parser.add_argument("--download-base", default="artifacts/whisperkit-models", help="WhisperKit model cache dir")
    parser.add_argument("--output-dir", default="artifacts/whisperkit/run", help="Result directory")
    parser.add_argument("--limit", type=int, help="Process at most N audio files")
    parser.add_argument("--timeout-seconds", type=float, default=3600.0, help="Timeout for the whole batch run")
    parser.add_argument("--fail-on-zero", action="store_true", help="Exit non-zero if no files are processed")
    parser.add_argument("--dry-run", action="store_true", help="Report the plan and tool status only")
    args = parser.parse_args()

    tool = args.whisperkit_tool
    tool_ok = bool(tool) and os.path.isfile(tool) and os.access(tool, os.X_OK)
    started_at = datetime.now(timezone.utc).isoformat()
    output_dir = Path(args.output_dir)

    base_payload = {
        "schema_version": SCHEMA_VERSION,
        "backend": "whisperkit",
        "backend_mode": "swift-batch",
        "experimental": True,
        "production_path_changed": False,
        "model": args.model,
        "corpus_dir": args.corpus_dir,
        "manifest": args.manifest,
        "download_base": args.download_base,
        "whisperkit_tool": tool,
        "started_at": started_at,
    }

    if args.dry_run:
        print("WHISPERKIT_DRY_RUN:1")
        print(f"WHISPERKIT_MODEL:{args.model}")
        print(f"WHISPERKIT_OUTPUT_DIR:{args.output_dir}")
        print(f"WHISPERKIT_TOOL:{tool or 'none'}")
        print(f"WHISPERKIT_TOOL_BUILT:{1 if tool_ok else 0}")
        print(f"WHISPERKIT_DOWNLOAD_BASE:{args.download_base}")
        if args.corpus_dir or args.manifest:
            try:
                items = load_corpus(args.corpus_dir or ".", args.manifest)
                if args.limit is not None:
                    items = items[: max(0, args.limit)]
                print(f"WHISPERKIT_PLANNED_FILES:{len(items)}")
            except Exception as error:  # noqa: BLE001
                print(f"WHISPERKIT_CORPUS_ERROR:{error}")
        if not tool_ok:
            print("WHISPERKIT_SKIP_REASON:whisperkit-transcribe not built; run scripts/benchmark_whisperkit.sh")
        return 0

    if not tool_ok:
        payload = {
            **base_payload,
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "status": "unavailable",
            "skip_reason": "whisperkit-transcribe binary not found or not executable; build with scripts/benchmark_whisperkit.sh",
            "audio_count": 0,
            "processed_count": 0,
            "failed_count": 0,
            "skipped_count": 0,
            "results": [],
            "summary": summarize([]),
        }
        write_json(output_dir / "summary.json", payload)
        print(f"WHISPERKIT_UNAVAILABLE:{payload['skip_reason']}")
        print(f"WHISPERKIT_SUMMARY:{output_dir / 'summary.json'}")
        return 2

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
        print("WHISPERKIT_NO_FILES:0 audio files selected")
        print(f"WHISPERKIT_SUMMARY:{output_dir / 'summary.json'}")
        return 1 if args.fail_on_zero else 0

    # Guard against missing audio up front; only hand existing files to the tool.
    present = [it for it in items if Path(it["audio_path"]).is_file()]
    missing = [it for it in items if not Path(it["audio_path"]).is_file()]

    text_by_path, model_load_ms, batch_error = ({}, None, None)
    if present:
        text_by_path, model_load_ms, batch_error = run_whisperkit_batch(
            tool, present, args.model, args.download_base, args.timeout_seconds
        )

    results = []
    processed = failed = skipped = 0
    for item in items:
        resolved = str(Path(item["audio_path"]).resolve())
        if item in missing:
            skipped += 1
            results.append(build_result(item, "", None, "audio file not found"))
            continue
        if batch_error is not None:
            failed += 1
            results.append(build_result(item, "", None, batch_error))
            continue
        entry = text_by_path.get(resolved)
        if entry is None:
            failed += 1
            results.append(build_result(item, "", None, "no transcript returned for this file"))
            continue
        err = entry.get("error")
        if err in ("", None):
            err = None
        result = build_result(item, entry.get("text", ""), entry.get("duration_ms"), err)
        results.append(result)
        if err is None:
            processed += 1
        else:
            failed += 1
        safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", item["file_name"])
        write_json(output_dir / "files" / f"{safe}.json", {**base_payload, "result": result})

    payload = {
        **base_payload,
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "status": "ok" if batch_error is None else "tool-error",
        "skip_reason": batch_error,
        "model_load_ms": model_load_ms,
        "audio_count": audio_count,
        "processed_count": processed,
        "failed_count": failed,
        "skipped_count": skipped,
        "results": results,
        "summary": summarize(results),
    }
    write_json(output_dir / "summary.json", payload)
    print(f"WHISPERKIT_SUMMARY:{output_dir / 'summary.json'}")
    print(f"WHISPERKIT_FILES:{audio_count}")
    print(f"WHISPERKIT_PROCESSED:{processed}")
    print(f"WHISPERKIT_FAILED:{failed}")
    print(f"WHISPERKIT_SKIPPED:{skipped}")
    summary = payload["summary"]
    if summary["avg_wer"] is not None:
        print(f"WHISPERKIT_AVG_WER:{summary['avg_wer']}")
        print(f"WHISPERKIT_AVG_LATENCY_MS:{summary['avg_latency_ms']}")
        print(f"WHISPERKIT_P95_LATENCY_MS:{summary['p95_latency_ms']}")
    if model_load_ms is not None:
        print(f"WHISPERKIT_MODEL_LOAD_MS:{model_load_ms}")

    if processed == 0 and args.fail_on_zero:
        return 1
    return 1 if (failed and processed == 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
