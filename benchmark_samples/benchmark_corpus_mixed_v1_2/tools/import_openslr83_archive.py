#!/usr/bin/env python3
"""Import selected clips from OpenSLR83 accent archives.

Inputs:
  --line-index line_index_all.csv from OpenSLR83
  --archive one or more dialect zip archives from OpenSLR83

The script is intentionally tolerant of line-index column naming because mirrors may
preserve upstream CSV headers differently. It writes a manifest file only; it does not
make the imported clips active until select_manifest.py or merge_transcripts.py is used.
"""
from __future__ import annotations
import argparse, csv, io, json, re, subprocess, tempfile, zipfile
from pathlib import Path


def normalize_key(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())


def read_index(path: Path) -> dict[str, str]:
    text = path.read_text(errors="ignore")
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample)
    except Exception:
        dialect = csv.excel
    rows = list(csv.reader(io.StringIO(text), dialect))
    if not rows:
        return {}
    header = [normalize_key(c) for c in rows[0]]
    data_rows = rows[1:] if any("file" in h or "text" in h or "trans" in h for h in header) else rows
    file_idx = None
    text_idx = None
    for i, h in enumerate(header):
        if file_idx is None and ("fileid" in h or h == "file" or h.endswith("file")):
            file_idx = i
        if text_idx is None and ("transcription" in h or "transcript" in h or "sentence" in h or "text" in h):
            text_idx = i
    if file_idx is None:
        file_idx = 1 if rows and len(rows[0]) > 1 else 0
    if text_idx is None:
        text_idx = 2 if rows and len(rows[0]) > 2 else len(rows[0]) - 1
    out = {}
    for row in data_rows:
        if len(row) <= max(file_idx, text_idx):
            continue
        fid = Path(row[file_idx].strip()).stem
        transcript = row[text_idx].strip()
        if fid and transcript:
            out[fid] = transcript
    return out


def safe_member_name(name: str) -> bool:
    p = Path(name)
    return not p.is_absolute() and ".." not in p.parts


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--line-index", required=True, help="OpenSLR83 line_index_all.csv")
    ap.add_argument("--archive", action="append", required=True, help="OpenSLR83 dialect zip archive; repeatable")
    ap.add_argument("--output-dir", required=True, help="Corpus root")
    ap.add_argument("--max-clips", type=int, default=10)
    ap.add_argument("--ffmpeg", default="ffmpeg")
    args = ap.parse_args()

    out = Path(args.output_dir).resolve()
    audio_out = out / "audio" / "public_openslr83"
    audio_out.mkdir(parents=True, exist_ok=True)
    index = read_index(Path(args.line_index).expanduser())
    if not index:
        raise SystemExit("Could not read transcripts from line index")

    entries = []
    seen = set()
    with tempfile.TemporaryDirectory() as td_raw:
        td = Path(td_raw)
        for archive_path in args.archive:
            zp = Path(archive_path).expanduser()
            with zipfile.ZipFile(zp) as zf:
                for info in sorted(zf.infolist(), key=lambda x: x.filename):
                    if len(entries) >= args.max_clips:
                        break
                    if info.is_dir() or not info.filename.lower().endswith(".wav"):
                        continue
                    if not safe_member_name(info.filename):
                        raise RuntimeError(f"Unsafe zip path: {info.filename}")
                    fid = Path(info.filename).stem
                    if fid not in index or fid in seen:
                        continue
                    seen.add(fid)
                    src = td / Path(info.filename).name
                    src.write_bytes(zf.read(info))
                    count = len(entries) + 1
                    name = f"slr83_{count:03d}_{fid}.wav"
                    rel = f"audio/public_openslr83/{name}"
                    subprocess.run([
                        args.ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                        "-i", str(src), "-ac", "1", "-ar", "16000", str(out / rel)
                    ], check=True)
                    entries.append({
                        "id": f"public_openslr83_{count:03d}",
                        "file": rel,
                        "expected": index[fid],
                        "category": "public_accent_read_speech",
                        "source": "OpenSLR83 imported locally from user-downloaded dialect archive",
                        "speaker_type": "public_dataset_speaker",
                        "sample_rate_hz": 16000,
                        "channels": 1,
                        "include_in_scoring": True,
                        "recommended_use": "public_accent_speech_scoring",
                        "notes": "Imported locally; preserve OpenSLR83 license metadata before redistribution."
                    })
                if len(entries) >= args.max_clips:
                    break
    (out / "transcripts_public_openslr83.json").write_text(json.dumps(entries, indent=2) + "\n")
    print(f"Imported {len(entries)} OpenSLR83 clips into {out}")


if __name__ == "__main__":
    main()
