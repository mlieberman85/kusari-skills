#!/usr/bin/env bash
# common.sh — Shared functions for Kusari security skills
# Source this file; do not execute directly.
#
# Functions:
#   check_kusari_cli    — Verify Kusari CLI is installed
#   print_auth_guidance — Print auth guidance (for scan auth failures)
#   check_git_repo      — Verify current directory is a git repo
#   detect_default_branch — Print the default branch name
#   format_error        — Format an error message
#   format_warning      — Format a warning message

set -euo pipefail

# check_kusari_cli: Returns 0 if kusari CLI is in PATH.
# Prints installation guidance to stderr on failure.
check_kusari_cli() {
  if command -v kusari >/dev/null 2>&1; then
    return 0
  fi
  format_error "Kusari CLI is not installed or not in PATH."
  cat >&2 <<'EOF'

To install the Kusari CLI:
  1. Visit https://github.com/kusaridev/kusari-cli for installation instructions
  2. Ensure the 'kusari' binary is available in your PATH
  3. Verify with: kusari --version
EOF
  return 1
}

# print_auth_guidance: Prints authentication guidance to stderr.
# Call this when a kusari command fails with an auth error.
print_auth_guidance() {
  format_error "Not authenticated with the Kusari platform."
  cat >&2 <<'EOF'

To authenticate:
  1. Run: kusari auth login
  2. Complete the browser-based authentication flow
  3. Then retry the scan
EOF
}

# check_git_repo: Returns 0 if the current directory is a git repository.
# Prints guidance to stderr on failure.
check_git_repo() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi
  format_error "Not a git repository."
  cat >&2 <<'EOF'

Kusari repo scan requires a git repository.
  - If this is a new project, run: git init
  - If this is a checkout, ensure you are inside the repository directory
EOF
  return 1
}

# detect_default_branch: Prints the default branch name to stdout.
# Uses git symbolic-ref with fallback to common branch names.
# Returns exit code 1 if no default branch can be detected.
detect_default_branch() {
  # Try symbolic ref first (most reliable)
  local branch
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's@^refs/remotes/origin/@@') || true

  if [ -n "$branch" ]; then
    echo "$branch"
    return 0
  fi

  # Fallback: check common names
  for candidate in main master; do
    if git rev-parse --verify "origin/$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  # Last resort: check local branches
  for candidate in main master; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  format_error "Could not detect the default branch."
  echo "Specify a git revision explicitly, e.g.: /kusari-change-evaluate main" >&2
  return 1
}

# format_error: Formats an error message to stderr.
# Usage: format_error "Something went wrong"
format_error() {
  echo "ERROR: $1" >&2
}

# format_warning: Formats a warning message to stderr.
# Usage: format_warning "Something might be off"
format_warning() {
  echo "WARNING: $1" >&2
}

# run_kusari_scan: Runs kusari repo scan capturing SARIF to a temp file.
# Arguments:
#   $1 — directory to scan (default: .)
#   $2 — git revision to compare against
# Output (stdout): path to temp file containing SARIF JSON
# Returns: 0 on success, 1 on failure
run_kusari_scan() {
  local scan_dir="${1:-.}"
  local revision="${2:?Usage: run_kusari_scan <dir> <revision>}"

  local sarif_tmp
  sarif_tmp=$(mktemp "${TMPDIR:-/tmp}/kusari-sarif-XXXXXX.json")

  if ! kusari repo scan "$scan_dir" "$revision" --output-format sarif --wait > "$sarif_tmp"; then
    local exit_code=$?
    rm -f "$sarif_tmp"
    format_error "Kusari scan failed (exit code $exit_code)."
    cat >&2 <<'EOF'

Possible causes:
  - Not authenticated: run 'kusari auth login'
  - Repository too large (monorepo): try scanning a subdirectory
  - Network/timeout error: retry the scan
EOF
    return 1
  fi

  # Validate the output is valid JSON
  if ! jq empty "$sarif_tmp" 2>/dev/null; then
    rm -f "$sarif_tmp"
    format_error "Kusari scan produced invalid JSON output."
    return 1
  fi

  echo "$sarif_tmp"
}
