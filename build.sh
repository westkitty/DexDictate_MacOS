#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# APP_NAME/EXECUTABLE_NAME/SYSTEM_INSTALL_DIR/USER_INSTALL_DIR use default-assignment
# (rather than unconditional `=`) so scripts/test_build_install_safety.sh can override
# them to isolated temp directories before sourcing this file — sourcing only defines
# functions (the real build/install flow is guarded further down to run only when this
# script is executed directly), so this never changes real-world behavior: these
# variables are never pre-set in normal `./build.sh` usage, so the same defaults always
# apply exactly as before.
: "${APP_NAME:=DexDictate}"
: "${EXECUTABLE_NAME:=DexDictate}"
SWIFT_PRODUCT="DexDictate_MacOS"
CERT_NAME="DexDictate Development"
TARGET_ARCH="arm64"
BUNDLE_IDENTIFIER="com.westkitty.dexdictate.macos"
BUILD_DIR=".build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
: "${SYSTEM_INSTALL_DIR:=/Applications}"
: "${USER_INSTALL_DIR:=$HOME/Applications}"
DEFAULT_INSTALL_DIR="$SYSTEM_INSTALL_DIR"
if [ ! -w "$DEFAULT_INSTALL_DIR" ]; then
    DEFAULT_INSTALL_DIR="$USER_INSTALL_DIR"
fi
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
ENTITLEMENTS="Sources/DexDictate/DexDictate.entitlements"
ICON_SOURCE="Sources/DexDictate/AppIcon.icns"
INFO_TEMPLATE="templates/Info.plist.template"
# Canonical packaged Info.plist source. Source plist is kept in sync via tests.
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
  --release   Package zip + dmg artifacts into _releases/ and run release validation; requires '$CERT_NAME'
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
        if [ "$WANTS_RELEASE" -eq 1 ]; then
            fail "Release packaging requires signing identity '$CERT_NAME'. Run ./build.sh without --release for an ad-hoc local build, or create the certificate first."
        fi
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

# ---------------------------------------------------------------------------
# Duplicate-install safety net
#
# DEFAULT_INSTALL_DIR falls back from /Applications to ~/Applications depending on
# whether /Applications happens to be writable on a given run, so two builds run under
# different permissions can silently land in two different places, leaving an old copy
# behind that Spotlight/Finder/Launchpad can't distinguish from the current one and may
# launch instead of it. Everything below guarantees a successful build leaves exactly one
# installed copy on disk, and launches that exact copy — never a Spotlight/bundle-ID
# lookup that could resolve to a stale one.
#
# All functions here are pure enough to be sourced and unit-tested in isolation (see
# scripts/test_build_install_safety.sh) by overriding APP_NAME/SYSTEM_INSTALL_DIR/
# USER_INSTALL_DIR/INSTALL_DIR/EXECUTABLE_NAME/HOME before calling them.
# ---------------------------------------------------------------------------

# True if the system and user install locations are, for whatever reason (e.g. a
# misconfigured $HOME), the exact same path — in which case there is no real "alternate"
# bundle to reason about at all, and every check below must no-op rather than treat the
# single bundle as its own stale duplicate.
install_locations_collide() {
    [ "$SYSTEM_INSTALL_DIR/$APP_NAME.app" = "$USER_INSTALL_DIR/$APP_NAME.app" ]
}

# Prints the install directory NOT selected as $INSTALL_DIR for this run.
alternate_install_dir() {
    if [ "$INSTALL_DIR" = "$SYSTEM_INSTALL_DIR" ]; then
        printf '%s' "$USER_INSTALL_DIR"
    else
        printf '%s' "$SYSTEM_INSTALL_DIR"
    fi
}

