#!/usr/bin/env bash
# test-prerequisites-declaration.sh — Tests for prerequisites.json and the
# refactored check-prerequisites.sh hook.
#
# Five tests: schema is valid JSON, hook passes for present tools, hook fails
# for missing tools, hook fails for outdated versions, hook fails when
# prerequisites.json is missing.
#
# Usage: bash tests/release/test-prerequisites-declaration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="${REPO_ROOT}/plugins/kusari/hooks/check-prerequisites.sh"
PREREQS_SOURCE="${REPO_ROOT}/plugins/kusari/prerequisites.json"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS  $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL  $1" >&2; }

TMPBASE=$(mktemp -d)
trap 'rm -rf "$TMPBASE"' EXIT

# Helper: create a temp plugin root with given prerequisites.json, run hook.
run_hook() {
  local test_name="$1"
  local prereqs_content="$2"
  local expected_exit="$3"

  local tmp="${TMPBASE}/${test_name}"
  mkdir -p "${tmp}/hooks"
  echo "$prereqs_content" > "${tmp}/prerequisites.json"
  sed "s|PLUGIN_ROOT=.*|PLUGIN_ROOT=\"${tmp}\"|" "$HOOK_SCRIPT" > "${tmp}/hooks/check-prerequisites.sh"
  chmod +x "${tmp}/hooks/check-prerequisites.sh"

  local actual_exit=0
  bash "${tmp}/hooks/check-prerequisites.sh" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "${test_name}"
  else
    fail "${test_name}: expected exit ${expected_exit}, got ${actual_exit}"
  fi
}

echo "=== prerequisites tests ==="

# Test 1: prerequisites.json is valid JSON with required structure
if jq -e '.tools | length > 0' "$PREREQS_SOURCE" >/dev/null 2>&1; then
  pass "schema: prerequisites.json is valid JSON with non-empty tools array"
else
  fail "schema: prerequisites.json is invalid or empty"
fi

# Test 2: Hook passes when all declared tools are present (bash + jq are in this env)
run_hook "present-tools" '{"tools": [
  {"name": "bash", "minVersion": null, "purl": "pkg:generic/bash", "downloadLocation": "https://gnu.org/software/bash/", "purpose": "shell"},
  {"name": "jq", "minVersion": null, "purl": "pkg:generic/jq", "downloadLocation": "https://jqlang.org/", "purpose": "json"}
]}' 0

# Test 3: Hook fails when a tool is missing
run_hook "missing-tool" '{"tools": [
  {"name": "nonexistent_tool_xyzzy", "minVersion": null, "purl": "pkg:generic/fake", "downloadLocation": "https://example.com", "purpose": "does not exist"}
]}' 1

# Test 4: Hook fails when version is too old (impossibly high requirement)
run_hook "version-too-old" '{"tools": [
  {"name": "bash", "minVersion": "999.0.0", "purl": "pkg:generic/bash", "downloadLocation": "https://gnu.org/software/bash/", "purpose": "shell"}
]}' 1

# Test 5: Hook fails when prerequisites.json is missing
local_tmp="${TMPBASE}/no-prereqs"
mkdir -p "${local_tmp}/hooks"
sed "s|PLUGIN_ROOT=.*|PLUGIN_ROOT=\"${local_tmp}\"|" "$HOOK_SCRIPT" > "${local_tmp}/hooks/check-prerequisites.sh"
chmod +x "${local_tmp}/hooks/check-prerequisites.sh"
local_exit=0
bash "${local_tmp}/hooks/check-prerequisites.sh" >/dev/null 2>&1 || local_exit=$?
if [ "$local_exit" -eq 1 ]; then
  pass "missing-file: exits 1 when prerequisites.json absent"
else
  fail "missing-file: expected exit 1, got ${local_exit}"
fi

echo ""
echo "---"
echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"
[ "$FAIL_COUNT" -eq 0 ]
