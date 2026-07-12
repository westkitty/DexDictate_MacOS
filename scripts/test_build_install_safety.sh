#!/bin/bash
# Unit tests for the duplicate-install safety net in build.sh (install_locations_collide,
# alternate_install_dir, is_allowed_bundle_path, pids_under_bundle,
# terminate_stale_bundle_processes, cleanup_alternate_install, verify_single_install).
#
# Never touches the real /Applications or ~/Applications, and never touches the real
# running DexDictate process: every scenario overrides APP_NAME/EXECUTABLE_NAME/
# SYSTEM_INSTALL_DIR/USER_INSTALL_DIR/INSTALL_DIR/HOME to point at an isolated temp
# directory tree with a unique, test-only executable name before sourcing build.sh (whose
# main build/install flow is itself guarded to only run when build.sh is executed
# directly — see the `if [ "${BASH_SOURCE[0]}" = "${0}" ]` guard at the bottom of
# build.sh — so sourcing it here only defines functions, it never triggers a real build).
#
# Each scenario runs in its own `bash` subprocess so a scenario's `fail`/`exit 1` (build.sh
# runs under `set -euo pipefail`) never aborts this test runner itself — only that one
# scenario's result is captured.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SH="$ROOT_DIR/build.sh"
WORKDIR="$(mktemp -d)"
SLEEPER_SRC="$WORKDIR/sleeper.c"
SLEEPER_BIN="$WORKDIR/sleeper"

PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

log_pass() { printf '  PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { printf '  FAIL: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# A real (non-Apple-platform-signed) native binary that just sleeps. Copying an Apple
# system binary (e.g. /bin/sleep) to an arbitrary path and running it gets SIGKILLed
# immediately by macOS's platform-binary path-integrity enforcement — verified during
# development (exit code 137). A freshly compiled binary has no such restriction.
build_sleeper() {
    cat > "$SLEEPER_SRC" <<'EOF'
#include <unistd.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    unsigned int secs = argc > 1 ? (unsigned int)atoi(argv[1]) : 30;
    sleep(secs);
    return 0;
}
EOF
    clang -O0 -o "$SLEEPER_BIN" "$SLEEPER_SRC"
}

# Creates a fake "installed bundle" directory at $1 with a copy of the sleeper binary at
# Contents/MacOS/$2 (the fake EXECUTABLE_NAME for this scenario).
make_fake_bundle() {
    local bundle_path="$1" exec_name="$2"
    mkdir -p "$bundle_path/Contents/MacOS"
    cp "$SLEEPER_BIN" "$bundle_path/Contents/MacOS/$exec_name"
    chmod +x "$bundle_path/Contents/MacOS/$exec_name"
}

# Starts a background sleeper process from the given fake bundle and prints its PID.
start_fake_process() {
    local bundle_path="$1" exec_name="$2" secs="${3:-30}"
    "$bundle_path/Contents/MacOS/$exec_name" "$secs" >/dev/null 2>&1 &
    printf '%s' "$!"
}

wait_for_pid_gone() {
    local pid="$1" waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 40 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done
    ! kill -0 "$pid" 2>/dev/null
}

# Runs a scenario's body (passed as a function name) in an isolated bash subprocess with
# the given env var overrides, so `set -e`/`fail`/`exit` inside build.sh's sourced
# functions can never abort this test runner. Prints the subprocess's stdout/stderr and
# returns its exit code via $SCENARIO_EXIT.
run_scenario() {
    local script_body="$1"
    shift
    local output
    output="$(env "$@" bash -c "
        set -uo pipefail
        source '$BUILD_SH'
        $script_body
    " 2>&1)"
    SCENARIO_EXIT=$?
    SCENARIO_OUTPUT="$output"
}

# ---------------------------------------------------------------------------
# Scenario 1: system location selected, stale user copy exists → removed.
# ---------------------------------------------------------------------------
test_system_selected_stale_user_exists() {
    local root="$WORKDIR/s1" exec_name="fakeexec1"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ ! -e "$user_dir/App.app" ] && [ -d "$sys_dir/App.app" ]; then
        log_pass "system selected: stale user copy removed, selected copy untouched"
    else
        log_fail "system selected: expected user copy removed and system copy intact (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 2: user location selected, stale system copy exists → removed.
