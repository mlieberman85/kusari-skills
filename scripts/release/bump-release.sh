#!/usr/bin/env bash
# bump-release.sh — Coordinate the three edits for a release bump.
#
# Usage: scripts/release/bump-release.sh <new-version> [--root <dir>]
#
# Arguments:
#   <new-version>   Target version (unprefixed SemVer, e.g. "0.3.0")
#   --root <dir>    Override repo root (for testing against fixture directories)
#
# Performs:
#   1. Rewrites plugins/kusari/.claude-plugin/plugin.json version field
#   2. Graduates CHANGELOG.md's ## Unreleased to ## <version> — <today>
#   3. Rewrites .claude-plugin/marketplace.json plugin source to pinned-ref form
#
# Idempotent: running twice for the same version produces the same result.
# Does NOT stage, commit, tag, or push.
#
# Exit codes:
#   0 — success
#   1 — error
#   2 — usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ── Argument parsing ─────────────────────────────────────────────────

NEW_VERSION=""
OVERRIDE_ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || fail 2 "Usage: bump-release.sh <new-version> [--root <dir>]"
      OVERRIDE_ROOT="$2"; shift 2 ;;
    -*)
      fail 2 "Unknown flag: $1" ;;
    *)
      if [ -z "$NEW_VERSION" ]; then
        NEW_VERSION="$1"; shift
      else
        fail 2 "Unexpected argument: $1"
      fi ;;
  esac
done

[ -n "$NEW_VERSION" ] || fail 2 "Usage: bump-release.sh <new-version> [--root <dir>]"

# Strip v prefix if provided
NEW_VERSION=$(strip_v "$NEW_VERSION")
TAG_VERSION="v${NEW_VERSION}"
TODAY=$(date -u +%Y-%m-%d)

# Resolve paths (override root for testing or use repo root)
if [ -n "$OVERRIDE_ROOT" ]; then
  B_PLUGIN_JSON="${OVERRIDE_ROOT}/plugins/kusari/.claude-plugin/plugin.json"
  B_CHANGELOG="${OVERRIDE_ROOT}/plugins/kusari/CHANGELOG.md"
  B_MARKETPLACE="${OVERRIDE_ROOT}/.claude-plugin/marketplace.json"
else
  # shellcheck disable=SC2153 # These are defined in common.sh, not misspellings
  B_PLUGIN_JSON="$PLUGIN_JSON"
  B_CHANGELOG="$CHANGELOG"
  B_MARKETPLACE="$MARKETPLACE_JSON"
fi

require_jq

# ── 1. Bump plugin.json version ─────────────────────────────────────

[ -f "$B_PLUGIN_JSON" ] || fail 1 "plugin.json not found at ${B_PLUGIN_JSON}"

# Check if already at the target version (idempotent)
current_ver=$(jq -r '.version' "$B_PLUGIN_JSON")
if [ "$current_ver" != "$NEW_VERSION" ]; then
  jq --arg v "$NEW_VERSION" '.version = $v' "$B_PLUGIN_JSON" > "${B_PLUGIN_JSON}.tmp"
  mv "${B_PLUGIN_JSON}.tmp" "$B_PLUGIN_JSON"
fi

# ── 2. Graduate CHANGELOG Unreleased section ─────────────────────────

[ -f "$B_CHANGELOG" ] || fail 1 "CHANGELOG.md not found at ${B_CHANGELOG}"

# Check if already graduated (idempotent — version heading already exists)
if grep -q "^## ${NEW_VERSION} " "$B_CHANGELOG"; then
  : # Already graduated; skip
else
  # Replace "## Unreleased" with "## Unreleased\n\n## <version> — <date>"
  # and keep everything that was under Unreleased under the new version heading.
  awk -v ver="$NEW_VERSION" -v date="$TODAY" '
    /^## Unreleased/ {
      print "# Changelog"
      print ""
      print "## Unreleased"
      print ""
      print "## " ver " \xe2\x80\x94 " date  # em-dash (UTF-8: E2 80 94)
      # Skip the original "## Unreleased" line; subsequent content flows naturally
      next
    }
    # Skip the original "# Changelog" heading (we already printed it)
    /^# Changelog/ { next }
    { print }
  ' "$B_CHANGELOG" > "${B_CHANGELOG}.tmp"
  mv "${B_CHANGELOG}.tmp" "$B_CHANGELOG"
fi

# ── 3. Rewrite marketplace.json source to pinned-ref form ────────────

[ -f "$B_MARKETPLACE" ] || fail 1 "marketplace.json not found at ${B_MARKETPLACE}"

# Check if already pinned to this version (idempotent)
current_ref=$(jq -r '(.plugins[] | select(.name == "kusari") | .source.ref) // "none"' "$B_MARKETPLACE" 2>/dev/null || echo "none")
if [ "$current_ref" != "$TAG_VERSION" ]; then
  jq --arg ref "$TAG_VERSION" '
    .plugins = [.plugins[] | if .name == "kusari" then
      .source = {
        "source": "github",
        "repo": "kusaridev/kusari-skills",
        "ref": $ref,
        "path": "plugins/kusari"
      }
    else . end]
  ' "$B_MARKETPLACE" > "${B_MARKETPLACE}.tmp"
  mv "${B_MARKETPLACE}.tmp" "$B_MARKETPLACE"
fi

echo "Bumped to ${TAG_VERSION}: plugin.json, CHANGELOG.md, marketplace.json updated."
