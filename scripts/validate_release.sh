#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="${1:-.build/DexDictate.app}"
RELEASE_DIR="_releases"
REPORT_DIR="$RELEASE_DIR/validation"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
REPORT_PATH="$REPORT_DIR/release-validation-$TIMESTAMP.txt"
APP_NAME="DexDictate"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
RESOURCE_BUNDLE="$APP_PATH/Contents/Resources/DexDictate_MacOS_DexDictateKit.bundle"
MODEL_PATH="$RESOURCE_BUNDLE/tiny.en.bin"
ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
HELPER_PATH="$APP_PATH/Contents/Helpers/VerificationRunner"
BASELINE_PATH="$APP_PATH/Contents/Resources/benchmark_baseline.json"

FAILURES=0
WARNINGS=0

mkdir -p "$REPORT_DIR"
: > "$REPORT_PATH"

log() {
    printf '%s\n' "$1" | tee -a "$REPORT_PATH"
}

section() {
    log ""
    log "== $1 =="
}

pass() {
    log "PASS: $1"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    log "WARN: $1"
}

fail() {
    FAILURES=$((FAILURES + 1))
    log "FAIL: $1"
}

check_path() {
    local path="$1"
    local description="$2"
    if [ -e "$path" ]; then
        pass "$description present at $path"
    else
        fail "$description missing at $path"
    fi
}

append_command() {
    local label="$1"
    shift

    section "$label"
    if "$@" >>"$REPORT_PATH" 2>&1; then
        pass "$label succeeded"
    else
        local exit_code=$?
        fail "$label failed with exit code $exit_code"
    fi
}

append_warn_command() {
    local label="$1"
    shift

    section "$label"
    if "$@" >>"$REPORT_PATH" 2>&1; then
        pass "$label succeeded"
    else
        local exit_code=$?
        warn "$label failed with exit code $exit_code"
    fi
}

log "DexDictate release validation report"
log "Generated: $(date)"
log "App path: $APP_PATH"

section "Bundle integrity"
check_path "$APP_PATH" "Application bundle"
check_path "$EXECUTABLE_PATH" "Executable"
check_path "$HELPER_PATH" "VerificationRunner helper"
check_path "$INFO_PLIST" "Info.plist"
check_path "$ICON_PATH" "App icon"
check_path "$BASELINE_PATH" "Benchmark baseline"
check_path "$RESOURCE_BUNDLE" "SwiftPM resource bundle"
check_path "$MODEL_PATH" "Embedded Whisper model"

if [ -f "$INFO_PLIST" ]; then
    section "Bundle metadata"
    if /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" >>"$REPORT_PATH" 2>&1; then
        pass "CFBundleIdentifier readable"
    else
        fail "CFBundleIdentifier missing or unreadable"
    fi

    if /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$INFO_PLIST" >>"$REPORT_PATH" 2>&1; then
        pass "NSMicrophoneUsageDescription readable"
    else
        fail "NSMicrophoneUsageDescription missing or unreadable"
    fi
fi

append_command "Code signing verification" codesign --verify --deep --strict --verbose=2 "$APP_PATH"
append_command "Code signing details" codesign -dvv "$APP_PATH"
append_command "Entitlements dump" codesign -d --entitlements - "$APP_PATH"
append_warn_command "Gatekeeper assessment" spctl --assess --type execute --verbose=4 "$APP_PATH"

section "Artifact hashes"
for artifact in "$RELEASE_DIR"/*.zip "$RELEASE_DIR"/*.dmg; do
    if [ -f "$artifact" ]; then
        if shasum -a 256 "$artifact" >>"$REPORT_PATH" 2>&1; then
            pass "SHA-256 recorded for $(basename "$artifact")"
        else
            fail "Unable to hash $(basename "$artifact")"
        fi
    fi
done

if ! compgen -G "$RELEASE_DIR/*.zip" >/dev/null && ! compgen -G "$RELEASE_DIR/*.dmg" >/dev/null; then
    warn "No packaged release artifacts found in $RELEASE_DIR"
fi

section "Summary"
log "Failures: $FAILURES"
log "Warnings: $WARNINGS"
log "Report: $REPORT_PATH"

if [ "$FAILURES" -gt 0 ]; then
    log "Release validation failed."
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    log "Release validation passed with warnings."
else
    log "Release validation passed."
fi
