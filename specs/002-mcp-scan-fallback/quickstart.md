# Quickstart: MCP Scan Fallback

**Feature**: 002-mcp-scan-fallback | **Date**: 2026-03-09

## What This Feature Does

Updates the `/kusari.scan` skill to automatically use the `kusari-inspector` MCP server for scanning when it's available, while preserving the existing CLI-based scanning as a seamless fallback.

## Prerequisites

**For MCP scanning** (preferred path):
- `kusari-inspector` MCP server configured in Claude Code settings
- MCP server accessible and authenticated

**For CLI scanning** (fallback path — existing requirements):
- `kusari` CLI v0.21.0+ installed and in PATH
- Authenticated via `kusari auth login`
- `jq` installed

## Usage

Usage is identical to before — just run:

```
/kusari.scan
/kusari.scan main
/kusari.scan HEAD~5
```

The skill automatically detects which scan method is available and uses the best one. The output indicates which method was used.

## How It Works

1. Skill checks if `kusari-inspector` MCP server is available
2. If yes → scans via MCP, parses SARIF, persists results
3. If no → falls back to `kusari` CLI (existing behavior)
4. Results are presented in the same format either way

## Files Changed

| File | Change |
|------|--------|
| `.claude/commands/kusari.scan.md` | Updated: MCP-first routing logic |
| `ai/skills/kusari/commands/kusari.scan.md` | Updated: mirrors commands version |

## Testing

- **MCP path**: Configure the MCP server and run `/kusari.scan`. Verify scan completes and results appear.
- **CLI fallback**: Remove/disable the MCP server and run `/kusari.scan`. Verify CLI scan works as before.
- **Output consistency**: Compare persisted result files from both methods — structure should be identical.
- **Error handling**: Test with MCP configured but returning errors — verify error is reported (no CLI fallback).
