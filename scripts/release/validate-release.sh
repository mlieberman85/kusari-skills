#!/usr/bin/env bash
# validate-release.sh — Check all release-time invariants.
#
# Usage: scripts/release/validate-release.sh <version> [--from <ref>] [--fixture-root <dir>]
#
# Arguments:
#   <version>           Target version in canonical tag form (v<major>.<minor>.<patch>[-<pre>])
#   --from <ref>        Git ref to validate against (default: HEAD)
#   --fixture-root <dir> Override file paths to read from a fixture directory (for testing)
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed
#   2 — usage error
#   3 — environment error
#
# All checks run; failures are not short-circuited. Every failure is
# reported on stderr with its error code (E1–E9).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ── Argument parsing ─────────────────────────────────────────────────

VERSION=""
FROM_REF="HEAD"
FIXTURE_ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      [ $# -ge 2 ] || fail 2 "Usage: validate-release.sh <version> [--from <ref>] [--fixture-root <dir>]"
      FROM_REF="$2"; shift 2 ;;
    --fixture-root)
      [ $# -ge 2 ] || fail 2 "Usage: validate-release.sh <version> [--from <ref>] [--fixture-root <dir>]"
      FIXTURE_ROOT="$2"; shift 2 ;;
    -*)
      fail 2 "Unknown flag: $1" ;;
    *)
      if [ -z "$VERSION" ]; then
        VERSION="$1"; shift
      else
        fail 2 "Unexpected argument: $1"
      fi ;;
  esac
done

[ -n "$VERSION" ] || fail 2 "Usage: validate-release.sh <version> [--from <ref>] [--fixture-root <dir>]"

# ── Resolve file paths (real repo or fixture) ────────────────────────

if [ -n "$FIXTURE_ROOT" ]; then
  F_PLUGIN_JSON="${FIXTURE_ROOT}/plugin.json"
  F_CHANGELOG="${FIXTURE_ROOT}/CHANGELOG.md"
  F_MARKETPLACE="${FIXTURE_ROOT}/marketplace.json"
  F_README="${FIXTURE_ROOT}/README.md"
else
  F_PLUGIN_JSON="$PLUGIN_JSON"
  F_CHANGELOG="$CHANGELOG"
  F_MARKETPLACE="$MARKETPLACE_JSON"
  F_README="$README"
fi

require_jq

# ── Check loop ───────────────────────────────────────────────────────

FAIL_COUNT=0

check_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "$1" >&2
}

BARE_VERSION=$(strip_v "$VERSION")

# C1: version format
if ! is_valid_tag_version "$VERSION"; then
  check_fail "E1: version format invalid: '${VERSION}' does not match v<major>.<minor>.<patch>[-<prerelease>]"
fi

# C2: tag must not already exist (skip in fixture mode — can't check git tags against a fixture)
if [ -z "$FIXTURE_ROOT" ]; then
  if git rev-parse "refs/tags/${VERSION}" >/dev/null 2>&1; then
    check_fail "E2: version already released: tag '${VERSION}' already exists"
  fi
fi

# C3: plugin.json version must match
if [ -f "$F_PLUGIN_JSON" ]; then
  plugin_ver=$(jq -r '.version' "$F_PLUGIN_JSON")
  if [ "$plugin_ver" != "$BARE_VERSION" ]; then
    check_fail "E3: plugin.json version mismatch: expected ${BARE_VERSION}, found ${plugin_ver}"
  fi
else
  check_fail "E3: plugin.json not found at ${F_PLUGIN_JSON}"
fi

# C4: CHANGELOG has heading for this version
# Accept both em-dash (—) and double-hyphen (--)
HAS_CHANGELOG_HEADING=false
if [ -f "$F_CHANGELOG" ]; then
  if grep -qE "^## ${BARE_VERSION//./\\.} " "$F_CHANGELOG" 2>/dev/null; then
    HAS_CHANGELOG_HEADING=true
  else
    check_fail "E4: CHANGELOG missing entry for: ${BARE_VERSION}"
  fi
