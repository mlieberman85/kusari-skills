#!/usr/bin/env bash
# scan.sh — Orchestrator for Kusari security scan pipeline
#
# Usage: bash <skill_dir>/scripts/scan.sh [revision]
#
# Validates prerequisites, runs the scan, parses SARIF,
# and outputs a structured JSON object to stdout.
#
# Exit codes:
#   0 — success
#   1 — prerequisite failure (missing tool)
#   2 — scan failure
#   3 — parse failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper scripts (paths resolved at runtime via SCRIPT_DIR)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/parse-sarif.sh"

# Cleanup temp files on exit
SARIF_TMP=""
cleanup() {
  [ -n "$SARIF_TMP" ] && rm -f "$SARIF_TMP"
}
trap cleanup EXIT

# --- Step 1: Validate prerequisites ---

check_git_repo || exit 1
check_kusari_cli || exit 1

if ! command -v jq >/dev/null 2>&1; then
  format_error "jq is required but not installed."
  echo "Install jq: brew install jq (macOS) or apt-get install jq (Linux)" >&2
  exit 1
fi

# --- Step 2: Determine revision ---

REVISION="${1:-}"
if [ -z "$REVISION" ]; then
  REVISION=$(detect_default_branch) || exit 1
  echo "Using default branch: $REVISION" >&2
fi

export KUSARI_GIT_REVISION="$REVISION"

# --- Step 3: Run the scan ---

echo "Running Kusari scan against revision '$REVISION'..." >&2

SARIF_TMP=$(run_kusari_scan "." "$REVISION") || exit 2

# --- Step 4: Parse SARIF ---

scan_json=$(parse_scan_result "$SARIF_TMP") || {
  format_error "Failed to parse scan result from SARIF."
  exit 3
}

code_mits_json=$(extract_code_mitigations "$SARIF_TMP") || {
  format_error "Failed to extract code mitigations from SARIF."
  exit 3
}

dep_mits_json=$(extract_dependency_mitigations "$SARIF_TMP") || {
  format_error "Failed to extract dependency mitigations from SARIF."
  exit 3
}

# --- Step 5: Output structured JSON ---

jq -n \
  --argjson scan "$scan_json" \
  --argjson code_mitigations "$code_mits_json" \
  --argjson dependency_mitigations "$dep_mits_json" \
  --arg revision "$REVISION" \
  '{
    scan: $scan,
    code_mitigations: $code_mitigations,
    dependency_mitigations: $dependency_mitigations,
    revision: $revision
  }'
