#!/usr/bin/env python3
"""Import selected one-word clips from Speech Commands v0.02.

Speech Commands is keyword spotting data, not full dictation. Imported clips should be
used for command/keyword stress, not as a replacement for dictation samples.
"""
from __future__ import annotations
import argparse, json, os, subprocess, tarfile, tempfile
from pathlib import Path

DEFAULT_WORDS = ["yes", "no", "up", "down", "left", "right", "on", "off", "stop", "go"]


def safe_member_name(name: str) -> bool:
    p = Path(name)
    return not p.is_absolute() and ".." not in p.parts


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True, help="speech_commands_v0.02.tar.gz")
    ap.add_argument("--output-dir", required=True, help="Corpus root")
    ap.add_argument("--max-clips", type=int, default=10)
    ap.add_argument("--words", nargs="*", default=DEFAULT_WORDS)
    ap.add_argument("--ffmpeg", default="ffmpeg")
    args = ap.parse_args()

    words = set(w.lower() for w in args.words)
    out = Path(args.output_dir).resolve()
    audio_out = out / "audio" / "public_speech_commands"
    audio_out.mkdir(parents=True, exist_ok=True)
    entries = []
    per_word = {w: 0 for w in words}

    with tempfile.TemporaryDirectory() as td_raw:
        td = Path(td_raw)
        with tarfile.open(Path(args.archive).expanduser()) as tf:
            for m in tf.getmembers():
                if len(entries) >= args.max_clips:
                    break
                if not (m.isfile() and m.name.lower().endswith(".wav")):
                    continue
                if not safe_member_name(m.name):
                    raise RuntimeError(f"Unsafe archive path: {m.name}")
                parts = Path(m.name).parts
                if len(parts) < 2:
                    continue
                word = parts[-2].lower()
                if word not in words or per_word[word] >= 1:
                    continue
                extracted = tf.extractfile(m)
                if extracted is None:
                    continue
                src = td / f"{word}_{Path(m.name).name}"
                src.write_bytes(extracted.read())
                count = len(entries) + 1
                rel = f"audio/public_speech_commands/speechcmd_{count:03d}_{word}.wav"
                subprocess.run([
                    args.ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                    "-i", str(src), "-ac", "1", "-ar", "16000", str(out / rel)
                ], check=True)
                per_word[word] += 1
                entries.append({
                    "id": f"public_speech_commands_{count:03d}",
                    "file": rel,
                    "expected": word,
                    "category": "public_command_word",
                    "source": "Speech Commands v0.02 imported locally from user-downloaded archive",
                    "speaker_type": "public_dataset_speaker",
                    "sample_rate_hz": 16000,
                    "channels": 1,
                    "include_in_scoring": True,
                    "recommended_use": "command_keyword_stress_only",
                    "notes": "Keyword spotting sample; not a full dictation sentence. Keep separate from dictation quality conclusions."
                })
    (out / "transcripts_public_speech_commands.json").write_text(json.dumps(entries, indent=2) + "\n")
    print(f"Imported {len(entries)} Speech Commands clips into {out}")


if __name__ == "__main__":
    main()
