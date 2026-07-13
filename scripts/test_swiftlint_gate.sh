#!/usr/bin/env bash
# Proves the SwiftLint baseline gate actually works:
#   1. the committed baseline exists and parses as JSON
#   2. strict lint passes against current source when suppressed by a baseline
#   3. a deliberately introduced new violation is NOT suppressed and fails strict lint
#   4. removing that violation restores a passing result
#   5. the committed baseline is never modified by any of the above
#
# NOTE ON PATHS: SwiftLint's baseline keys violations by absolute file path
# (see https://github.com/realm/SwiftLint/issues/5599, open as of SwiftLint
# 0.65.0). The committed .swiftlint-baseline.json is generated for GitHub
# Actions' fixed checkout path (/Users/runner/work/DexDictate_MacOS/DexDictate_MacOS)
# and will only suppress known debt when swiftlint runs from that exact path.
# Steps 2-4 below therefore prove the *mechanism* using a throwaway baseline
# regenerated at whatever path this script is currently running from; they do
# not require the committed baseline to match the current checkout location.
# See docs/SWIFTLINT_DEBT.md for the full explanation.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE=".swiftlint-baseline.json"
TMP_BASELINE=".swiftlint-baseline.gate-test.json"
TMP_VIOLATION_FILE="Sources/DexDictateKit/__GateTestTemporaryViolation.swift"

cleanup() {
  rm -f "$TMP_BASELINE" "$TMP_VIOLATION_FILE"
}
trap cleanup EXIT

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "FAIL: swiftlint is not installed. Install with: brew install swiftlint" >&2
  exit 1
fi

if [[ ! -f "$BASELINE" ]]; then
  echo "FAIL: $BASELINE does not exist" >&2
  exit 1
fi

if ! jq empty "$BASELINE" 2>/dev/null; then
  echo "FAIL: $BASELINE is not valid JSON" >&2
  exit 1
fi
echo "OK: $BASELINE exists and parses (jq)"

baseline_checksum() { shasum -a 256 "$BASELINE" | awk '{print $1}'; }
CHECKSUM_BEFORE="$(baseline_checksum)"

# 1) Regenerate a throwaway baseline for the CURRENT checkout path and prove
#    strict lint passes against current source when suppressed by it.
swiftlint lint --strict --quiet --write-baseline "$TMP_BASELINE" >/dev/null 2>&1 || true

if [[ ! -f "$TMP_BASELINE" ]]; then
  echo "FAIL: swiftlint did not write a baseline to $TMP_BASELINE" >&2
  exit 1
fi

if ! swiftlint lint --strict --quiet --baseline "$TMP_BASELINE" >/tmp/gate_pass.$$ 2>&1; then
  echo "FAIL: strict lint did not pass against current source with a freshly generated baseline" >&2
  cat /tmp/gate_pass.$$ >&2
  rm -f /tmp/gate_pass.$$
  exit 1
fi
rm -f /tmp/gate_pass.$$
echo "OK: strict lint passes against current source (baseline suppresses known debt)"

# 2) Introduce a deterministic new violation via an enabled, non-disabled
#    rule (large_tuple) at a path that exists in no baseline.
cat > "$TMP_VIOLATION_FILE" <<'SWIFT'
import Foundation

enum GateTestTemporaryViolation {
    static let tuple: (Int, Int, Int, Int) = (1, 2, 3, 4)
}
SWIFT

if swiftlint lint --strict --quiet --baseline "$TMP_BASELINE" "$TMP_VIOLATION_FILE" >/tmp/gate_fail.$$ 2>&1; then
  echo "FAIL: deliberately introduced violation did not cause strict lint to fail" >&2
  cat /tmp/gate_fail.$$ >&2
  rm -f /tmp/gate_fail.$$
  exit 1
fi
rm -f /tmp/gate_fail.$$
echo "OK: new violation correctly fails strict lint"

# 3) Remove the temporary violation and prove passing is restored.
rm -f "$TMP_VIOLATION_FILE"

if ! swiftlint lint --strict --quiet --baseline "$TMP_BASELINE" >/tmp/gate_restore.$$ 2>&1; then
  echo "FAIL: strict lint did not pass again after removing the temporary violation" >&2
  cat /tmp/gate_restore.$$ >&2
  rm -f /tmp/gate_restore.$$
  exit 1
fi
rm -f /tmp/gate_restore.$$
echo "OK: passing restored after removing the temporary violation"

# 4) Confirm the committed baseline was never touched.
CHECKSUM_AFTER="$(baseline_checksum)"
if [[ "$CHECKSUM_BEFORE" != "$CHECKSUM_AFTER" ]]; then
  echo "FAIL: committed baseline $BASELINE changed during the gate test" >&2
  exit 1
fi
echo "OK: committed baseline unchanged ($CHECKSUM_BEFORE)"

echo "SwiftLint gate test: PASS"
