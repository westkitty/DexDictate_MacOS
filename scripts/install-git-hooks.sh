#!/bin/bash
# Installs a pre-commit hook that runs the local quality gate (`make check`).
# Opt-in: run `bash scripts/install-git-hooks.sh` once per clone.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$ROOT_DIR/.git/hooks"
HOOK_PATH="$HOOK_DIR/pre-commit"

mkdir -p "$HOOK_DIR"
cat > "$HOOK_PATH" <<'HOOK'
#!/bin/bash
# DexDictate pre-commit gate. Skip with `git commit --no-verify` when necessary.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
echo "pre-commit: running lint + build + tests (make check)…"
make check
HOOK

chmod +x "$HOOK_PATH"
echo "Installed pre-commit hook at $HOOK_PATH"
echo "Bypass once with: git commit --no-verify"
