#!/bin/bash
# Unit tests for the duplicate-install safety net in build.sh (install_locations_collide,
# install_dir_is_standard, alternate_install_dir, is_allowed_bundle_path, pids_under_bundle,
# terminate_bundle_processes, ensure_bundle_process_stopped, cleanup_alternate_install,
# verify_single_install) — covering both the alternate/stale bundle (the duplicate-install
# fix) and the selected/current bundle (the pre-install shutdown hardening, so the
# selected bundle is never replaced while a process is still running from it).
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
STUBBORN_SRC="$WORKDIR/stubborn.c"
STUBBORN_BIN="$WORKDIR/stubborn"

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

# A variant that ignores SIGTERM, so tests can exercise the SIGKILL escalation path (and
# the "cannot be stopped, abort" path, by additionally ignoring SIGKILL — which is not
# actually possible for any process to do, so that path is instead exercised by killing
# the process out from under pids_under_bundle's own detection — see
# test_selected_bundle_cannot_be_stopped_aborts below for how that's simulated safely).
build_stubborn_sleeper() {
    cat > "$STUBBORN_SRC" <<'EOF'
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
int main(int argc, char **argv) {
    signal(SIGTERM, SIG_IGN);
    unsigned int secs = argc > 1 ? (unsigned int)atoi(argv[1]) : 30;
    sleep(secs);
    return 0;
}
EOF
    clang -O0 -o "$STUBBORN_BIN" "$STUBBORN_SRC"
}

# Creates a fake "installed bundle" directory at $1 with a copy of the sleeper binary at
# Contents/MacOS/$2 (the fake EXECUTABLE_NAME for this scenario). $3, if "stubborn", uses
# the SIGTERM-ignoring binary instead, so a scenario can exercise the SIGKILL escalation
# path.
make_fake_bundle() {
    local bundle_path="$1" exec_name="$2" variant="${3:-normal}"
    mkdir -p "$bundle_path/Contents/MacOS"
    if [ "$variant" = "stubborn" ]; then
        cp "$STUBBORN_BIN" "$bundle_path/Contents/MacOS/$exec_name"
    else
        cp "$SLEEPER_BIN" "$bundle_path/Contents/MacOS/$exec_name"
    fi
    chmod +x "$bundle_path/Contents/MacOS/$exec_name"
}

