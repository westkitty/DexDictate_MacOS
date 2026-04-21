#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="DexDictate"
EXECUTABLE_NAME="DexDictate"
SWIFT_PRODUCT="DexDictate_MacOS"
CERT_NAME="DexDictate Development"
TARGET_ARCH="arm64"
BUNDLE_IDENTIFIER="com.westkitty.dexdictate.macos"
BUILD_DIR=".build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
SYSTEM_INSTALL_DIR="/Applications"
USER_INSTALL_DIR="$HOME/Applications"
DEFAULT_INSTALL_DIR="$SYSTEM_INSTALL_DIR"
if [ ! -w "$DEFAULT_INSTALL_DIR" ]; then
    DEFAULT_INSTALL_DIR="$USER_INSTALL_DIR"
fi
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
ENTITLEMENTS="Sources/DexDictate/DexDictate.entitlements"
ICON_SOURCE="Sources/DexDictate/AppIcon.icns"
INFO_TEMPLATE="templates/Info.plist.template"
SOURCE_INFO_PLIST="Sources/DexDictate/Info.plist"
VERSION_FILE="VERSION"
BENCHMARK_BASELINE="benchmark_baseline.json"
MODEL_FETCH_SCRIPT="scripts/fetch_model.sh"
RELEASE_DIR="_releases"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WANTS_RELEASE=0
INSTALL_TARGET_SET=0

usage() {
    cat <<EOF
Usage: ./build.sh [--user | --system] [--release] [--help]

  --user      Install the built app into ~/Applications
  --system    Install the built app into /Applications (fails if not writable)
  --release   Package zip + dmg artifacts into _releases/ and run release validation
  --help      Show this help text
EOF
}

log_info() {
    printf '%b%s%b\n' "$BLUE" "$1" "$NC"
}

log_warn() {
    printf '%b%s%b\n' "$YELLOW" "$1" "$NC"
}

log_success() {
    printf '%b%s%b\n' "$GREEN" "$1" "$NC"
}

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --user)
                [ "$INSTALL_TARGET_SET" -eq 0 ] || fail "Choose only one install target: --user or --system."
                INSTALL_DIR="$USER_INSTALL_DIR"
                INSTALL_TARGET_SET=1
                ;;
            --system)
                [ "$INSTALL_TARGET_SET" -eq 0 ] || fail "Choose only one install target: --user or --system."
                INSTALL_DIR="$SYSTEM_INSTALL_DIR"
                INSTALL_TARGET_SET=1
                ;;
            --release)
                WANTS_RELEASE=1
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                fail "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

check_host_architecture() {
    local translated="0"
    if translated="$(sysctl -in sysctl.proc_translated 2>/dev/null)"; then
        if [ "$translated" = "1" ]; then
            fail "Rosetta shell detected. Open a native arm64 terminal session and run ./build.sh again."
        fi
    fi

    local machine_arch
    machine_arch="$(uname -m)"
    if [ "$machine_arch" != "arm64" ]; then
        fail "Unsupported build architecture: $machine_arch. DexDictate_MacOS targets Apple Silicon (arm64) only."
    fi
}

ensure_install_target() {
    if [ "$INSTALL_DIR" = "$SYSTEM_INSTALL_DIR" ] && [ ! -w "$SYSTEM_INSTALL_DIR" ]; then
        fail "/Applications is not writable for the current user. Re-run with sudo, or use --user."
    fi
}

ensure_model() {
    [ -x "$MODEL_FETCH_SCRIPT" ] || fail "Missing executable model bootstrap script: $MODEL_FETCH_SCRIPT"
    "$MODEL_FETCH_SCRIPT"
}

validate_bundle_metadata() {
    [ -f "$SOURCE_INFO_PLIST" ] || fail "Missing source Info.plist: $SOURCE_INFO_PLIST"
    local source_bundle_id
    source_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_INFO_PLIST" 2>/dev/null)" \
        || fail "Unable to read CFBundleIdentifier from $SOURCE_INFO_PLIST"

    if [ "$source_bundle_id" != "$BUNDLE_IDENTIFIER" ]; then
        fail "Bundle identifier mismatch. build.sh expects '$BUNDLE_IDENTIFIER' but $SOURCE_INFO_PLIST contains '$source_bundle_id'."
    fi
}

build_products() {
    log_info "Building $APP_NAME..."
    swift build -c release --disable-sandbox
    swift build -c release --disable-sandbox --product VerificationRunner
}

resolve_build_artifacts() {
    BIN_PATH="$(swift build -c release --show-bin-path)"
    BINARY="$BIN_PATH/$SWIFT_PRODUCT"
    HELPER_BINARY="$BIN_PATH/VerificationRunner"
    RESOURCE_BUNDLE="$BIN_PATH/${SWIFT_PRODUCT}_DexDictateKit.bundle"

    [ -f "$BINARY" ] || fail "Missing binary: $BINARY"
    [ -d "$RESOURCE_BUNDLE" ] || fail "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE"
    [ -f "$HELPER_BINARY" ] || fail "Missing helper binary: $HELPER_BINARY"
}

