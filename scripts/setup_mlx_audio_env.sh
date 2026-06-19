#!/bin/bash
# Create an isolated, project-local virtual environment for MLX-Audio benchmark
# exploration. This NEVER touches the Swift build environment, installs nothing
# globally, and is not required by `swift build` or `swift test`.
#
# Usage:
#   ./scripts/setup_mlx_audio_env.sh
#   source .venv_mlx_audio/bin/activate
#   python3 scripts/benchmark_mlx_audio.py --help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv_mlx_audio"

# MLX wheels are published for CPython up to 3.13. The repo's default `python3`
# may be newer (e.g. 3.14), so prefer a known-good interpreter and fall back.
PYTHON_BIN=""
for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        ver="$("$candidate" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
        major="${ver%%.*}"
        minor="${ver##*.}"
        if [[ "$major" -eq 3 && "$minor" -ge 9 && "$minor" -le 13 ]]; then
            PYTHON_BIN="$candidate"
            break
        fi
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    echo "ERROR: No CPython 3.9-3.13 interpreter found." >&2
    echo "MLX wheels are not published for newer interpreters yet." >&2
    echo "Install one (e.g. 'brew install python@3.13') and re-run." >&2
    exit 1
fi

echo "MLX_SETUP_PYTHON:$PYTHON_BIN ($("$PYTHON_BIN" --version 2>&1))"

# Fail clearly if there is no network rather than leaving a half-built venv.
if ! curl -sS -m 10 -o /dev/null "https://pypi.org/simple/mlx-whisper/"; then
    echo "ERROR: Cannot reach pypi.org. Network is required for first-time setup." >&2
    exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
    echo "MLX_SETUP_CREATE_VENV:$VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
else
    echo "MLX_SETUP_REUSE_VENV:$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"
"$VENV_PY" -m pip install --quiet --upgrade pip

# mlx-whisper pulls in mlx + numpy. Keep the surface minimal and local.
if ! "$VENV_PY" -m pip install "mlx-whisper"; then
    echo "ERROR: pip install mlx-whisper failed. Leaving venv in place for inspection." >&2
    echo "You may remove it with: rm -rf '$VENV_DIR'" >&2
    exit 1
fi

echo
echo "MLX_SETUP_OK:1"
echo "Installed packages:"
"$VENV_PY" -m pip list 2>/dev/null | grep -Ei 'mlx|numpy' || true
echo
echo "Run the MLX-Audio benchmark like this:"
echo
echo "  DEXDICTATE_MLX_AUDIO_CMD=\"$VENV_PY $REPO_ROOT/tools/mlx_audio_sidecar/mlx_transcribe_wrapper.py\" \\"
echo "    python3 scripts/benchmark_mlx_audio.py \\"
echo "      --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \\"
echo "      --model mlx-community/whisper-tiny \\"
echo "      --limit 5 \\"
echo "      --output-dir artifacts/mlx-audio/smoke-5"
echo
echo "Or transcribe in-process with the venv interpreter (module mode):"
echo
echo "  $VENV_PY scripts/benchmark_mlx_audio.py \\"
echo "      --backend-mode python-module \\"
echo "      --corpus-dir benchmark_samples/benchmark_corpus_mixed_v1_2 \\"
echo "      --model mlx-community/whisper-tiny --limit 5 \\"
echo "      --output-dir artifacts/mlx-audio/smoke-5-module"