# Starts a background sleeper process from the given fake bundle and prints its PID. The
# brief settle delay after backgrounding matters specifically for the "stubborn" (SIGTERM-
# ignoring) variant: `signal(SIGTERM, SIG_IGN)` must actually execute before any test sends
# SIGTERM, or the still-default disposition (terminate) applies instead — verified during
# development that a 0.3s gap was sometimes too short (and reproduced the flake) while 1s
# reliably was not.
start_fake_process() {
    local bundle_path="$1" exec_name="$2" secs="${3:-30}"
    "$bundle_path/Contents/MacOS/$exec_name" "$secs" >/dev/null 2>&1 &
    local new_pid="$!"
    sleep 0.5
    printf '%s' "$new_pid"
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
# Scenario 11: a custom verification target is outside the canonical system/user
# pair. Cleanup and verification must preserve both canonical bundles and verify
# only the explicitly selected custom bundle.
# ---------------------------------------------------------------------------
test_custom_install_preserves_standard_bundles() {
    local root="$WORKDIR/s11" exec_name="fakeexec11"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps" custom_dir="$root/Verification"
    mkdir -p "$sys_dir" "$user_dir" "$custom_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"
    make_fake_bundle "$custom_dir/App.app" "$exec_name"

    run_scenario '
        install_dir_is_standard && exit 1
        cleanup_alternate_install
        verify_single_install
    ' APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$custom_dir" HOME="$root/home"

    if [ "$SCENARIO_EXIT" -eq 0 ] \
        && [ -d "$sys_dir/App.app" ] \
        && [ -d "$user_dir/App.app" ] \
        && [ -d "$custom_dir/App.app" ]; then
        log_pass "custom install: canonical bundles preserved and selected bundle verified"
    else
        log_fail "custom install: expected all three bundles intact and verification success (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
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

# ===========================================================================
# Selected/current-bundle shutdown scenarios (pre-install hardening):
# ensure_bundle_process_stopped() / terminate_bundle_processes() must confirm, by
# executable path, that the bundle about to be replaced has no running process — never by
# name alone, and never a process from a different bundle.
# ===========================================================================

# Scenario: selected bundle has no running process → no-op, no error.
test_selected_bundle_no_running_process() {
    local root="$WORKDIR/sel1" exec_name="fakeexecsel1"
    local sel_bundle="$root/Selected/App.app"
    mkdir -p "$root/Selected"
    make_fake_bundle "$sel_bundle" "$exec_name"

    run_scenario 'ensure_bundle_process_stopped "$SEL_BUNDLE"' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle"

    if [ "$SCENARIO_EXIT" -eq 0 ] && [ -d "$sel_bundle" ]; then
        log_pass "selected bundle, no running process: no-op"
    else
        log_fail "selected bundle, no running process: expected clean no-op (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# Scenario: selected bundle has one running process, exits on SIGTERM → confirmed stopped.
test_selected_bundle_process_exits_on_sigterm() {
    local root="$WORKDIR/sel2" exec_name="fakeexecsel2"
    local sel_bundle="$root/Selected/App.app"
    mkdir -p "$root/Selected"
    make_fake_bundle "$sel_bundle" "$exec_name"

    local pid
    pid="$(start_fake_process "$sel_bundle" "$exec_name" 20)"

    run_scenario 'ensure_bundle_process_stopped "$SEL_BUNDLE"' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    kill -0 "$pid" 2>/dev/null && ok=0  # must be gone (SIGTERM was enough)

    if [ "$ok" -eq 1 ]; then
        log_pass "selected bundle, SIGTERM-responsive process: stopped, exit 0"
    else
        log_fail "selected bundle, SIGTERM-responsive process: expected stopped (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
        kill -9 "$pid" 2>/dev/null || true
    fi
}

# Scenario: selected bundle process ignores SIGTERM → escalates to SIGKILL, still confirmed
# stopped, still exit 0.
test_selected_bundle_process_requires_sigkill() {
    local root="$WORKDIR/sel3" exec_name="fakeexecsel3"
    local sel_bundle="$root/Selected/App.app"
    mkdir -p "$root/Selected"
    make_fake_bundle "$sel_bundle" "$exec_name" stubborn

    local pid
    pid="$(start_fake_process "$sel_bundle" "$exec_name" 20)"

    run_scenario 'ensure_bundle_process_stopped "$SEL_BUNDLE"' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    case "$SCENARIO_OUTPUT" in *"SIGKILL"*) ;; *) ok=0 ;; esac
    kill -0 "$pid" 2>/dev/null && ok=0  # must be gone even though it ignored SIGTERM

    if [ "$ok" -eq 1 ]; then
        log_pass "selected bundle, SIGTERM-ignoring process: escalated to SIGKILL, stopped, exit 0"
    else
        log_fail "selected bundle, SIGTERM-ignoring process: expected SIGKILL escalation + stopped (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
        kill -9 "$pid" 2>/dev/null || true
    fi
}

# Scenario: selected bundle process cannot be confirmed stopped → install aborts (nonzero
# exit), no false success logged. Simulated by shadowing `kill` as a no-op inside the
# scenario (a real process cannot ignore SIGKILL, so this is the honest way to exercise
# "even SIGKILL didn't work" without relying on undefined behavior).
test_selected_bundle_cannot_be_stopped_aborts() {
    local root="$WORKDIR/sel4" exec_name="fakeexecsel4"
    local sel_bundle="$root/Selected/App.app"
    mkdir -p "$root/Selected"
    make_fake_bundle "$sel_bundle" "$exec_name" stubborn

    local pid
    pid="$(start_fake_process "$sel_bundle" "$exec_name" 20)"

    run_scenario '
        kill() { return 0; }  # simulate signals never actually reaching the process
        ensure_bundle_process_stopped "$SEL_BUNDLE"
    ' APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle"

    local ok=1
    [ "$SCENARIO_EXIT" -ne 0 ] || ok=0
    case "$SCENARIO_OUTPUT" in *"ERROR:"*"Refusing to proceed"*) ;; *) ok=0 ;; esac
    case "$SCENARIO_OUTPUT" in *"Installed to"*|*"Verified exactly one"*) ok=0 ;; esac  # no false success

    kill -9 "$pid" 2>/dev/null || true  # real cleanup, outside the shadowed scenario

    if [ "$ok" -eq 1 ]; then
        log_pass "selected bundle, unstoppable process: aborts nonzero, no false success logged"
    else
        log_fail "selected bundle, unstoppable process: expected nonzero abort + clear error + no success (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# Scenario: a process sharing the same executable name but running from a DIFFERENT
