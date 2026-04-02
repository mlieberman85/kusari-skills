#!/usr/bin/env bash
# test-run-kusari-scan.sh — Tests for run_kusari_scan in common.sh
# Uses a mock kusari binary to verify stdout/stderr separation and error handling.
# Exit 0 if all tests pass, exit 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/kusari-test-scan-XXXXXX")
cleanup() { rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT

# Source common.sh (provides run_kusari_scan)
# shellcheck source=../plugins/kusari/skills/kusari-change-evaluate/scripts/common.sh
source "$PROJECT_ROOT/plugins/kusari/skills/kusari-change-evaluate/scripts/common.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "  FAIL: $1 (expected: $2, got: $3)"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label" "$expected" "$actual"
  fi
}

# ============================================================
# Create mock kusari binaries
# ============================================================

# Mock that outputs progress to stderr and SARIF to stdout (normal behavior)
MOCK_OK="$TEST_TMPDIR/kusari-ok"
cat > "$MOCK_OK" <<'SCRIPT'
#!/usr/bin/env bash
echo "Scanning repository..." >&2
echo "Analyzing code..." >&2
echo "Processing results..." >&2
cat "$KUSARI_TEST_FIXTURE"
SCRIPT
chmod +x "$MOCK_OK"

# Mock that outputs progress to stderr and SARIF to stdout, with extra stderr noise
MOCK_NOISY="$TEST_TMPDIR/kusari-noisy"
cat > "$MOCK_NOISY" <<'SCRIPT'
#!/usr/bin/env bash
echo "Scanning repository..." >&2
echo "WARNING: Large repository detected" >&2
echo "Processing..." >&2
echo "[progress] 25%..." >&2
echo "[progress] 50%..." >&2
echo "[progress] 75%..." >&2
echo "[progress] 100%..." >&2
cat "$KUSARI_TEST_FIXTURE"
SCRIPT
chmod +x "$MOCK_NOISY"

# Mock that fails with non-zero exit
MOCK_FAIL="$TEST_TMPDIR/kusari-fail"
cat > "$MOCK_FAIL" <<'SCRIPT'
#!/usr/bin/env bash
echo "Authentication required" >&2
exit 1
SCRIPT
chmod +x "$MOCK_FAIL"

# Mock that succeeds but outputs invalid JSON
MOCK_BAD_JSON="$TEST_TMPDIR/kusari-bad-json"
cat > "$MOCK_BAD_JSON" <<'SCRIPT'
#!/usr/bin/env bash
echo "Some preamble text"
echo "not json at all"
SCRIPT
chmod +x "$MOCK_BAD_JSON"

# ============================================================
# Test 1: Normal scan — SARIF captured cleanly (no stderr in file)
# ============================================================
echo ""
echo "=== Test: stdout/stderr separation ==="

export KUSARI_TEST_FIXTURE="$FIXTURES_DIR/clean-scan.json"

# Prepend mock dir to PATH so "kusari" resolves to our mock
mkdir -p "$TEST_TMPDIR/bin"
cp "$MOCK_OK" "$TEST_TMPDIR/bin/kusari"
export PATH="$TEST_TMPDIR/bin:$PATH"

SARIF_PATH=$(run_kusari_scan "." "main" 2>/dev/null)
ACTUAL_CONTENT=$(cat "$SARIF_PATH")
EXPECTED_CONTENT=$(cat "$FIXTURES_DIR/clean-scan.json")

assert_eq "normal: output is valid JSON" "true" "$(jq empty "$SARIF_PATH" 2>/dev/null && echo true || echo false)"
assert_eq "normal: content matches fixture" "$EXPECTED_CONTENT" "$ACTUAL_CONTENT"
rm -f "$SARIF_PATH"

# ============================================================
# Test 2: Noisy stderr — SARIF still captured cleanly
# ============================================================
echo ""
echo "=== Test: noisy stderr does not corrupt SARIF ==="

export KUSARI_TEST_FIXTURE="$FIXTURES_DIR/code-mitigations.json"
cp "$MOCK_NOISY" "$TEST_TMPDIR/bin/kusari"

SARIF_PATH=$(run_kusari_scan "." "feature" 2>/dev/null)
assert_eq "noisy: output is valid JSON" "true" "$(jq empty "$SARIF_PATH" 2>/dev/null && echo true || echo false)"

ACTUAL_SHOULD_PROCEED=$(jq -r '.runs[0].results[0].properties.should_proceed' "$SARIF_PATH")
assert_eq "noisy: SARIF content intact" "false" "$ACTUAL_SHOULD_PROCEED"
rm -f "$SARIF_PATH"

# ============================================================
# Test 3: Scan failure — returns non-zero, no temp file left
# ============================================================
echo ""
echo "=== Test: scan failure handling ==="

cp "$MOCK_FAIL" "$TEST_TMPDIR/bin/kusari"

SCAN_EXIT=0
run_kusari_scan "." "main" 2>/dev/null || SCAN_EXIT=$?

assert_eq "fail: non-zero exit" "1" "$SCAN_EXIT"

# Verify no orphan temp files from the failed run
ORPHANS=$(find "${TMPDIR:-/tmp}" -name 'kusari-sarif-*' -newer "$TEST_TMPDIR" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "fail: no orphan temp files" "0" "$ORPHANS"

# ============================================================
# Test 4: Invalid JSON output — returns non-zero
# ============================================================
echo ""
echo "=== Test: invalid JSON detection ==="

cp "$MOCK_BAD_JSON" "$TEST_TMPDIR/bin/kusari"

SCAN_EXIT=0
run_kusari_scan "." "main" 2>/dev/null || SCAN_EXIT=$?

assert_eq "bad-json: non-zero exit" "1" "$SCAN_EXIT"

# ============================================================
# Summary
# ============================================================
echo ""
echo "================================"
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
