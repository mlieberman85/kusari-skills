#!/usr/bin/env bash
# parse-sarif.sh — SARIF 2.1.0 output parser for Kusari Inspector results
# Source this file; do not execute directly.
#
# Functions:
#   parse_scan_result             — Extract ScanResult entity from SARIF
#   extract_code_mitigations      — Extract CodeMitigation array from SARIF
#   extract_dependency_mitigations — Extract DependencyMitigation array from SARIF
#
# Requires: jq

set -euo pipefail

# Validate jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for SARIF parsing but is not installed." >&2
  echo "Install jq: brew install jq (macOS) or apt-get install jq (Linux)" >&2
  # shellcheck disable=SC2317  # exit is reachable when script is executed directly (not sourced)
  return 1 2>/dev/null || exit 1
fi

# parse_scan_result: Extracts ScanResult entity from a SARIF file.
# Arguments: $1 — path to SARIF JSON file
# Output (stdout): JSON object with ScanResult fields
parse_scan_result() {
  local sarif_file="${1:?Usage: parse_scan_result <sarif_file>}"

  jq -r '
    ([.runs[0].results[] | select(.ruleId == "security-analysis")] | first) as $sa |
    {
      should_proceed:              ($sa.properties.should_proceed),
      health_score:                ($sa.properties.health_score),
      severity:                    ($sa.level),
      justification:               ($sa.properties.justification),
      recommendation:              ($sa.properties.recommendation),
      failed_analysis:             ($sa.properties.failed_analysis // false),
      code_mitigation_count:       ([.runs[0].results[] | select(.ruleId == "code-mitigation")] | length),
      dependency_mitigation_count: ([.runs[0].results[] | select(.ruleId == "dependency-mitigation")] | length),
      console_url:                 ($sa.helpUri // null)
    }
  ' "$sarif_file"
}

# extract_code_mitigations: Extracts CodeMitigation array from a SARIF file.
# Arguments: $1 — path to SARIF JSON file
# Output (stdout): JSON array of CodeMitigation objects
extract_code_mitigations() {
  local sarif_file="${1:?Usage: extract_code_mitigations <sarif_file>}"

  jq -r '
    [
      .runs[0].results[]
      | select(.ruleId == "code-mitigation")
      | {
          file_path:    .locations[0].physicalLocation.artifactLocation.uri,
          line_number:  .locations[0].physicalLocation.region.startLine,
          code_snippet: .locations[0].physicalLocation.region.snippet.text,
          description:  .message.text,
          severity:     .level
        }
    ]
  ' "$sarif_file"
}

# extract_dependency_mitigations: Extracts DependencyMitigation array from a SARIF file.
# Arguments: $1 — path to SARIF JSON file
# Output (stdout): JSON array of DependencyMitigation objects
extract_dependency_mitigations() {
  local sarif_file="${1:?Usage: extract_dependency_mitigations <sarif_file>}"

  jq -r '
    [
      .runs[0].results[]
      | select(.ruleId == "dependency-mitigation")
      | {
          description: .message.text,
          severity:    .level
        }
    ]
  ' "$sarif_file"
}