# bundle (not the selected one) must never be touched by ensure_bundle_process_stopped.
test_selected_bundle_shutdown_ignores_other_bundle() {
    local root="$WORKDIR/sel5" exec_name="fakeexecsel5"
    local sel_bundle="$root/Selected/App.app" other_bundle="$root/Unrelated/App.app"
    mkdir -p "$root/Selected" "$root/Unrelated"
    make_fake_bundle "$sel_bundle" "$exec_name"
    make_fake_bundle "$other_bundle" "$exec_name"

    # Only the OTHER (non-selected) bundle has a running process; the selected one has
    # none. ensure_bundle_process_stopped for the selected bundle must not touch it.
    local other_pid
    other_pid="$(start_fake_process "$other_bundle" "$exec_name" 20)"

    run_scenario 'ensure_bundle_process_stopped "$SEL_BUNDLE"' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    kill -0 "$other_pid" 2>/dev/null || ok=0  # unrelated-bundle process must survive

    kill "$other_pid" 2>/dev/null || true
    wait "$other_pid" 2>/dev/null || true

    if [ "$ok" -eq 1 ]; then
        log_pass "selected bundle shutdown: process from an unrelated bundle (same exec name) survives"
    else
        log_fail "selected bundle shutdown: expected unrelated-bundle process to survive (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# Scenario: selected-bundle and alternate-bundle process handling compose correctly in the
# same run — both get stopped where running, only the alternate bundle gets removed.
test_selected_and_alternate_compose() {
    local root="$WORKDIR/sel6" exec_name="fakeexecsel6"
    local sys_dir="$root/SystemApps" user_dir="$root/UserApps"
    mkdir -p "$sys_dir" "$user_dir"
    make_fake_bundle "$sys_dir/App.app" "$exec_name"
    make_fake_bundle "$user_dir/App.app" "$exec_name"

    local selected_pid alt_pid
    selected_pid="$(start_fake_process "$sys_dir/App.app" "$exec_name" 20)"
    alt_pid="$(start_fake_process "$user_dir/App.app" "$exec_name" 20)"

    run_scenario '
        ensure_bundle_process_stopped "$INSTALL_DIR/$APP_NAME.app"
        cleanup_alternate_install
    ' APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$sys_dir" USER_INSTALL_DIR="$user_dir" \
        INSTALL_DIR="$sys_dir" HOME="$root/home"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    kill -0 "$selected_pid" 2>/dev/null && ok=0   # selected bundle's OWN old process stopped too
    kill -0 "$alt_pid" 2>/dev/null && ok=0         # alternate bundle's process stopped
    [ -d "$sys_dir/App.app" ] || ok=0              # selected bundle directory remains
    [ ! -e "$user_dir/App.app" ] || ok=0           # alternate bundle directory removed

    kill -9 "$selected_pid" "$alt_pid" 2>/dev/null || true

    if [ "$ok" -eq 1 ]; then
        log_pass "selected + alternate compose: both processes stopped, only alternate bundle removed"
    else
        log_fail "selected + alternate compose: unexpected result (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# Scenario: no replacement happens before selected-bundle shutdown is confirmed — a
# simulated "replace" step (writing a marker file, standing in for install_bundle()'s real
# rm -rf + ditto) must never run when ensure_bundle_process_stopped aborts first.
test_no_replacement_before_shutdown_confirmed() {
    local root="$WORKDIR/sel7" exec_name="fakeexecsel7"
    local sel_bundle="$root/Selected/App.app"
    local marker="$root/replaced.marker"
    mkdir -p "$root/Selected"
    make_fake_bundle "$sel_bundle" "$exec_name" stubborn

    local pid
    pid="$(start_fake_process "$sel_bundle" "$exec_name" 20)"

    run_scenario '
        kill() { return 0; }
        ensure_bundle_process_stopped "$SEL_BUNDLE"
        : > "$MARKER"   # stands in for install_bundle()'"'"'s rm -rf + ditto
    ' APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home" \
        SEL_BUNDLE="$sel_bundle" MARKER="$marker"

    local ok=1
    [ "$SCENARIO_EXIT" -ne 0 ] || ok=0
    [ ! -e "$marker" ] || ok=0  # the "replace" step must never have run

    kill -9 "$pid" 2>/dev/null || true

    if [ "$ok" -eq 1 ]; then
        log_pass "no replacement before confirmed shutdown: replace step never ran"
    else
        log_fail "no replacement before confirmed shutdown: replace step ran when it must not have (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
    fi
}

# Scenario: paths containing spaces are handled safely for selected-bundle shutdown too.
test_selected_bundle_paths_with_spaces() {
    local root="$WORKDIR/sel8 with space" exec_name="fakeexecsel8"
    local sel_bundle="$root/Selected App/App.app"
    mkdir -p "$root/Selected App"
    make_fake_bundle "$sel_bundle" "$exec_name"

    local pid
    pid="$(start_fake_process "$sel_bundle" "$exec_name" 20)"

    run_scenario 'ensure_bundle_process_stopped "$SEL_BUNDLE"' \
        APP_NAME=App EXECUTABLE_NAME="$exec_name" \
        SYSTEM_INSTALL_DIR="$root/Sys" USER_INSTALL_DIR="$root/User" \
        INSTALL_DIR="$root/Sys" HOME="$root/home with space" \
        SEL_BUNDLE="$sel_bundle"

    local ok=1
    [ "$SCENARIO_EXIT" -eq 0 ] || ok=0
    kill -0 "$pid" 2>/dev/null && ok=0

    if [ "$ok" -eq 1 ]; then
        log_pass "selected bundle shutdown: paths with spaces handled safely"
    else
        log_fail "selected bundle shutdown: expected clean stop with spaced paths (exit=$SCENARIO_EXIT): $SCENARIO_OUTPUT"
        kill -9 "$pid" 2>/dev/null || true
    fi
}

main() {
    echo "Building test sleeper helpers..."
    build_sleeper
    build_stubborn_sleeper

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
    test_custom_install_preserves_standard_bundles
    test_is_allowed_bundle_path_rejects_degenerate_inputs

    echo "Running selected-bundle shutdown scenarios..."
    test_selected_bundle_no_running_process
    test_selected_bundle_process_exits_on_sigterm
    test_selected_bundle_process_requires_sigkill
    test_selected_bundle_cannot_be_stopped_aborts
    test_selected_bundle_shutdown_ignores_other_bundle
    test_selected_and_alternate_compose
    test_no_replacement_before_shutdown_confirmed
    test_selected_bundle_paths_with_spaces

    echo ""
    echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    [ "$FAIL_COUNT" -eq 0 ]
}

main
