#!/usr/bin/env python3
"""Benchmark soniqo/speech-swift ParakeetStreamingASR against a DexDictate corpus.

Exploration/benchmark tooling ONLY. Never imports or touches DexDictate production
code, and is never wired into live dictation. It drives the isolated Swift tool
`tools/speech_swift_sidecar` (built via scripts/benchmark_speech_swift.sh).

This is a STREAMING ASR lane: in addition to WER it records streaming-specific
metrics (first-partial latency, partial counts, end-of-utterance timing,
final-vs-last-partial divergence) that the batch SwiftWhisper/MLX/WhisperKit lanes
cannot measure.

Scoring helpers and the corpus loader are identical to benchmark_whisperkit.py /
benchmark_mlx_audio.py so results line up field-for-field where comparable.

Privacy: recognized text is written only into the Swift tool's JSON output (under
the git-ignored artifacts/ tree). This driver computes WER from that file and does
not re-print transcripts. Pass --no-store-transcripts to suppress text entirely
(disables WER).
"""
import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "2026-06-19"

REPRESENTATIVE_CATEGORIES = [
    "command_like", "normal_dictation", "public_clean_read_speech", "proper_nouns",
    "punctuation_heavy", "fast_speech", "quiet_speech", "background_noise",
]


# --- scoring (identical normalization to the other lanes) --------------------
def normalize_words(text):
    text = (text or "").lower()
    text = re.sub(r"[^\w\s]", "", text)
    return text.split()


def tokenize_punctuation_aware(text):
    return re.findall(r"\w+|[^\w\s]", (text or "").lower())


def _edit_distance_rate(ref, hyp):
    if not ref:
        return float("inf") if hyp else 0.0
    prev = list(range(len(hyp) + 1))
    for a in range(1, len(ref) + 1):
        cur = [a] + [0] * len(hyp)
        for b in range(1, len(hyp) + 1):
            cost = 0 if ref[a - 1] == hyp[b - 1] else 1
            cur[b] = min(prev[b] + 1, cur[b - 1] + 1, prev[b - 1] + cost)
        prev = cur
    return prev[len(hyp)] / len(ref)


def compute_wer(ref, hyp):
    return _edit_distance_rate(normalize_words(ref), normalize_words(hyp))


def compute_punctuation_aware_wer(ref, hyp):
    return _edit_distance_rate(tokenize_punctuation_aware(ref), tokenize_punctuation_aware(hyp))


# --- corpus loader (same semantics as the other lanes) -----------------------
def load_corpus(corpus_dir, manifest, categories=None, limit=None):
    corpus = Path(corpus_dir)
    path = Path(manifest) if manifest else corpus / "transcripts.json"
    if not path.is_absolute():
        path = corpus / path if manifest else path
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    items = []
    if isinstance(data, dict):
        for name, expected in sorted(data.items()):
            items.append({"file_name": name, "audio_path": corpus / name, "expected": expected,
                          "id": None, "category": None, "source": None})
    else:
        for e in data:
            if not isinstance(e, dict) or e.get("include_in_scoring", True) is False:
                continue
            if not e.get("file") or e.get("expected") is None:
                continue
            if categories and e.get("category") not in categories:
                continue
            items.append({"file_name": e["file"], "audio_path": corpus / e["file"],
                          "expected": e["expected"], "id": e.get("id"),
                          "category": e.get("category"), "source": e.get("source")})
    if limit is not None:
        items = items[: max(0, limit)]
    return items


def pct(values, fraction):
    s = sorted(values)
    if not s:
        return None
    idx = max(0, min(len(s) - 1, int(round(fraction * len(s) + 0.5)) - 1))
    return s[idx]