# Hard safety gate: true only if $1 is exactly one of the two known, allowed app-bundle
# paths — $SYSTEM_INSTALL_DIR/$APP_NAME.app or $USER_INSTALL_DIR/$APP_NAME.app (i.e.
# /Applications/DexDictate.app or $HOME/Applications/DexDictate.app under this script's own
# constants, set once near the top of this file and never reassigned). Every deletion
# target in this script must pass this check first — nothing computed is ever handed to
# `rm -rf` without also being validated against this allowlist, so a bug elsewhere in path
# arithmetic can never widen what can be deleted. Referencing the same constants used
# everywhere else in the script (rather than re-hardcoding the literal strings a second
# time) also makes this testable in isolation by overriding them before sourcing.
is_allowed_bundle_path() {
    local candidate="${1:-}"
    [ -n "$candidate" ] || return 1
    [ "$candidate" = "$SYSTEM_INSTALL_DIR/$APP_NAME.app" ] && return 0
    [ "$candidate" = "$USER_INSTALL_DIR/$APP_NAME.app" ] && return 0
    return 1
}

# Prints the PIDs (one per line) of running processes whose executable image resides
# under the given app bundle's Contents/MacOS directory — i.e. processes that actually
# originate from that specific bundle, not just anything sharing $EXECUTABLE_NAME. `ps -o
# comm=` reports the full invoked executable path on macOS (verified: a GUI app launched
# from /Applications/DexDictate.app reports comm=/Applications/DexDictate.app/Contents/
# MacOS/DexDictate), so a prefix match against "$bundle_path/Contents/MacOS/" reliably
# distinguishes which installed copy a given process came from.
pids_under_bundle() {
    local bundle_path="$1"
    local exec_prefix="$bundle_path/Contents/MacOS/"
    local pid comm
    for pid in $(pgrep -x "$EXECUTABLE_NAME" 2>/dev/null || true); do
        comm="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
        case "$comm" in
            "$exec_prefix"*) printf '%s\n' "$pid" ;;
        esac
    done
}

# Terminates only processes proven (via pids_under_bundle) to originate from the given
# stale bundle — never touches the currently installed/selected bundle's process, even if
# it shares the same executable name. Escalates from SIGTERM to SIGKILL only for PIDs
# still confirmed running from that same stale bundle after the grace period; fails loudly
# (via `fail`, nonzero exit) rather than proceeding to delete a bundle whose process could
# not be confirmed stopped.
terminate_stale_bundle_processes() {
    local bundle_path="$1"
    local pids
    pids="$(pids_under_bundle "$bundle_path")"
    [ -n "$pids" ] || return 0

    log_warn "Stopping stale DexDictate process(es) from $bundle_path before removing it..."
    local pid
    for pid in $pids; do
        kill "$pid" 2>/dev/null || true
    done

    local waited=0
    while [ -n "$(pids_under_bundle "$bundle_path")" ] && [ "$waited" -lt 20 ]; do
        sleep 0.25
        waited=$((waited + 1))
    done

    pids="$(pids_under_bundle "$bundle_path")"
    if [ -n "$pids" ]; then
        log_warn "Stale process(es) from $bundle_path did not exit gracefully; sending SIGKILL."
        for pid in $pids; do
            kill -9 "$pid" 2>/dev/null || true
        done
        sleep 0.5
        pids="$(pids_under_bundle "$bundle_path")"
        if [ -n "$pids" ]; then
            fail "Could not terminate stale DexDictate process(es) from $bundle_path (PIDs: $pids). Refusing to delete a bundle with a process still running from it."
        fi
    fi
}

