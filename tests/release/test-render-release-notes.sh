#!/usr/bin/env bash
# test-render-release-notes.sh — Tests for scripts/release/render-release-notes.sh
#
# Uses inline heredocs instead of fixture files. Three tests covering the
# critical paths: correct extraction, missing version, and separator tolerance.
#
# Usage: bash tests/release/test-render-release-notes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENDERER="${REPO_ROOT}/scripts/release/render-release-notes.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS  $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL  $1" >&2; }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== render-release-notes.sh tests ==="

# ── Test 1: Extract correct version from multi-version changelog ──────

cat > "${TMPDIR}/multi.md" <<'CHANGELOG'
# Changelog

## Unreleased

### Added
- Unreleased feature (should NOT appear)

## 0.3.0 — 2026-04-15

### Added
- Release process with signing

### Fixed
- Plugin install race condition

## 0.2.0 — 2026-04-08

### Added
- Bundled MCP server (should NOT appear)
CHANGELOG

output=$(bash "$RENDERER" "0.3.0" "${TMPDIR}/multi.md" 2>/dev/null)

if echo "$output" | grep -q "signing" && ! echo "$output" | grep -q "Unreleased" && ! echo "$output" | grep -q "MCP server"; then
  pass "extracts correct version, excludes others and Unreleased"
else
  fail "extraction wrong: got '$output'"
fi

# ── Test 2: Missing version exits 1 ──────────────────────────────────

exit_code=0
bash "$RENDERER" "0.9.0" "${TMPDIR}/multi.md" >/dev/null 2>&1 || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
  pass "missing version exits 1"
else
  fail "missing version: expected exit 1, got ${exit_code}"
fi

# ── Test 3: Accepts both em-dash and double-hyphen separators ─────────

cat > "${TMPDIR}/hyphen.md" <<'CHANGELOG'
# Changelog

## Unreleased

## 0.3.0 -- 2026-04-15

### Security
- Signed releases with SLSA provenance
CHANGELOG

output2=$(bash "$RENDERER" "v0.3.0" "${TMPDIR}/hyphen.md" 2>/dev/null)
if echo "$output2" | grep -q "SLSA provenance"; then
  pass "double-hyphen separator and v-prefix both accepted"
else
  fail "double-hyphen/v-prefix: got '$output2'"
fi

echo ""
echo "---"
echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"
[ "$FAIL_COUNT" -eq 0 ]