# ---------------------------------------------------------------------------
test_user_selected_stale_system_exists() {
    local root="$WORKDIR/s2" exec_name="fakeexec2"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$user_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ ! -e "$sys_dir/App.app" ] && [ -d "$user_dir/App.app" ]; then
        log_pass "user selected: stale system copy removed, selected copy untouched"
    else
        log_fail "user selected: expected system copy removed and user copy intact (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 3: alternate copy absent → no-op, no error.
# ---------------------------------------------------------------------------
test_alternate_absent() {
    local root="$WORKDIR/s3" exec_name="fakeexec3"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    # No bundle created under user_dir at all.

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ -d "$sys_dir/App.app" ] && [ ! -e "$user_dir/App.app" ]; then
        log_pass "alternate absent: no-op, selected copy untouched"
    else
        log_fail "alternate absent: expected clean no-op (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 4: alternate copy exists but removal fails (parent dir not writable) →
# nonzero exit, clear error, bundle left in place (not silently skipped).
# ---------------------------------------------------------------------------
test_alternate_removal_fails() {
    local root="$WORKDIR/s4" exec_name="fakeexec4"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"
    chmod 555 "$user_dir"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    local ok=1
    [ "$SCENARIO_EXIT" -ne 0 ] || ok=0
    [ -d "$user_dir/App.app" ] || ok=0
    case "$SCENARIO_OUTPUT" in *"not writable"*) ;; *) ok=0 ;; esac
    chmod 755 "$user_dir"

    if [ "$ok" -eq 1 ]; then
        log_pass "removal failure: nonzero exit, clear message, bundle left in place"
    else
        log_fail "removal failure: expected nonzero exit + clear message + bundle intact (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 5: system and user install dirs accidentally resolve to the same bundle →
# cleanup no-ops rather than treating the single bundle as its own stale duplicate.
# ---------------------------------------------------------------------------
test_locations_collide() {
    local root="$WORKDIR/s5" exec_name="fakeexec5"
    local shared_dir="$root/SharedApps"
    mkdir -p "$shared_dir"
    make_fake_bundle "$shared_dir/App.app" "$exec_name"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$shared_dir" USER_INSTALL_DIR="$shared_dir" \
        INSTALL_DIR="$shared_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ -d "$shared_dir/App.app" ]; then
        log_pass "colliding locations: no-op, single bundle left untouched"
    else
        log_fail "colliding locations: expected no-op with bundle intact (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 6: a process from the SELECTED (current) bundle must never be detected as
