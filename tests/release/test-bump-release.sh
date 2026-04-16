#!/usr/bin/env bash
# test-bump-release.sh — Tests for scripts/release/bump-release.sh
#
# Copies the pre-bump fixture to a temp directory, runs bump-release.sh,
# and compares the result against the expected post-bump fixture.
#
# Usage: bash tests/release/test-bump-release.sh
#
# Exit codes:
#   0 — all tests pass
#   1 — one or more tests failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUMPER="${REPO_ROOT}/scripts/release/bump-release.sh"
FIXTURES="${SCRIPT_DIR}/fixtures/bump-release"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS  $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL  $1" >&2; }

echo "=== bump-release.sh tests ==="

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Copy pre-bump fixture into a temp work area
cp -R "${FIXTURES}/repo-clean-at-v0.2.0/." "${TMPDIR}/"

# Run the bumper
bump_exit=0
bash "$BUMPER" "0.3.0" --root "$TMPDIR" 2>/dev/null || bump_exit=$?

if [ "$bump_exit" -ne 0 ]; then
  fail "bump-release.sh exited with ${bump_exit}"
  echo ""
  echo "---"
  echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"
  exit 1
fi

pass "bump-release: exits 0"

# ── Check plugin.json version bumped ─────────────────────────────────

actual_version=$(jq -r '.version' "${TMPDIR}/plugins/kusari/.claude-plugin/plugin.json")
if [ "$actual_version" = "0.3.0" ]; then
  pass "plugin.json: version updated to 0.3.0"
else
  fail "plugin.json: expected version 0.3.0, got ${actual_version}"
fi

# ── Check marketplace.json source.ref bumped ─────────────────────────

actual_ref=$(jq -r '.plugins[0].source.ref' "${TMPDIR}/.claude-plugin/marketplace.json")
if [ "$actual_ref" = "v0.3.0" ]; then
  pass "marketplace.json: source.ref updated to v0.3.0"
else
  fail "marketplace.json: expected source.ref v0.3.0, got ${actual_ref}"
fi

actual_source_type=$(jq -r '.plugins[0].source.source' "${TMPDIR}/.claude-plugin/marketplace.json")
if [ "$actual_source_type" = "github" ]; then
  pass "marketplace.json: source.source is 'github'"
else
  fail "marketplace.json: expected source.source 'github', got ${actual_source_type}"
fi

actual_path=$(jq -r '.plugins[0].source.path' "${TMPDIR}/.claude-plugin/marketplace.json")
if [ "$actual_path" = "plugins/kusari" ]; then
  pass "marketplace.json: source.path is 'plugins/kusari'"
else
  fail "marketplace.json: expected source.path 'plugins/kusari', got ${actual_path}"
fi

# ── Check CHANGELOG graduated ────────────────────────────────────────

changelog="${TMPDIR}/plugins/kusari/CHANGELOG.md"

# Should have a new ## Unreleased section at the top (empty)
if head -5 "$changelog" | grep -q "^## Unreleased"; then
  pass "CHANGELOG: has ## Unreleased heading at top"
else
  fail "CHANGELOG: missing ## Unreleased heading at top"
fi

# The Unreleased section should be empty (no bullets between it and the version heading)
unreleased_content=$(awk '/^## Unreleased/{found=1; next} found && /^## /{exit} found && !/^$/{print}' "$changelog")
if [ -z "$unreleased_content" ]; then
  pass "CHANGELOG: Unreleased section is empty"
else
  fail "CHANGELOG: Unreleased section still has content: ${unreleased_content}"
fi

# Should have a version heading for 0.3.0
if grep -q "^## 0\.3\.0" "$changelog"; then
  pass "CHANGELOG: has ## 0.3.0 heading"
else
  fail "CHANGELOG: missing ## 0.3.0 heading"
fi

# The 0.3.0 heading should have a date (YYYY-MM-DD)
if grep "^## 0\.3\.0" "$changelog" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
  pass "CHANGELOG: 0.3.0 heading has date"
else
  fail "CHANGELOG: 0.3.0 heading missing date"
fi

# The 0.3.0 section should contain the original Unreleased content
if grep -q "Release process with signing and provenance" "$changelog"; then
  pass "CHANGELOG: graduated content preserved under 0.3.0"
else
  fail "CHANGELOG: graduated content not found under 0.3.0"
fi

# Older version (0.2.0) should still be present
if grep -q "^## 0\.2\.0" "$changelog"; then
  pass "CHANGELOG: older version 0.2.0 preserved"
else
  fail "CHANGELOG: older version 0.2.0 lost"
fi

# ── Idempotency check ────────────────────────────────────────────────

# Running bump again on the already-bumped state for the same version
# should produce the same result (idempotent)
cp -R "${TMPDIR}/." "${TMPDIR}_copy/"
bash "$BUMPER" "0.3.0" --root "${TMPDIR}_copy" 2>/dev/null || true
diff_output=$(diff -r "${TMPDIR}" "${TMPDIR}_copy" 2>&1 || true)
if [ -z "$diff_output" ]; then
  pass "idempotency: running bump twice produces same result"
else
  fail "idempotency: second bump changed files"
  echo "    diff: ${diff_output}" >&2
fi
rm -rf "${TMPDIR}_copy"

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "---"
echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
