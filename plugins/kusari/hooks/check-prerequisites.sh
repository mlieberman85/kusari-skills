#!/usr/bin/env bash
# check-prerequisites.sh — Verify runtime prerequisites at session start.
#
# Reads plugins/kusari/prerequisites.json and checks that each declared
# tool is installed (and meets the minimum version when specified).
# This script is the canonical consumer of prerequisites.json for
# install-time enforcement.
#
# Exit codes:
#   0 — all prerequisites satisfied
#   1 — one or more prerequisites missing or too old

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PREREQS_FILE="${PLUGIN_ROOT}/prerequisites.json"

if [ ! -f "$PREREQS_FILE" ]; then
  echo "[kusari plugin] ERROR: prerequisites.json not found at ${PREREQS_FILE}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[kusari plugin] ERROR: jq is required to check prerequisites but is not installed." >&2
  echo "  Install from: https://jqlang.org/" >&2
  exit 1
fi

FAIL_COUNT=0
TOOL_COUNT=$(jq '.tools | length' "$PREREQS_FILE")

for i in $(seq 0 $((TOOL_COUNT - 1))); do
  name=$(jq -r ".tools[$i].name" "$PREREQS_FILE")
  min_version=$(jq -r ".tools[$i].minVersion // empty" "$PREREQS_FILE")
  version_cmd=$(jq -r ".tools[$i].versionCommand // empty" "$PREREQS_FILE")
  download=$(jq -r ".tools[$i].downloadLocation" "$PREREQS_FILE")
  purpose=$(jq -r ".tools[$i].purpose" "$PREREQS_FILE")

  # Check presence
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "[kusari plugin] Prerequisite '${name}' not found. ${purpose}." >&2
    echo "  Install from: ${download}" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Check minimum version (if specified)
  if [ -n "$min_version" ]; then
    # Determine version command
    if [ -n "$version_cmd" ]; then
      ver_output=$(eval "$version_cmd" 2>/dev/null || true)
    else
      ver_output=$("$name" --version 2>/dev/null || true)
    fi

    # Extract first SemVer-shaped token from output
    installed_version=$(echo "$ver_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

    if [ -z "$installed_version" ]; then
      echo "[kusari plugin] WARNING: could not parse version for '${name}'; skipping version check." >&2
      continue
    fi

    # Compare versions (major.minor.patch numeric comparison)
    IFS='.' read -r req_major req_minor req_patch <<< "$min_version"
    IFS='.' read -r inst_major inst_minor inst_patch <<< "$installed_version"

    version_ok=true
    if [ "$inst_major" -lt "$req_major" ]; then
      version_ok=false
    elif [ "$inst_major" -eq "$req_major" ]; then
      if [ "$inst_minor" -lt "$req_minor" ]; then
        version_ok=false
      elif [ "$inst_minor" -eq "$req_minor" ] && [ "$inst_patch" -lt "$req_patch" ]; then
        version_ok=false
      fi
    fi

    if [ "$version_ok" = false ]; then
      echo "[kusari plugin] Prerequisite '${name}' version ${installed_version} is older than required ${min_version}. ${purpose}." >&2
      echo "  Update from: ${download}" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "[kusari plugin] ${FAIL_COUNT} prerequisite(s) not satisfied." >&2
  exit 1
fi

exit 0
