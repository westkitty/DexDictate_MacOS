#!/usr/bin/env python3
"""Validate DexDictate benchmark corpus structure and WAV/manifest consistency."""
from __future__ import annotations
import argparse, json, wave, re, sys
from pathlib import Path
from collections import Counter

MANIFESTS = [
    'transcripts.json',
    'transcripts_default_gold.json',
    'transcripts_andrew_review.json',
    'transcripts_andrew_scored_full.json',
    'transcripts_andrew_excluded.json',
    'transcripts_synthetic_support.json',
    'transcripts_all.json',
    # optional manifests created by local public import tools
    'transcripts_public_librispeech.json',
    'transcripts_public_openslr83.json',
    'transcripts_public_speech_commands.json',
    'transcripts_mixed_public.json',
]
REQUIRED_BASE = {
    'transcripts.json',
    'transcripts_default_gold.json',
    'transcripts_andrew_review.json',
    'transcripts_andrew_scored_full.json',
    'transcripts_andrew_excluded.json',
    'transcripts_synthetic_support.json',
    'transcripts_all.json',
}


def word_count(text: str) -> int:
    return len(re.findall(r"[A-Za-z0-9_]+(?:[.'-][A-Za-z0-9_]+)?", text or ''))


def load_manifest(path: Path, required: bool, errors: list[str]) -> list[dict]:
    if not path.exists():
        if required:
            errors.append(f'missing manifest {path.name}')
        return []
    try:
        data = json.loads(path.read_text())
    except Exception as e:
        errors.append(f'{path.name}: invalid JSON: {e}')
        return []
    if not isinstance(data, list):
        errors.append(f'{path.name}: expected JSON list')
        return []
    return data


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('root', nargs='?', default='.')
    args = ap.parse_args()
    root = Path(args.root)
    errors: list[str] = []
    warnings: list[str] = []
    all_refs = set()

    for name in MANIFESTS:
        data = load_manifest(root / name, name in REQUIRED_BASE, errors)
        if not data:
            continue
        seen = set()
        for idx, item in enumerate(data, 1):
            for key in ['id', 'file', 'expected', 'category']:
                if key not in item:
                    errors.append(f'{name}[{idx}]: missing {key}')
            rel = item.get('file')
            if not rel:
                continue
            all_refs.add(rel)
            if rel in seen:
                errors.append(f'{name}: duplicate file {rel}')
            seen.add(rel)
            wav = root / rel
            if not wav.exists():
                errors.append(f'{name}[{idx}]: missing WAV {rel}')
                continue
            try:
                with wave.open(str(wav), 'rb') as wf:
                    ch = wf.getnchannels()
                    sr = wf.getframerate()
                    sw = wf.getsampwidth()
                    frames = wf.getnframes()
                    dur = frames / sr if sr else 0
            except Exception as e:
                errors.append(f'{rel}: cannot read WAV: {e}')
                continue
            if sr != 16000 or ch != 1:
                errors.append(f'{rel}: expected 16000 Hz mono, got {sr} Hz/{ch} ch')
            if sw != 2:
                errors.append(f'{rel}: expected 16-bit PCM, got sample width {sw}')
            mdur = item.get('duration_seconds') or item.get('clip_duration_seconds')
            if mdur is not None and abs(float(mdur) - dur) > 0.03:
                warnings.append(f'{rel}: manifest duration {mdur} vs actual {dur:.3f}')

    all_wavs = {str(p.relative_to(root)) for p in (root / 'audio').rglob('*.wav')}
    for rel in sorted(all_wavs - all_refs):
        warnings.append(f'WAV not referenced by any known manifest: {rel}')
    for rel in sorted(all_refs - all_wavs):
        errors.append(f'manifest reference missing WAV: {rel}')

    active = load_manifest(root / 'transcripts.json', True, errors)
    c = Counter(i.get('category') for i in active)
    print(f'Active manifest clips: {len(active)}')
    print('Active categories:', dict(sorted(c.items())))
    print(f'Errors: {len(errors)}')
    for e in errors:
        print('ERROR:', e)
    print(f'Warnings: {len(warnings)}')
    for w in warnings:
        print('WARN:', w)
    if errors:
        sys.exit(1)


if __name__ == '__main__':
    main()
