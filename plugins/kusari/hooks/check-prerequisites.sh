#!/usr/bin/env bash
# check-prerequisites.sh — Verify Kusari CLI is available at session start
set -euo pipefail

if ! command -v kusari >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[kusari plugin] Kusari CLI not found.

The kusari-inspector MCP server requires the Kusari CLI to be installed.
Without it, security scanning and remediation skills will not work.

To install (requires v1.0.0+):
  1. Install the Kusari CLI: https://github.com/kusaridev/kusari-cli
  2. Authenticate: kusari auth login
EOF
  exit 1
fi