# belonging to the alternate bundle, even sharing the same executable name.
# ---------------------------------------------------------------------------
test_stale_detection_ignores_current_bundle() {
    local root="$WORKDIR/s6" exec_name="fakeexec6"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    # Start a long-lived process from the SELECTED (system) bundle — must survive.
    local current_pid
    current_pid="$(start_fake_process "$sys_dir/App.app" "$exec_name" 20)"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    [ ! -e "$user_dir/App.app" ] || ok=0
    kill -0 "$current_pid" 2>/dev/null || ok=0  # current-bundle process must still be alive

    kill "$current_pid" 2>/dev/null || true
    wait "$current_pid" 2>/dev/null || true

    if [ "$ok" -eq 1 ]; then
        log_pass "stale detection: current-bundle process survives, stale bundle removed"
    else
        log_fail "stale detection: expected current process alive + stale bundle gone (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 6b: a process from the ALTERNATE (stale) bundle must be terminated before
# removal, and removal must still succeed.
# ---------------------------------------------------------------------------
test_stale_process_terminated_before_removal() {
    local root="$WORKDIR/s6b" exec_name="fakeexec6b"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    local stale_pid
    stale_pid="$(start_fake_process "$user_dir/App.app" "$exec_name" 20)"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    [ ! -e "$user_dir/App.app" ] || ok=0
    kill -0 "$stale_pid" 2>/dev/null && ok=0  # must be gone

    if [ "$ok" -eq 1 ]; then
        log_pass "stale process: terminated and bundle removed"
    else
        log_fail "stale process: expected terminated + bundle removed (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
        kill "$stale_pid" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Scenario 7: paths containing spaces are handled safely (quoting).
# ---------------------------------------------------------------------------
test_paths_with_spaces() {
    local root="$WORKDIR/s7 with space" exec_name="fakeexec7"
    local sys_dir="$root/System Apps" user_dir="$root/User Apps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home with space"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ ! -e "$user_dir/App.app" ] && [ -d "$sys_dir/App.app" ]; then
        log_pass "paths with spaces: handled safely"
    else
        log_fail "paths with spaces: expected clean removal (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 8: cleanup failure causes a nonzero exit (duplicate of scenario 4's exit-code
# assertion, kept separate since it's an explicitly required scenario on its own).
# ---------------------------------------------------------------------------
test_cleanup_failure_nonzero_exit() {
    local root="$WORKDIR/s8" exec_name="fakeexec8"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"
    chmod 555 "$user_dir"

    run_scenario 'cleanup_alternate_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    chmod 755 "$user_dir"

    if [ "$SCENARIO_EXIT" -ne 0 ]; then
        log_pass "cleanup failure: process exit code is nonzero ($SCENARIO_EXIT)"
    else
        log_fail "cleanup failure: expected nonzero exit code, got $SCENARIO_EXIT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 5b: verify_single_install must also handle colliding locations correctly
# (not just cleanup_alternate_install) — otherwise it would double-count the same
# physical bundle as if it existed at two locations and fail a spurious "found 2" check.
# ---------------------------------------------------------------------------
test_verify_handles_colliding_locations() {
    local root="$WORKDIR/s5b" exec_name="fakeexec5b"
    local shared_dir="$root/SharedApps"
    mkdir -p "$shared_dir"
    make_fake_bundle "$shared_dir/App.app" "$exec_name"

    run_scenario 'verify_single_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$shared_dir" USER_INSTALL_DIR="$shared_dir" \
        INSTALL_DIR="$shared_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ]; then
        log_pass "verify with colliding locations: succeeds without double-counting"
    else
        log_fail "verify with colliding locations: expected success (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 10: full pipeline composition — cleanup_alternate_install followed by
# verify_single_install in the same process, matching how build.sh's real main flow
# chains them, must succeed end-to-end.
# ---------------------------------------------------------------------------
test_full_pipeline_composition() {
    local root="$WORKDIR/s10" exec_name="fakeexec10"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    run_scenario 'cleanup_alternate_install && verify_single_install' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ -d "$sys_dir/App.app" ] && [ ! -e "$user_dir/App.app" ]; then
        log_pass "full pipeline: cleanup then verify succeeds end-to-end"
    else
        log_fail "full pipeline: expected success (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# ---------------------------------------------------------------------------
# Bonus: is_allowed_bundle_path rejects everything except the two allowed forms.
# ---------------------------------------------------------------------------
test_is_allowed_bundle_path_rejects_degenerate_inputs() {
    local root="$WORKDIR/s9"
    mkdir -p "$root"

    run_scenario '
        is_allowed_bundle_path "" && exit 1
        is_allowed_bundle_path "/" && exit 1
        is_allowed_bundle_path "$HOME" && exit 1
        is_allowed_bundle_path "$SYSTEM_INSTALL_DIR" && exit 1
        is_allowed_bundle_path "$USER_INSTALL_DIR" && exit 1
        is_allowed_bundle_path "$SYSTEM_INSTALL_DIR/$APP_NAME.app" || exit 1
        is_allowed_bundle_path "$USER_INSTALL_DIR/$APP_NAME.app" || exit 1
        exit 0
    ' APP_NAME=App SYSTEM_INSTALL_DIR="$root/SystemApps" USER_INSTALL_DIR="$root/UserApps" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ]; then
        log_pass "is_allowed_bundle_path: rejects empty/root/home/bare-install-dir, accepts only full bundle paths"
    else
        log_fail "is_allowed_bundle_path: unexpected result (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

main() {
    echo "Building test sleeper helper..."
    build_sleeper

    echo "Running build.sh install-safety scenarios..."
    test_system_selected_stale_user_exists
    test_user_selected_stale_system_exists
    test_alternate_absent
    test_alternate_removal_fails
    test_locations_collide
    test_verify_handles_colliding_locations
    test_stale_detection_ignores_current_bundle
    test_stale_process_terminated_before_removal
    test_paths_with_spaces
    test_cleanup_failure_nonzero_exit
    test_full_pipeline_composition
    test_is_allowed_bundle_path_rejects_degenerate_inputs

    echo ""
    echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    [ "$FAIL_COUNT" -eq 0 ]
}

main
