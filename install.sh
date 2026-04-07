#!/usr/bin/env bash
# install.sh — Install Kusari security skills into a target repository
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/plugins/kusari"

usage() {
  echo "Usage: $0 <target-repo-path>"
  echo ""
  echo "Installs Kusari security skills into the target repository."
  echo "Copies skill commands and shared scripts into the target's .claude/ directory."
  echo ""
  echo "Alternatively, install via the Claude Code plugin marketplace:"
  echo "  claude plugin marketplace add kusaridev/kusari-skills"
  echo "  claude plugin install kusari@kusari-security"
  echo ""
  echo "Prerequisites in the target repo:"
  echo "  - jq installed (for CLI fallback)"
  echo "  - kusari CLI installed (kusari auth login), OR kusari-inspector MCP server"
  echo "  - Must be a git repository"
  exit 1
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
fi

TARGET="$(cd "$1" 2>/dev/null && pwd)" || { echo "ERROR: Directory not found: $1"; exit 1; }

if [ ! -d "$TARGET/.git" ]; then
  echo "WARNING: $TARGET does not appear to be a git repository."
  read -rp "Continue anyway? [y/N] " confirm
  [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || exit 0
fi

# Clean up old-style installation (pre-plugin layout)
if ls "$TARGET/.claude/commands"/kusari.change.* >/dev/null 2>&1; then
  echo "  MIGRATE Removing old-style skill commands..."
  rm -f "$TARGET/.claude/commands"/kusari.change.*
fi
if [ -d "$TARGET/.claude/scripts/kusari" ]; then
  echo "  MIGRATE Removing old-style scripts directory..."
  rm -rf "$TARGET/.claude/scripts/kusari"
fi

# Copy skill commands as Claude Code slash commands
mkdir -p "$TARGET/.claude/commands"
for skill_dir in "$PLUGIN_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    continue
  fi
  # Extract the command name from the SKILL.md frontmatter
  cmd_name=$(grep -m1 '^name:' "$skill_file" | sed 's/^name: *"*//;s/"*$//')
  if [ -z "$cmd_name" ]; then
    cmd_name="kusari.$skill_name"
  fi
  dest="$TARGET/.claude/commands/$cmd_name.md"
  if [ -f "$dest" ]; then
    echo "  UPDATE  .claude/commands/$cmd_name.md"
  else
    echo "  ADD     .claude/commands/$cmd_name.md"
  fi
  cp "$skill_file" "$dest"
done

# Copy shared scripts (from the kusari-change-evaluate skill which owns the scan pipeline)
SCAN_SCRIPTS="$PLUGIN_DIR/skills/kusari-change-evaluate/scripts"
if [ -d "$SCAN_SCRIPTS" ]; then
  mkdir -p "$TARGET/.claude/scripts/kusari"
  for f in "$SCAN_SCRIPTS"/*.sh; do
    name="$(basename "$f")"
    if [ -f "$TARGET/.claude/scripts/kusari/$name" ]; then
      echo "  UPDATE  .claude/scripts/kusari/$name"
    else
      echo "  ADD     .claude/scripts/kusari/$name"
    fi
    cp "$f" "$TARGET/.claude/scripts/kusari/$name"
    if [ -x "$f" ]; then
      chmod +x "$TARGET/.claude/scripts/kusari/$name"
    fi
  done
fi

echo ""
echo "Installed kusari skills into $TARGET"
echo ""
echo "Available commands:"
echo "  /kusari-change-evaluate   Scan repository for security issues"
echo "  /kusari-change-fix        Review and apply fixes from scan results"
