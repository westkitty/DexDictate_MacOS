#!/bin/bash
set -eo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_audio_file.wav>"
    exit 1
fi

AUDIO_FILE="$1"

# Build the runner
swift build --target VerificationRunner -c debug

# Execute via swift run, passing arguments after double-dash
swift run VerificationRunner --benchmark "$AUDIO_FILE"