stop_running_instances() {
    local app_path
    for app_path in "$INSTALL_DIR/$APP_NAME.app" "$SYSTEM_INSTALL_DIR/$APP_NAME.app" "$USER_INSTALL_DIR/$APP_NAME.app" "$BUNDLE"; do
        if [ -d "$app_path" ]; then
            osascript -e "tell application \"$app_path\" to quit" >/dev/null 2>&1 || true
        fi
    done
    osascript -e "tell application id \"$BUNDLE_IDENTIFIER\" to quit" >/dev/null 2>&1 || true

    local waited=0
    while pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1 && [ "$waited" -lt 20 ]; do
        sleep 0.25
        waited=$((waited + 1))
    done

    if pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
        log_warn "DexDictate is still running; terminating remaining processes before install."
        pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
        sleep 1
    fi
}

assemble_bundle() {
    rm -rf "$BUNDLE"
    mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources" "$BUNDLE/Contents/Helpers"
    cp -f "$BINARY" "$BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
    cp -f "$HELPER_BINARY" "$BUNDLE/Contents/Helpers/VerificationRunner"
    chmod +x "$BUNDLE/Contents/Helpers/VerificationRunner"
    rm -rf "$BUNDLE/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"
    cp -R "$RESOURCE_BUNDLE" "$BUNDLE/Contents/Resources/"
    cp -f "$ICON_SOURCE" "$BUNDLE/Contents/Resources/AppIcon.icns"
    cp -f "$BENCHMARK_BASELINE" "$BUNDLE/Contents/Resources/benchmark_baseline.json"

    VERSION="$(cat "$VERSION_FILE")"
    log_info "Generating Info.plist..."
    sed -e "s/{{APP_NAME}}/$APP_NAME/g" \
        -e "s/{{EXECUTABLE_NAME}}/$EXECUTABLE_NAME/g" \
        -e "s/{{BUNDLE_IDENTIFIER}}/$BUNDLE_IDENTIFIER/g" \
        -e "s/{{VERSION}}/$VERSION/g" \
        "$INFO_TEMPLATE" > "$BUNDLE/Contents/Info.plist"

    echo "APPL????" > "$BUNDLE/Contents/PkgInfo"
}

sign_bundle() {
    if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
        log_info "Signing with '$CERT_NAME'..."
        codesign --force --deep \
            --sign "$CERT_NAME" \
            --entitlements "$ENTITLEMENTS" \
            --options runtime \
            --timestamp=none \
            "$BUNDLE"
    else
        log_warn "'$CERT_NAME' not found. Using ad-hoc signing (-)."
        codesign --force --deep \
            --sign - \
            --entitlements "$ENTITLEMENTS" \
            "$BUNDLE"
    fi

    CDHASH="$(codesign -dvv "$BUNDLE" 2>&1 | awk -F= '/CDHash=/{print $2; exit}')"
    if [ -n "$CDHASH" ]; then
        log_success "CDHash: $CDHASH"
    fi
}

install_bundle() {
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    ditto "$BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    if [ -x "$LSREGISTER" ]; then
        "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
    fi

    log_success "Installed to $INSTALL_DIR/$APP_NAME.app"
    printf 'Open with: open "%s/%s.app"\n' "$INSTALL_DIR" "$APP_NAME"
}

package_release() {
    VERSION="$(cat "$VERSION_FILE")"
    local release_stem="${APP_NAME}-${VERSION}-macos-${TARGET_ARCH}"
    local zip_name="${release_stem}.zip"
    local dmg_name="${release_stem}.dmg"
    local checksum_name="${release_stem}-SHA256SUMS.txt"

    mkdir -p "$RELEASE_DIR"
    rm -f "$RELEASE_DIR"/*.zip "$RELEASE_DIR"/*.dmg "$RELEASE_DIR"/*-SHA256SUMS.txt

    log_info "Packaging release artifacts..."
    ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$RELEASE_DIR/$zip_name"

    STAGING_DIR="$(mktemp -d)"
    cleanup_release() {
        rm -rf "$STAGING_DIR"
    }
    trap cleanup_release RETURN

    cp -R "$BUNDLE" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$RELEASE_DIR/$dmg_name" >/dev/null

    (
        cd "$RELEASE_DIR"
        shasum -a 256 "$zip_name" "$dmg_name" > "$checksum_name"
    )

    ./scripts/validate_release.sh "$BUNDLE"
    log_success "Release artifacts written to $RELEASE_DIR/"
}

parse_args "$@"
check_host_architecture
ensure_install_target
ensure_model
validate_bundle_metadata
build_products
resolve_build_artifacts
stop_running_instances
assemble_bundle
sign_bundle
install_bundle

if [ "$WANTS_RELEASE" -eq 1 ]; then
    package_release
fi
