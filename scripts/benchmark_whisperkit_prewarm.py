#!/usr/bin/env python3
"""Benchmark-only investigation of WhisperKit first-inference / CoreML compile cost.

Exploration tooling ONLY. Does not touch DexDictate production code, settings, or
diagnostics, and is never wired into live dictation. It drives the isolated Swift
tool `tools/whisperkit_sidecar` in --diagnose mode.

Privacy: prewarm uses a synthetic SILENT clip (generated here), never a private
transcript. The Swift tool returns only booleans for any recognized text, never
the transcript itself. All output stays under the git-ignored artifacts/ tree.

What it measures, per model:
  - cache state: whether the model was already downloaded before the run
  - model load time (WhisperKit init)
  - sequential inference times on the silent prewarm clip (inference[0] is the
    suspected first-inference CoreML compile; [1..] are warm)
  - optional one real (public) clip transcribed AFTER prewarm (latency only)
  - across N fresh processes ("sessions"), to test whether warm/compiled state
    survives process restart

Optional levers:
  --reset-models <list>   delete those models' download dirs first (cold reproduction)
  --probe-caches          snapshot candidate OS cache dirs before/after to locate
                          where the compile artifacts live
  --compute-units <u>     ane | gpu | cpu | all (suspected compile driver)
"""
import argparse
import json
import os
import shutil
import struct
import subprocess
import sys
import time
import wave
from datetime import datetime, timezone
from pathlib import Path

# Candidate OS caches that CoreML / Apple Neural Engine specialization may use.
# Read-only snapshotting only; nothing here is deleted by this script.
CACHE_CANDIDATES = [
    "~/Library/Caches/com.apple.e5rt.e5bundlecache",
    "~/Library/Caches/com.apple.aned",
    "~/Library/Caches/com.apple.CoreML",
    "~/Library/Caches/com.apple.modelmanagerd",
]


def make_silent_wav(path, seconds, rate=16000):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = int(seconds * rate)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(struct.pack("<%dh" % frames, *([0] * frames)))
    return str(path.resolve())


def pick_public_real_clip(corpus_dir):
    """Pick a public (non-private) clip for the real-after-prewarm latency probe."""
    transcripts = Path(corpus_dir) / "transcripts.json"
    if not transcripts.is_file():
        return None
    data = json.loads(transcripts.read_text(encoding="utf-8"))
    entries = data if isinstance(data, list) else []
    preferred = ("public_clean_read_speech", "public_accent_read_speech")
    for category in preferred:
        for entry in entries:
            if isinstance(entry, dict) and entry.get("category") == category:
                p = Path(corpus_dir) / entry["file"]
                if p.is_file():
                    return str(p.resolve())
    return None


def snapshot_caches():
    """Return {path: (latest_mtime, file_count, total_bytes)} for candidate dirs
    plus every direct child of ~/Library/Caches (read-only)."""
    snap = {}
    dirs = [os.path.expanduser(p) for p in CACHE_CANDIDATES]
    caches_root = os.path.expanduser("~/Library/Caches")
    if os.path.isdir(caches_root):
        for name in os.listdir(caches_root):
            dirs.append(os.path.join(caches_root, name))
    for d in dirs:
        if not os.path.isdir(d):
            continue
        latest = 0.0
        count = 0
        total = 0
        for root, _, files in os.walk(d):
            for f in files:
                try:
                    st = os.stat(os.path.join(root, f))
                except OSError:
                    continue
                latest = max(latest, st.st_mtime)
                count += 1
                total += st.st_size
        snap[d] = (latest, count, total)
    return snap


