#!/usr/bin/env bash
# common.sh — Shared helpers for the release tooling scripts.
# Sourced by validate-release.sh, render-release-notes.sh,
# generate-sbom.sh, and bump-release.sh.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────────

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: not inside a git repository" >&2
  exit 3
}
readonly REPO_ROOT

readonly PLUGIN_DIR="${REPO_ROOT}/plugins/kusari"
readonly PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
readonly CHANGELOG="${PLUGIN_DIR}/CHANGELOG.md"
readonly MARKETPLACE_JSON="${REPO_ROOT}/.claude-plugin/marketplace.json"
readonly PREREQS_JSON="${PLUGIN_DIR}/prerequisites.json"
readonly README="${PLUGIN_DIR}/README.md"

# ── Utilities ────────────────────────────────────────────────────────

# Print an error message to stderr and exit with the given code.
# Usage: fail <exit_code> <message>
fail() {
  local code="$1"; shift
  echo "$*" >&2
  exit "$code"
}

# Assert that jq is available.
require_jq() {
  command -v jq >/dev/null 2>&1 || fail 3 "ERROR: jq is required but not installed."
}

# ── SemVer helpers ───────────────────────────────────────────────────

# Validate a version string matches v-prefixed SemVer with optional prerelease.
# Returns 0 if valid, 1 otherwise.  Does not print anything.
# Accepted: v1.2.3, v0.3.0-rc.1, v0.3.0-beta.2
# Rejected: 1.2.3 (no v), v1.2 (incomplete), vfoo
is_valid_tag_version() {
  local ver="$1"
  [[ "$ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

# Strip leading 'v' prefix if present.
# v0.3.0 → 0.3.0;  0.3.0 → 0.3.0
strip_v() {
  local ver="$1"
  echo "${ver#v}"
}

# Add leading 'v' prefix if absent.
# 0.3.0 → v0.3.0;  v0.3.0 → v0.3.0
ensure_v() {
  local ver="$1"
  if [[ "$ver" == v* ]]; then
    echo "$ver"
  else
    echo "v${ver}"
  fi
}

# Return true if the version has a SemVer prerelease qualifier.
# v0.3.0-rc.1 → true;  v0.3.0 → false
has_prerelease() {
  local ver="$1"
  [[ "$ver" =~ -[a-zA-Z0-9.]+$ ]]
}

# ── Plugin manifest helpers ──────────────────────────────────────────

# Read the "version" field from plugin.json.
# Prints the bare version (no 'v' prefix), e.g. "0.3.0".
read_plugin_version() {
  require_jq
  jq -r '.version' "$PLUGIN_JSON"
}

# Read the marketplace.json plugin entry's source.ref field.
# Prints the ref value or "null" if not present / not an object.
read_marketplace_ref() {
  require_jq
  jq -r '(.plugins[] | select(.name == "kusari") | .source.ref) // "null"' "$MARKETPLACE_JSON"
}

# Read the marketplace.json plugin entry's source type.
# Returns "github" for the pinned form, "string" for the legacy relative-path form.
read_marketplace_source_type() {
  require_jq
  local source_type
  source_type=$(jq -r '(.plugins[] | select(.name == "kusari") | .source | type)' "$MARKETPLACE_JSON")
  if [ "$source_type" = "object" ]; then
    jq -r '(.plugins[] | select(.name == "kusari") | .source.source) // "unknown"' "$MARKETPLACE_JSON"
  else
    echo "string"
  fi
}
