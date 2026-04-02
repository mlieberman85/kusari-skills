# Contract: kusari.scan Skill Command

**Feature**: 002-mcp-scan-fallback | **Date**: 2026-03-09

## Interface

**Invocation**: `/kusari.scan [revision]`

**Input**:
- `$ARGUMENTS` (optional): Git revision to compare against (e.g., `main`, `HEAD~5`, `abc1234`). Defaults to the repository's default branch.

**Output** (presented to developer):
- Health score, status (Clean/Flagged/Error), justification
- Code mitigations with file path, line number, severity, description, flagged code
- Dependency mitigations with severity and description
- Console URL (if available)
- Scan method used (MCP server or CLI)
- Persisted result file path
- Suggestion to run `/kusari.remediate` if code mitigations exist

## Behavior Contract

### Method Selection

```text
1. Attempt MCP scan via mcp__kusari-inspector__scan_local_changes
   - Parameters: repo_path=<repo_root>, base_ref=<revision>, output_format="sarif"
2. If MCP tool unavailable or unreachable → fall back to CLI (step 3)
   If MCP tool returns scan-level error → report error, do NOT fall back
   If MCP tool succeeds → proceed to step 4
3. CLI fallback: bash .claude/scripts/kusari/scan.sh <revision>
   Handle exit codes 1 (prereq), 2 (scan failure), 3 (parse failure)
4. Parse SARIF output (from either method) using parse-sarif.sh functions
5. Persist results using persist-results.sh
6. Present findings to developer
```

### Exit Conditions

| Condition | Behavior |
|-----------|----------|
| MCP available, scan succeeds | Present MCP results, note "Scanned via MCP server" |
| MCP unavailable, CLI succeeds | Present CLI results, note "Scanned via CLI" |
| MCP unavailable, CLI fails | Report CLI error with existing guidance |
| MCP available, MCP scan error | Report MCP error directly, no CLI fallback |
| Both unavailable | Report no scanning method available, provide setup guidance |

### Backward Compatibility

- When MCP server is not configured, behavior is identical to the current implementation
- The `scan.sh` script is not modified — it remains the CLI-only orchestrator
- Persisted file format is unchanged — `/kusari.remediate` continues to work
