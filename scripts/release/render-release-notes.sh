#!/usr/bin/env bash
# render-release-notes.sh — Extract a version's CHANGELOG section as release notes.
#
# Usage: scripts/release/render-release-notes.sh <version> [<changelog-path>]
#
# Arguments:
#   <version>          Version to extract (with or without v prefix)
#   <changelog-path>   Path to CHANGELOG.md (default: plugins/kusari/CHANGELOG.md)
#
# Output (stdout): The body of the matching version section (everything after
#   the ## heading, up to the next ## heading or EOF), with trailing blank
#   lines trimmed. The heading itself is NOT included.
#
# Exit codes:
#   0 — section found and emitted
#   1 — no matching section found
#   2 — usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

[ $# -ge 1 ] || fail 2 "Usage: render-release-notes.sh <version> [<changelog-path>]"

VERSION="$1"
CHANGELOG_PATH="${2:-$CHANGELOG}"

BARE_VERSION=$(strip_v "$VERSION")

[ -f "$CHANGELOG_PATH" ] || fail 1 "CHANGELOG not found at ${CHANGELOG_PATH}"

# Extract the section: lines after the matching version heading, up to the
# next ## heading or EOF. Accepts both em-dash (—) and double-hyphen (--).
section=$(awk -v ver="$BARE_VERSION" '
  $0 ~ "^## " ver " " { found=1; next }
  found && /^## / { exit }
  found { print }
' "$CHANGELOG_PATH")

# Check if we found anything
if [ -z "$section" ]; then
  fail 1 "No CHANGELOG section found for version ${BARE_VERSION}"
fi

# Trim trailing blank lines using awk (portable across BSD/GNU)
echo "$section" | awk '
  /[^ \t]/ { for (i=1; i<=bl; i++) print ""; bl=0; print; next }
  { bl++ }
'
