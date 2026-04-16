#!/usr/bin/env bash
# lint.sh — Run ShellCheck on all project-owned shell scripts
# Development tool (not a distributed skill artifact).
#
# Usage: bash scripts/lint.sh [--list]
#
# Options:
#   --list    Print discovered script paths without running ShellCheck
#
# Excludes: .specify/ (speckit framework), .git/
# Exit codes:
#   0 — all scripts pass (or --list mode)
#   1 — ShellCheck found issues or prerequisite failure

set -euo pipefail

# Check for ShellCheck
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ERROR: shellcheck is not installed." >&2
  echo "" >&2
  echo "Install ShellCheck:" >&2
  echo "  macOS:  brew install shellcheck" >&2
  echo "  Linux:  apt-get install shellcheck" >&2
  echo "  Other:  https://github.com/koalaman/shellcheck#installing" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Discover project-owned .sh files, excluding framework and git dirs
mapfile -t scripts < <(
  find "$REPO_ROOT" \
    -path "$REPO_ROOT/.specify" -prune -o \
    -path "$REPO_ROOT/.git" -prune -o \
    -name '*.sh' -type f -print \
  | sort
)

if [ "${#scripts[@]}" -eq 0 ]; then
  echo "No shell scripts found to check."
  exit 0
fi

# --list mode: print discovered files and exit
if [ "${1:-}" = "--list" ]; then
  for s in "${scripts[@]}"; do
    echo "${s#"$REPO_ROOT/"}"
  done
  exit 0
fi

echo "Checking ${#scripts[@]} shell script(s)..."

FAIL_COUNT=0
for s in "${scripts[@]}"; do
  rel="${s#"$REPO_ROOT/"}"
  if shellcheck -x "$s"; then
    echo "  PASS  $rel"
  else
    echo "  FAIL  $rel"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "${FAIL_COUNT} script(s) failed ShellCheck."
  exit 1
fi

echo "All scripts passed ShellCheck."
exit 0