def mean(values):
    return (sum(values) / len(values)) if values else None


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    p = argparse.ArgumentParser(description="Benchmark speech-swift ParakeetStreamingASR (streaming, benchmark-only).")
    src = p.add_mutually_exclusive_group()
    src.add_argument("--corpus-dir", help="Corpus directory containing transcripts.json")
    src.add_argument("--audio", help="Single audio file")
    p.add_argument("--manifest", help="Explicit manifest file")
    p.add_argument("--reference-text", help="Reference for single --audio")
    p.add_argument("--speech-swift-tool", help="Path to built speech-swift-benchmark binary")
    p.add_argument("--model", default="", help="HF model id (default: tool default)")
    p.add_argument("--output-dir", default="artifacts/speech-swift/run")
    p.add_argument("--csv", action="store_true", help="Also write results.csv")
    p.add_argument("--chunk-ms", type=int)
    p.add_argument("--warmup", action="store_true")
    p.add_argument("--limit", type=int)
    p.add_argument("--subset", choices=("smoke5", "rep15", "full"), help="Convenience corpus subset")
    p.add_argument("--categories", help="Comma list of categories to keep")
    p.add_argument("--no-store-transcripts", action="store_true")
    p.add_argument("--timeout-seconds", type=float, default=3600.0)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    tool = args.speech_swift_tool
    tool_ok = bool(tool) and os.path.isfile(tool) and os.access(tool, os.X_OK)
    output_dir = Path(args.output_dir)

    categories = None
    limit = args.limit
    if args.categories:
        categories = [c.strip() for c in args.categories.split(",") if c.strip()]
    if args.subset == "smoke5":
        limit = 5
    elif args.subset == "rep15":
        categories = REPRESENTATIVE_CATEGORIES
        limit = 15

    base = {
        "schema_version": SCHEMA_VERSION, "backend": "speech-swift",
        "product": "ParakeetStreamingASR", "streaming": True, "experimental": True,
        "production_path_changed": False, "model": args.model or "(tool default)",
        "corpus_dir": args.corpus_dir, "started_at": datetime.now(timezone.utc).isoformat(),
        "speech_swift_tool": tool,
    }

    if args.dry_run:
        print("SPEECH_SWIFT_DRY_RUN:1")
        print(f"SPEECH_SWIFT_TOOL:{tool or 'none'}")
        print(f"SPEECH_SWIFT_TOOL_BUILT:{1 if tool_ok else 0}")
        print(f"SPEECH_SWIFT_MODEL:{args.model or '(tool default)'}")
        print(f"SPEECH_SWIFT_OUTPUT_DIR:{args.output_dir}")
        if args.corpus_dir or args.manifest:
            try:
                items = load_corpus(args.corpus_dir or ".", args.manifest, categories, limit)
                print(f"SPEECH_SWIFT_PLANNED_FILES:{len(items)}")
            except Exception as e:  # noqa: BLE001
                print(f"SPEECH_SWIFT_CORPUS_ERROR:{e}")
        if not tool_ok:
            print("SPEECH_SWIFT_SKIP_REASON:tool not built; run scripts/benchmark_speech_swift.sh")
        return 0

    if not tool_ok:
        write_json(output_dir / "summary.json", {**base, "status": "unavailable",
                   "skip_reason": "speech-swift-benchmark binary not built", "results": []})
        print("SPEECH_SWIFT_UNAVAILABLE:tool not built")
        return 2

    if args.audio:
        items = [{"file_name": Path(args.audio).name, "audio_path": Path(args.audio),
                  "expected": args.reference_text, "id": None, "category": None, "source": None}]
    else:
        if not args.corpus_dir and not args.manifest:
            p.error("Provide --audio, --corpus-dir, or --manifest")
        items = load_corpus(args.corpus_dir or ".", args.manifest, categories, limit)

    present = [it for it in items if Path(it["audio_path"]).is_file()]
    if not present:
        write_json(output_dir / "summary.json", {**base, "status": "no-files", "results": []})
        print("SPEECH_SWIFT_NO_FILES:0")
        return 1

    # Run the streaming tool once over all present clips (model loaded once).
    by_path = {}
    tool_meta = {}
    with tempfile.TemporaryDirectory(prefix="speech-swift-bench-") as tmp:
        paths_file = os.path.join(tmp, "paths.txt")
        out_file = str(output_dir / "tool_output.json")
        with open(paths_file, "w", encoding="utf-8") as fh:
            for it in present:
                fh.write(str(Path(it["audio_path"]).resolve()) + "\n")
        cmd = [tool, "--audios-file", paths_file, "--out", out_file]
        if args.model:
            cmd += ["--model", args.model]
        if args.chunk_ms is not None:
            cmd += ["--chunk-ms", str(args.chunk_ms)]
        if args.warmup:
            cmd += ["--warmup"]
        if args.no_store_transcripts:
            cmd += ["--no-store-transcripts"]
        try:
            completed = subprocess.run(cmd, capture_output=True, text=True,
                                       timeout=args.timeout_seconds, check=False)
        except subprocess.TimeoutExpired:
            write_json(output_dir / "summary.json", {**base, "status": "timeout", "results": []})
            print(f"SPEECH_SWIFT_TIMEOUT:{args.timeout_seconds}s")
            return 1
        if not os.path.isfile(out_file):
            tail = (completed.stderr or completed.stdout or "no output").strip().splitlines()
            write_json(output_dir / "summary.json", {**base, "status": "tool-error",
                       "skip_reason": tail[-1] if tail else "", "results": []})
            print(f"SPEECH_SWIFT_TOOL_ERROR:{tail[-1] if tail else 'no output'}")
            return 1
        payload = json.loads(Path(out_file).read_text(encoding="utf-8"))
        tool_meta = {k: payload.get(k) for k in
                     ("model", "model_load_ms", "model_sample_rate", "chunk_ms", "stored_transcripts")}
        for entry in payload.get("results", []):
            by_path[entry["audio_path"]] = entry

    # Score per clip.
    results = []
    for it in items:
        resolved = str(Path(it["audio_path"]).resolve())
        entry = by_path.get(resolved)
        if entry is None:
            results.append({**{k: it.get(k) for k in ("id", "category", "source")},
                            "audio_path": str(it["audio_path"]), "expected": it["expected"],
                            "error": "no result (file missing or skipped)", "wer": None})
            continue
        text = entry.get("text", "")
        err = entry.get("error")
        wer = compute_wer(it["expected"], text) if (err is None and "text" in entry and it["expected"] is not None) else None
        paw = compute_punctuation_aware_wer(it["expected"], text) if (err is None and "text" in entry and it["expected"] is not None) else None
        results.append({
            "audio_path": resolved, "id": it.get("id"), "category": it.get("category"),
            "source": it.get("source"), "expected": it["expected"],
            "text": text if "text" in entry else None,
            "wer": wer, "punctuation_aware_wer": paw,
            "first_partial_ms": entry.get("first_partial_ms"),
            "final_ms": entry.get("final_ms"),
            "num_partials": entry.get("num_partials"),
            "num_segments": entry.get("num_segments"),
            "eou_detected": entry.get("eou_detected"),
            "eou_ms": entry.get("eou_ms"),
            "final_differs_from_last_partial": entry.get("final_differs_from_last_partial"),
            "empty_output": entry.get("empty_output"),
            "audio_seconds": entry.get("audio_seconds"),
            "error": err,
        })

    ok = [r for r in results if r.get("error") is None]
    wers = [r["wer"] for r in ok if isinstance(r.get("wer"), (int, float))]
    paws = [r["punctuation_aware_wer"] for r in ok if isinstance(r.get("punctuation_aware_wer"), (int, float))]
    finals = [r["final_ms"] for r in ok if isinstance(r.get("final_ms"), (int, float))]
    firsts = [r["first_partial_ms"] for r in ok if isinstance(r.get("first_partial_ms"), (int, float))]
    partials = [r["num_partials"] for r in ok if isinstance(r.get("num_partials"), int)]
    empties = [1 for r in ok if r.get("empty_output")]
    eous = [1 for r in ok if r.get("eou_detected")]
    diffs = [1 for r in ok if r.get("final_differs_from_last_partial")]

    summary = {
        "avg_wer": mean(wers), "avg_punctuation_aware_wer": mean(paws),
        "median_final_latency_ms": statistics.median(finals) if finals else None,
        "avg_final_latency_ms": mean(finals), "p95_final_latency_ms": pct(finals, 0.95),
        "median_first_partial_ms": statistics.median(firsts) if firsts else None,
        "avg_num_partials": mean(partials),
        "partials_available": bool(firsts),
        "eou_detected_rate": (len(eous) / len(ok)) if ok else None,
        "final_differs_from_last_partial_rate": (len(diffs) / len(ok)) if ok else None,
        "empty_output_rate": (len(empties) / len(ok)) if ok else None,
    }

    payload = {**base, "finished_at": datetime.now(timezone.utc).isoformat(), "status": "ok",
               "tool_meta": tool_meta, "audio_count": len(items),
               "processed_count": len(ok), "failed_count": len(results) - len(ok),
               "results": results, "summary": summary}
    write_json(output_dir / "summary.json", payload)

    if args.csv:
        import csv
        with open(output_dir / "results.csv", "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["id", "category", "wer", "punctuation_aware_wer", "first_partial_ms",
                        "final_ms", "num_partials", "num_segments", "eou_detected",
                        "final_differs_from_last_partial", "empty_output", "error"])
            for r in results:
                w.writerow([r.get("id"), r.get("category"), r.get("wer"), r.get("punctuation_aware_wer"),
                            r.get("first_partial_ms"), r.get("final_ms"), r.get("num_partials"),
                            r.get("num_segments"), r.get("eou_detected"),
                            r.get("final_differs_from_last_partial"), r.get("empty_output"), r.get("error")])

    print(f"SPEECH_SWIFT_SUMMARY:{output_dir / 'summary.json'}")
    print(f"SPEECH_SWIFT_FILES:{len(items)} PROCESSED:{len(ok)} FAILED:{len(results) - len(ok)}")
    if summary["avg_wer"] is not None:
        print(f"SPEECH_SWIFT_AVG_WER:{summary['avg_wer']:.4f}")
    if summary["median_final_latency_ms"] is not None:
        print(f"SPEECH_SWIFT_MEDIAN_FINAL_MS:{summary['median_final_latency_ms']:.0f} "
              f"P95_FINAL_MS:{summary['p95_final_latency_ms']:.0f}")
    print(f"SPEECH_SWIFT_PARTIALS_AVAILABLE:{summary['partials_available']} "
          f"EOU_RATE:{summary['eou_detected_rate']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
