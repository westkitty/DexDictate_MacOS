#!/usr/bin/env python3
"""Merge transcript manifests with basic de-duplication."""
from __future__ import annotations
import argparse, json
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', required=True)
    ap.add_argument('--allow-duplicate-files', action='store_true')
    ap.add_argument('manifests', nargs='+')
    args = ap.parse_args()
    items = []
    seen_files = set()
    seen_ids = set()
    for m in args.manifests:
        path = Path(m)
        if not path.exists():
            raise SystemExit(f'Missing manifest: {m}')
        data = json.loads(path.read_text())
        if not isinstance(data, list):
            raise SystemExit(f'{m} is not a JSON list')
        for item in data:
            rel = item.get('file')
            item_id = item.get('id')
            if rel in seen_files and not args.allow_duplicate_files:
                raise SystemExit(f'Duplicate file across manifests: {rel}')
            if item_id in seen_ids:
                raise SystemExit(f'Duplicate id across manifests: {item_id}')
            seen_files.add(rel)
            seen_ids.add(item_id)
            items.append(item)
    Path(args.output).write_text(json.dumps(items, indent=2) + '\n')
    print(f'Wrote {len(items)} entries to {args.output}')


if __name__ == '__main__':
    main()
