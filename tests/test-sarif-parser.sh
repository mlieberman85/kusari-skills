#!/usr/bin/env bash
# test-sarif-parser.sh — Validation tests for SARIF parser functions
# Runs parse-sarif.sh functions against test fixtures and validates output.
# Exit 0 if all tests pass, exit 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Source the parser
# shellcheck source=../plugins/kusari/skills/change-evaluate/scripts/parse-sarif.sh
source "$PROJECT_ROOT/plugins/kusari/skills/change-evaluate/scripts/parse-sarif.sh"

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
# Test 1: Clean scan fixture
# ============================================================
echo ""
echo "=== Test: clean-scan.json ==="

CLEAN_RESULT=$(parse_scan_result "$FIXTURES_DIR/clean-scan.json")
CLEAN_CODE=$(extract_code_mitigations "$FIXTURES_DIR/clean-scan.json")
CLEAN_DEPS=$(extract_dependency_mitigations "$FIXTURES_DIR/clean-scan.json")

assert_eq "clean: should_proceed" "true" "$(echo "$CLEAN_RESULT" | jq -r '.should_proceed')"
assert_eq "clean: health_score" "5" "$(echo "$CLEAN_RESULT" | jq -r '.health_score')"
assert_eq "clean: severity" "note" "$(echo "$CLEAN_RESULT" | jq -r '.severity')"
assert_eq "clean: code_mitigation_count" "0" "$(echo "$CLEAN_RESULT" | jq -r '.code_mitigation_count')"
assert_eq "clean: dependency_mitigation_count" "0" "$(echo "$CLEAN_RESULT" | jq -r '.dependency_mitigation_count')"
assert_eq "clean: failed_analysis" "false" "$(echo "$CLEAN_RESULT" | jq -r '.failed_analysis')"
assert_eq "clean: console_url" "https://app.kusari.dev/repos/example-org/example-repo/scans/abc123" "$(echo "$CLEAN_RESULT" | jq -r '.console_url')"
assert_eq "clean: code mitigations array empty" "0" "$(echo "$CLEAN_CODE" | jq 'length')"
assert_eq "clean: dependency mitigations array empty" "0" "$(echo "$CLEAN_DEPS" | jq 'length')"

# ============================================================
# Test 2: Code mitigations fixture
# ============================================================
echo ""
echo "=== Test: code-mitigations.json ==="

CODE_RESULT=$(parse_scan_result "$FIXTURES_DIR/code-mitigations.json")
CODE_MITS=$(extract_code_mitigations "$FIXTURES_DIR/code-mitigations.json")
CODE_DEPS=$(extract_dependency_mitigations "$FIXTURES_DIR/code-mitigations.json")

assert_eq "code: should_proceed" "false" "$(echo "$CODE_RESULT" | jq -r '.should_proceed')"
assert_eq "code: health_score" "3" "$(echo "$CODE_RESULT" | jq -r '.health_score')"
assert_eq "code: severity" "warning" "$(echo "$CODE_RESULT" | jq -r '.severity')"
assert_eq "code: code_mitigation_count" "2" "$(echo "$CODE_RESULT" | jq -r '.code_mitigation_count')"
assert_eq "code: dependency_mitigation_count" "1" "$(echo "$CODE_RESULT" | jq -r '.dependency_mitigation_count')"
assert_eq "code: failed_analysis" "false" "$(echo "$CODE_RESULT" | jq -r '.failed_analysis')"
assert_eq "code: console_url" "https://app.kusari.dev/repos/example-org/example-repo/scans/def456" "$(echo "$CODE_RESULT" | jq -r '.console_url')"

# Verify code mitigation details
assert_eq "code: mitigations array length" "2" "$(echo "$CODE_MITS" | jq 'length')"
assert_eq "code: first file_path" "src/auth/login.py" "$(echo "$CODE_MITS" | jq -r '.[0].file_path')"
assert_eq "code: first line_number" "45" "$(echo "$CODE_MITS" | jq -r '.[0].line_number')"
assert_eq "code: second file_path" "src/api/handlers.py" "$(echo "$CODE_MITS" | jq -r '.[1].file_path')"
assert_eq "code: second line_number" "112" "$(echo "$CODE_MITS" | jq -r '.[1].line_number')"

# Verify dependency mitigation
assert_eq "code: dependency mitigations array length" "1" "$(echo "$CODE_DEPS" | jq 'length')"

# ============================================================
# Test 3: Dependency-only mitigations fixture
# ============================================================
echo ""
echo "=== Test: dependency-mitigations.json ==="

DEP_RESULT=$(parse_scan_result "$FIXTURES_DIR/dependency-mitigations.json")
DEP_CODE=$(extract_code_mitigations "$FIXTURES_DIR/dependency-mitigations.json")
DEP_MITS=$(extract_dependency_mitigations "$FIXTURES_DIR/dependency-mitigations.json")

assert_eq "dep: should_proceed" "true" "$(echo "$DEP_RESULT" | jq -r '.should_proceed')"
assert_eq "dep: health_score" "4" "$(echo "$DEP_RESULT" | jq -r '.health_score')"
assert_eq "dep: severity" "warning" "$(echo "$DEP_RESULT" | jq -r '.severity')"
assert_eq "dep: code_mitigation_count" "0" "$(echo "$DEP_RESULT" | jq -r '.code_mitigation_count')"
assert_eq "dep: dependency_mitigation_count" "2" "$(echo "$DEP_RESULT" | jq -r '.dependency_mitigation_count')"
assert_eq "dep: failed_analysis" "false" "$(echo "$DEP_RESULT" | jq -r '.failed_analysis')"
assert_eq "dep: console_url" "https://app.kusari.dev/repos/example-org/example-repo/scans/ghi789" "$(echo "$DEP_RESULT" | jq -r '.console_url')"
assert_eq "dep: code mitigations array empty" "0" "$(echo "$DEP_CODE" | jq 'length')"
assert_eq "dep: dependency mitigations array length" "2" "$(echo "$DEP_MITS" | jq 'length')"

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