def diff_caches(before, after, since_ts):
    """Report cache dirs whose newest file mtime is after since_ts (i.e. touched)."""
    touched = []
    for path, (mtime, count, total) in after.items():
        b = before.get(path, (0.0, 0, 0))
        if mtime > since_ts + 0.5 or count != b[1] or total != b[2]:
            touched.append(
                {
                    "path": path.replace(os.path.expanduser("~"), "~"),
                    "newest_mtime_iso": datetime.fromtimestamp(mtime, timezone.utc).isoformat(),
                    "file_count": count,
                    "delta_files": count - b[1],
                    "delta_bytes": total - b[2],
                }
            )
    return sorted(touched, key=lambda x: -x["delta_bytes"])


def model_download_dir(download_base, model):
    return Path(download_base) / "models" / "argmaxinc" / "whisperkit-coreml" / model


# WhisperKit caches CoreML/ANE specialization here, named after the executable.
COMPILE_CACHE = os.path.expanduser("~/Library/Caches/whisperkit-transcribe")


def run_diagnose(tool, model, download_base, prewarm_clip, real_clip, inferences,
                 compute_units, config_prewarm, dummy_decode, out_file, timeout):
    command = [
        tool, "--diagnose",
        "--model", model,
        "--download-base", str(Path(download_base).resolve()),
        "--prewarm-audio", prewarm_clip,
        "--inferences", str(inferences),
        "--out", out_file,
    ]
    if real_clip:
        command += ["--real-audio", real_clip]
    if compute_units:
        command += ["--compute-units", compute_units]
    if config_prewarm is True:
        command += ["--config-prewarm"]
    elif config_prewarm is False:
        command += ["--no-config-prewarm"]
    if dummy_decode:
        command += ["--dummy-decode"]
    wall_start = time.perf_counter()
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return {"error": f"diagnose timed out after {timeout}s"}, None
    wall_ms = (time.perf_counter() - wall_start) * 1000.0
    if not os.path.isfile(out_file):
        tail = (completed.stderr or completed.stdout or "no output").strip().splitlines()
        return {"error": f"no diagnose output (exit {completed.returncode}): {tail[-1] if tail else ''}"}, wall_ms
    return json.loads(Path(out_file).read_text(encoding="utf-8")), wall_ms


