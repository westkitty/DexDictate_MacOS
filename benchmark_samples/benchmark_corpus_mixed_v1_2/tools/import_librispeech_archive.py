#!/usr/bin/env python3
"""Import selected clips from a user-downloaded LibriSpeech archive.

This script does not download anything. Download a LibriSpeech archive first from
OpenSLR 12, for example dev-clean.tar.gz or test-clean.tar.gz.
"""
import argparse, json, tarfile, tempfile, subprocess, os
from pathlib import Path


def safe_extract_selected(tf, dest, members):
    dest=Path(dest).resolve()
    safe=[]
    for m in members:
        target=(dest/m.name).resolve()
        if not str(target).startswith(str(dest)+os.sep):
            raise RuntimeError(f'Unsafe archive path: {m.name}')
        safe.append(m)
    tf.extractall(dest, members=safe)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--archive', required=True)
    ap.add_argument('--output-dir', required=True)
    ap.add_argument('--max-clips', type=int, default=15)
    ap.add_argument('--ffmpeg', default='ffmpeg')
    args=ap.parse_args()
    archive=Path(args.archive).expanduser()
    out=Path(args.output_dir)
    audio_out=out/'audio'/'public_librispeech'
    audio_out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td_raw:
        td=Path(td_raw)
        with tarfile.open(archive) as tf:
            members=[m for m in tf.getmembers() if m.isfile() and m.name.endswith(('.flac','.trans.txt'))]
            safe_extract_selected(tf, td, members)
        trans={}
        for t in td.rglob('*.trans.txt'):
            for line in t.read_text(errors='ignore').splitlines():
                if not line.strip(): continue
                uid, text=line.split(' ',1)
                trans[uid]=text.strip()
        entries=[]
        for flac in sorted(td.rglob('*.flac')):
            uid=flac.stem
            if uid not in trans: continue
            count=len(entries)+1
            name=f'libri_{count:03d}_{uid}.wav'
            rel=f'audio/public_librispeech/{name}'
            subprocess.run([args.ffmpeg,'-y','-hide_banner','-loglevel','error','-i',str(flac),'-ac','1','-ar','16000',str(out/rel)], check=True)
            entries.append({
                'id': f'public_librispeech_{count:03d}',
                'file': rel,
                'expected': trans[uid],
                'category': 'public_clean_read_speech',
                'source': 'LibriSpeech/OpenSLR12 imported locally from user-downloaded archive',
                'speaker_type': 'public_dataset_speaker',
                'sample_rate_hz': 16000,
                'channels': 1,
                'include_in_scoring': True,
                'recommended_use': 'public_clean_speech_scoring',
                'notes': 'Imported locally; preserve LibriSpeech/OpenSLR12 license metadata before redistribution.'
            })
            if len(entries) >= args.max_clips:
                break
    (out/'transcripts_public_librispeech.json').write_text(json.dumps(entries, indent=2)+'\n')
    print(f'Imported {len(entries)} clips into {out}')

if __name__=='__main__':
    main()
