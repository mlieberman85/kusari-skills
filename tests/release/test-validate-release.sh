#!/usr/bin/env bash
# test-validate-release.sh — Tests for scripts/release/validate-release.sh
#
# Uses a single "golden" fixture (repo-valid-release/) and programmatically
# breaks one thing per test case in a temp copy. Keeps test count proportionate
# to the risk: ~6 tests for a script that runs once per release.
#
# Usage: bash tests/release/test-validate-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="${REPO_ROOT}/scripts/release/validate-release.sh"
GOLDEN="${SCRIPT_DIR}/fixtures/validate-release/repo-valid-release"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS  $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL  $1" >&2; }

TMPBASE=$(mktemp -d)
trap 'rm -rf "$TMPBASE"' EXIT

# Helper: copy golden fixture to a temp dir, optionally mutate, run validator.
run_test() {
  local test_name="$1"
  local version="$2"
  local expected_exit="$3"
  local expected_error="${4:-}"
  local mutate_fn="${5:-}"

  local tmp="${TMPBASE}/${test_name}"
  cp -R "$GOLDEN" "$tmp"

  # Apply mutation if provided
  if [ -n "$mutate_fn" ]; then
    $mutate_fn "$tmp"
  fi

  local actual_exit=0
  local stderr_output
  stderr_output=$(bash "$VALIDATOR" "$version" --fixture-root "$tmp" 2>&1 >/dev/null) || actual_exit=$?

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    fail "${test_name}: expected exit ${expected_exit}, got ${actual_exit}"
    [ -n "$stderr_output" ] && echo "    stderr: ${stderr_output}" >&2
    return
  fi

  if [ -n "$expected_error" ]; then
    if echo "$stderr_output" | grep -q "$expected_error"; then
      pass "${test_name}"
    else
      fail "${test_name}: expected '${expected_error}' in stderr"
      echo "    stderr: ${stderr_output}" >&2
    fi
  else
    pass "${test_name}"
  fi
}

# Mutations (each takes the fixture dir as $1 and writes the broken state directly)
break_plugin_version() {
  jq '.version = "0.2.0"' "$1/plugin.json" > "$1/plugin.json.tmp" && mv "$1/plugin.json.tmp" "$1/plugin.json"
}
remove_changelog_entry() {
  printf '# Changelog\n\n## Unreleased\n\n## 0.2.0 — 2026-04-08\n\n### Added\n- Old stuff\n' > "$1/CHANGELOG.md"
}
break_marketplace_ref() {
  jq '.plugins[0].source.ref = "v0.2.0"' "$1/marketplace.json" > "$1/marketplace.json.tmp" && mv "$1/marketplace.json.tmp" "$1/marketplace.json"
}
remove_verify_section() {
  printf '# Kusari Plugin\n\nJust a plugin.\n' > "$1/README.md"
}

echo "=== validate-release.sh tests ==="

# Happy path
run_test "happy-path" "v0.3.0" 0

# Bad version format (C1)
run_test "bad-format" "0.3.0" 1 "E1"

# Plugin version mismatch (C3)
run_test "plugin-mismatch" "v0.3.0" 1 "E3" "break_plugin_version"

# Missing changelog entry (C4)
run_test "changelog-missing" "v0.3.0" 1 "E4" "remove_changelog_entry"

# Marketplace ref mismatch (C6)
run_test "marketplace-mismatch" "v0.3.0" 1 "E6" "break_marketplace_ref"

# README missing verify section (C9)
run_test "readme-no-verify" "v0.3.0" 1 "E9" "remove_verify_section"

# Multiple failures reported together (C3 + C4)
multi_break() { break_plugin_version "$1"; remove_changelog_entry "$1"; }
local_tmp="${TMPBASE}/multi"
cp -R "$GOLDEN" "$local_tmp"
multi_break "$local_tmp"
local_exit=0
local_stderr=$(bash "$VALIDATOR" "v0.3.0" --fixture-root "$local_tmp" 2>&1 >/dev/null) || local_exit=$?
if [ "$local_exit" -eq 1 ] && echo "$local_stderr" | grep -q "E3" && echo "$local_stderr" | grep -q "E4"; then
  pass "multi-failures: reports E3 and E4 together"
else
  fail "multi-failures: expected exit 1 with both E3 and E4"
fi

echo ""
echo "---"
echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"
[ "$FAIL_COUNT" -eq 0 ]