else
  check_fail "E4: CHANGELOG.md not found at ${F_CHANGELOG}"
fi

# C5: CHANGELOG section is non-empty (has at least one bullet under a ### subsection)
if [ "$HAS_CHANGELOG_HEADING" = true ]; then
  # Extract the section: lines after the version heading until the next ## heading or EOF
  section=$(awk -v ver="$BARE_VERSION" '
    $0 ~ "^## " ver " " { found=1; next }
    found && /^## [0-9]/ { exit }
    found { print }
  ' "$F_CHANGELOG")
  if ! echo "$section" | grep -qE '^- '; then
    check_fail "E5: CHANGELOG entry empty: section for ${BARE_VERSION} has no bulleted content"
  fi
fi

# C6: marketplace.json source.ref matches
if [ -f "$F_MARKETPLACE" ]; then
  mkt_source_type=$(jq -r '(.plugins[] | select(.name == "kusari") | .source | type)' "$F_MARKETPLACE" 2>/dev/null || echo "unknown")

  if [ "$mkt_source_type" = "object" ]; then
    mkt_source=$(jq -r '(.plugins[] | select(.name == "kusari") | .source.source) // "unknown"' "$F_MARKETPLACE")
    mkt_ref=$(jq -r '(.plugins[] | select(.name == "kusari") | .source.ref) // "null"' "$F_MARKETPLACE")
    mkt_path=$(jq -r '(.plugins[] | select(.name == "kusari") | .source.path) // "null"' "$F_MARKETPLACE")

    errors=""
    [ "$mkt_source" = "github" ] || errors="${errors} source.source=${mkt_source} (expected github);"
    [ "$mkt_ref" = "$VERSION" ] || errors="${errors} source.ref=${mkt_ref} (expected ${VERSION});"
    [ "$mkt_path" = "plugins/kusari" ] || errors="${errors} source.path=${mkt_path} (expected plugins/kusari);"

    if [ -n "$errors" ]; then
      check_fail "E6: marketplace.json source.ref mismatch:${errors}"
    fi
  else
    check_fail "E6: marketplace.json source.ref mismatch: plugin source is not an object (found type '${mkt_source_type}', expected pinned-ref object form)"
  fi
else
  check_fail "E6: marketplace.json not found at ${F_MARKETPLACE}"
fi

# C7: working tree clean (skip in fixture mode)
if [ -z "$FIXTURE_ROOT" ]; then
  if ! git diff --quiet "$FROM_REF" 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    check_fail "E7: working tree has uncommitted changes"
  fi
fi

# C8: Unreleased section is empty
if [ -f "$F_CHANGELOG" ]; then
  unreleased_content=$(awk '
    /^## Unreleased/ { found=1; next }
    found && /^## / { exit }
    found && !/^$/ { print }
  ' "$F_CHANGELOG")
  if [ -n "$unreleased_content" ]; then
    check_fail "E8: Unreleased section is non-empty: found content that should have been graduated"
  fi
fi

# C9: README has a Verifying section with slsa-verifier and cosign
if [ -f "$F_README" ]; then
  # Check for a heading matching ## Verifying (case-insensitive)
  if ! grep -qiE '^##\s+Verifying' "$F_README"; then
    check_fail "E9: README missing verification section: no heading matching '## Verifying' found"
  else
    # Extract section from the Verifying heading to the next ## heading or EOF
    verify_section=$(awk '/^## [Vv]erifying/{found=1; next} found && /^## /{exit} found{print}' "$F_README")
    if ! echo "$verify_section" | grep -q "slsa-verifier"; then
      check_fail "E9: README verification section missing 'slsa-verifier' reference"
    fi
    if ! echo "$verify_section" | grep -q "cosign"; then
      check_fail "E9: README verification section missing 'cosign' reference"
    fi
  fi
else
  check_fail "E9: README not found at ${F_README}"
fi

# ── Result ───────────────────────────────────────────────────────────

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "${FAIL_COUNT} check(s) failed" >&2
  exit 1
fi

echo "OK: ${VERSION} release invariants validated"
exit 0