def main():
    parser = argparse.ArgumentParser(description="WhisperKit first-inference / prewarm investigation (benchmark-only).")
    parser.add_argument("--whisperkit-tool", required=True, help="Path to built whisperkit-transcribe")
    parser.add_argument("--models", default="openai_whisper-tiny,openai_whisper-base,openai_whisper-small")
    parser.add_argument("--corpus-dir", default="benchmark_samples/benchmark_corpus_mixed_v1_2")
    parser.add_argument("--download-base", default="artifacts/whisperkit-models")
    parser.add_argument("--output-dir", default="artifacts/whisperkit-prewarm/run")
    parser.add_argument("--sessions", type=int, default=2, help="Fresh processes per model (restart-persistence test)")
    parser.add_argument("--inferences", type=int, default=3, help="Sequential inferences per session")
    parser.add_argument("--prewarm-seconds", type=float, default=2.0)
    parser.add_argument("--reset-models", default="", help="Comma list of models whose download dir to delete first")
    parser.add_argument("--probe-caches", action="store_true")
    parser.add_argument("--compute-units", default="", help="ane|gpu|cpu|all (default: WhisperKit default)")
    parser.add_argument("--config-prewarm", choices=("on", "off"), default="",
                        help="Set WhisperKitConfig(prewarm:) on/off (default: WhisperKit default)")
    parser.add_argument("--clear-compile-cache", action="store_true",
                        help="Delete ~/Library/Caches/whisperkit-transcribe before each model (forces true cold)")
    parser.add_argument("--real-after-prewarm", action="store_true", help="Also time one public clip after prewarm")
    parser.add_argument("--dummy-decode", action="store_true",
                        help="Run one silent dummy decode after load, before the real clip (prep probe)")
    parser.add_argument("--timeout-seconds", type=float, default=900.0)
    args = parser.parse_args()

    tool = args.whisperkit_tool
    if not (os.path.isfile(tool) and os.access(tool, os.X_OK)):
        print(f"PREWARM_UNAVAILABLE:tool not built at {tool}", file=sys.stderr)
        return 2

    models = [m.strip() for m in args.models.split(",") if m.strip()]
    reset = {m.strip() for m in args.reset_models.split(",") if m.strip()}
    config_prewarm = {"on": True, "off": False}.get(args.config_prewarm, None)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    prewarm_clip = make_silent_wav(output_dir / "silent_prewarm.wav", args.prewarm_seconds)
    real_clip = pick_public_real_clip(args.corpus_dir) if args.real_after_prewarm else None

    # Reset (delete download dirs) to force cold download + recompile.
    reset_done = []
    for model in reset:
        d = model_download_dir(args.download_base, model)
        if d.exists():
            shutil.rmtree(d)
            reset_done.append(str(d))

    cache_before = snapshot_caches() if args.probe_caches else None
    probe_ts = time.time()

    report = {
        "backend": "whisperkit",
        "investigation": "prewarm/first-inference-compile",
        "experimental": True,
        "production_path_changed": False,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "download_base": args.download_base,
        "compute_units": args.compute_units or "default",
        "config_prewarm": args.config_prewarm or "default",
        "dummy_decode": args.dummy_decode,
        "clear_compile_cache": args.clear_compile_cache,
        "compile_cache_dir": COMPILE_CACHE.replace(os.path.expanduser("~"), "~"),
        "prewarm_clip_seconds": args.prewarm_seconds,
        "real_after_prewarm": bool(real_clip),
        "reset_models": sorted(reset),
        "reset_dirs_removed": reset_done,
        "models": {},
    }

    for model in models:
        # Optionally force a true-cold compile by deleting WhisperKit's specialization cache.
        if args.clear_compile_cache and os.path.isdir(COMPILE_CACHE):
            shutil.rmtree(COMPILE_CACHE)
            print(f"CLEARED_COMPILE_CACHE:{COMPILE_CACHE} before {model}")
        already_before = model_download_dir(args.download_base, model).exists()
        sessions = []
        for s in range(args.sessions):
            out_file = str(output_dir / f"{model}_session{s}.json")
            data, wall_ms = run_diagnose(
                tool, model, args.download_base, prewarm_clip, real_clip,
                args.inferences, args.compute_units, config_prewarm, args.dummy_decode,
                out_file, args.timeout_seconds,
            )
            data["_wall_ms"] = wall_ms
            sessions.append(data)
            inf = data.get("inferences_ms") or []
            dummy = data.get("dummy_decode_ms")
            print(
                f"PREWARM {model} session{s} "
                f"(config_prewarm={args.config_prewarm or 'default'}, dummy_decode={args.dummy_decode}): "
                f"downloaded_before={already_before} load_ms={round(data.get('model_load_ms') or 0)} "
                f"wk_prewarm_ms={round(data.get('whisperkit_prewarm_load_ms') or 0)} "
                f"dummy_ms={round(dummy) if isinstance(dummy, (int, float)) else None} "
                f"real_after={round(data.get('real_after_prewarm_ms') or 0)} "
                f"warm={[round(x) for x in inf] if inf else []} err={data.get('error')}"
            )
            # After session 0 the model is definitely downloaded.
            already_before = True
        report["models"][model] = {
            "downloaded_before_first_session": model_download_dir(args.download_base, model).exists(),
            "sessions": sessions,
        }

    if args.probe_caches:
        cache_after = snapshot_caches()
        touched = diff_caches(cache_before, cache_after, probe_ts)
        report["caches_touched_during_run"] = touched
        for t in touched:
            print(f"CACHE_TOUCHED:{t['path']} delta_files={t['delta_files']} delta_bytes={t['delta_bytes']}")

    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    summary_path = output_dir / "prewarm_summary.json"
    summary_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"PREWARM_SUMMARY:{summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
