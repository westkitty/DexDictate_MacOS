# DexDictate Documentation Index

Authoritative project documentation lives here. Start with the bible.

## Canonical
- **[DEXDICTATE_BIBLE.md](DEXDICTATE_BIBLE.md)** — the single source of truth for
  architecture, runtime lifecycle, invariants, and the additive implementation ledger.
  This is the document to read first and to append to (append-only, never rewrite).
- [DEXDICTATE_FILE_MAP.md](DEXDICTATE_FILE_MAP.md) — where things live in the source tree.
- [DEXDICTATE_FEATURE_MATRIX.md](DEXDICTATE_FEATURE_MATRIX.md) — feature inventory.
- [DEPENDENCIES.md](DEPENDENCIES.md) — third-party dependencies and why versions are pinned.

## Operational
- Build & install: `./build.sh` (see `--help`); dev tasks: `make help`.
- Release validation: `./scripts/validate_release.sh .build/DexDictate.app`.
- Local quality gate: `make check`. Optional pre-commit hook: `bash scripts/install-git-hooks.sh`.

## Experimental UI
- [experimental-ui-state-first-nano-hud.md](experimental-ui-state-first-nano-hud.md)
- [experimental-ui-exposure-audit.md](experimental-ui-exposure-audit.md)
- [experimental-ui-manual-qa-runbook.md](experimental-ui-manual-qa-runbook.md)

## Archive
Historical reports, one-off handoffs, and superseded plans are kept under
[`archive/`](archive/) for provenance. They are **not** maintained and may be out of date —
prefer the bible for current truth.

> Note: a legacy `BIBLE.md` exists at the repository root. The canonical, maintained bible is
> `docs/DEXDICTATE_BIBLE.md` (this directory).