# Removes the alternate installed bundle (the one NOT selected for this run) so only one
# installed copy of DexDictate ever exists on disk. Never silently skips a cleanup that's
# actually needed — if the alternate bundle exists but can't be removed, this fails the
# build with a clear, actionable message rather than leaving it in place unreported.
cleanup_alternate_install() {
    if install_locations_collide; then
        log_warn "System and user install locations resolve to the same path — skipping alternate-bundle cleanup."
        return 0
    fi

    local alt_dir alt_bundle
    alt_dir="$(alternate_install_dir)"
    alt_bundle="$alt_dir/$APP_NAME.app"

    [ -d "$alt_bundle" ] || return 0

    # Never delete the bundle that was just installed, no matter what alt_bundle computes
    # to — this is a second, independent guard on top of alternate_install_dir()'s own
    # if/else, in case INSTALL_DIR and the computed alternate ever agreed by mistake.
    if [ "$alt_bundle" = "$INSTALL_DIR/$APP_NAME.app" ]; then
        fail "Refusing to remove '$alt_bundle' — it is the same bundle that was just installed."
    fi

    if ! is_allowed_bundle_path "$alt_bundle"; then
        # Unreachable given alt_dir is always one of the two known constants above, but
        # this is the hard gate: nothing computed reaches rm -rf without passing it.
        fail "Refusing to remove computed alternate bundle path '$alt_bundle' — it did not pass the allowed-path safety check."
    fi

    terminate_stale_bundle_processes "$alt_bundle"

    if [ ! -w "$alt_dir" ]; then
        fail "Found a stale DexDictate build at '$alt_bundle' but '$alt_dir' is not writable, so it cannot be removed automatically. Remove it manually (e.g. rm -rf \"$alt_bundle\") or fix its permissions, then re-run ./build.sh."
    fi

    log_warn "Removing stale build at '$alt_bundle' (installed to '$INSTALL_DIR/$APP_NAME.app' instead)."
    if ! rm -rf -- "$alt_bundle"; then
        fail "Failed to remove stale bundle at '$alt_bundle'. Remove it manually and re-run ./build.sh."
    fi

    if [ -e "$alt_bundle" ]; then
        fail "Stale bundle at '$alt_bundle' still exists after removal attempt."
    fi
}

# Confirms the guarantee this whole safety net exists for: the selected bundle exists,
# the alternate does not, and there is exactly one installed copy across both locations.
verify_single_install() {
    local selected_bundle="$INSTALL_DIR/$APP_NAME.app"
    [ -d "$selected_bundle" ] || fail "Verification failed: expected installed bundle '$selected_bundle' does not exist."

    if install_locations_collide; then
        log_success "Verified installed copy at $selected_bundle (system/user locations collide; alternate check skipped)"
        return 0
    fi

    local alt_bundle
    alt_bundle="$(alternate_install_dir)/$APP_NAME.app"
    if [ -e "$alt_bundle" ]; then
        fail "Verification failed: alternate bundle '$alt_bundle' still exists after cleanup."
    fi

    local count=0
    [ -d "$SYSTEM_INSTALL_DIR/$APP_NAME.app" ] && count=$((count + 1))
    [ -d "$USER_INSTALL_DIR/$APP_NAME.app" ] && count=$((count + 1))
    if [ "$count" -ne 1 ]; then
        fail "Verification failed: expected exactly one installed DexDictate.app across '$SYSTEM_INSTALL_DIR' and '$USER_INSTALL_DIR', found $count."
    fi

    log_success "Verified exactly one installed copy at $selected_bundle"
}

# Launches the exact bundle path just installed — never via Spotlight, Launchpad,
# bundle-ID/name lookup, or `open -a`, all of which could resolve to a different copy if
# one ever existed. By the time this runs, cleanup_alternate_install() has already
# guaranteed no stale-bundle process remains, so this always starts a fresh instance of
# the bundle that was just installed.
launch_installed_bundle() {
    local bundle_path="$1"
    log_info "Launching $bundle_path..."
    open "$bundle_path"

    local exec_path="$bundle_path/Contents/MacOS/$EXECUTABLE_NAME"
    local waited=0
    while [ "$waited" -lt 20 ]; do
        if pids_under_bundle "$bundle_path" | grep -q .; then
            log_success "Running executable: $exec_path"
            return 0
        fi
        sleep 0.25
        waited=$((waited + 1))
    done
    log_warn "Launched $bundle_path but could not confirm the process started within 5s (it may still be starting, e.g. behind a permission prompt)."
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

# Only run the build/install flow when this script is executed directly, not when it's
# sourced (e.g. by scripts/test_build_install_safety.sh to unit-test the functions above
# in isolation without triggering a real swift build).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
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
    cleanup_alternate_install
    verify_single_install
    launch_installed_bundle "$INSTALL_DIR/$APP_NAME.app"

    if [ "$WANTS_RELEASE" -eq 1 ]; then
        package_release
    fi
fi
