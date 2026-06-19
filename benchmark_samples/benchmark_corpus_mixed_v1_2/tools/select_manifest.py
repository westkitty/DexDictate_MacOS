#!/usr/bin/env python3
"""Select which manifest should be active as transcripts.json."""
from __future__ import annotations
import argparse, shutil
from pathlib import Path

BASE_MODES = {
    'gold': 'transcripts_default_gold.json',
    'andrew-full': 'transcripts_andrew_scored_full.json',
    'review': 'transcripts_andrew_review.json',
    'synthetic': 'transcripts_synthetic_support.json',
    'excluded': 'transcripts_andrew_excluded.json',
    'all': 'transcripts_all.json',
    'mixed-public': 'transcripts_mixed_public.json',
    'public-librispeech': 'transcripts_public_librispeech.json',
    'public-openslr83': 'transcripts_public_openslr83.json',
    'public-speech-commands': 'transcripts_public_speech_commands.json',
}


def existing_modes(root: Path) -> dict[str, str]:
    return {mode: name for mode, name in BASE_MODES.items() if (root / name).exists()}


def main() -> None:
    ap = argparse.ArgumentParser(description='Copy a selected benchmark manifest to transcripts.json')
    ap.add_argument('mode', nargs='?', help='Manifest mode to activate')
    ap.add_argument('--root', default='.', help='Corpus root, default current directory')
    ap.add_argument('--list', action='store_true', help='List available modes')
    args = ap.parse_args()
    root = Path(args.root)
    modes = existing_modes(root)
    if args.list:
        for mode, name in sorted(modes.items()):
            print(f'{mode}\t{name}')
        return
    if not args.mode:
        raise SystemExit('Missing mode. Use --list to see available modes.')
    if args.mode not in BASE_MODES:
        raise SystemExit(f'Unknown mode: {args.mode}')
    if args.mode not in modes:
        raise SystemExit(f'Manifest for mode {args.mode!r} does not exist yet: {BASE_MODES[args.mode]}')
    src = root / modes[args.mode]
    dst = root / 'transcripts.json'
    shutil.copy2(src, dst)
    print(f'Selected {args.mode}: {src.name} -> transcripts.json')


if __name__ == '__main__':
    main()
