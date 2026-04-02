# Research: MCP Scan Fallback

**Feature**: 002-mcp-scan-fallback | **Date**: 2026-03-09

## R1: MCP Server Detection in Claude Code Skill Commands

**Decision**: Detect MCP server availability by attempting to call the `mcp__kusari-inspector__scan_local_changes` tool within the skill command markdown. Claude Code natively resolves MCP tool availability at runtime — if the tool is not configured, the call will fail, which the command can handle as a fallback trigger.

**Rationale**: Claude Code skill commands (markdown) are executed by the AI agent which has direct access to MCP tools. The detection does not need to happen in bash — it happens in the command's instruction flow. The skill command can instruct: "Try the MCP tool first; if unavailable or unreachable, fall back to the bash script."

**Alternatives considered**:
- Bash-level MCP detection: Not feasible — MCP servers are agent-level integrations, not CLI tools accessible from shell.
- Environment variable check: Fragile — MCP server configuration is managed by Claude Code settings, not env vars.
- Pre-flight tool listing: Possible but adds unnecessary complexity; attempting the call directly is simpler.

## R2: MCP Server SARIF Output Compatibility

**Decision**: Request SARIF format from the MCP server via the `output_format` parameter (`output_format: "sarif"`). The MCP server's `scan_local_changes` tool accepts an `output_format` parameter. If SARIF is supported, the response can be written to a temp file and fed into the existing `parse-sarif.sh` pipeline.

**Rationale**: Reusing the existing SARIF parsing pipeline means zero changes to `parse-sarif.sh` and `persist-results.sh`. This keeps the change minimal and ensures output consistency (FR-004, FR-005).

**Alternatives considered**:
- Custom JSON normalizer: Would require a new script to map MCP JSON output to the internal format. More code, more maintenance, more risk of format drift.
- Direct structured output: Skip SARIF entirely and have the command parse MCP response directly. Would bypass the persistence pipeline and break `/kusari.remediate` compatibility.

**Dependency**: If the MCP server does not yet support `output_format: "sarif"`, this is a coordination item with the MCP server developer. The skill should handle this gracefully — if SARIF is not returned, treat it as an MCP error and fall back to CLI.

## R3: Fallback Strategy — Availability vs. Scan Errors

**Decision**: Fall back to CLI only when the MCP server is unreachable/unavailable (tool not configured, connection failure). Scan-level errors from the MCP server (auth failure, invalid repo, parse errors) are reported directly without CLI retry.

**Rationale**: Per clarification session — scan-level errors would likely affect the CLI path equally (same auth, same repo). Retrying wastes time and confuses the error message. Availability errors are different: the MCP server simply isn't there, so CLI is the correct alternative.

**Detection heuristic**:
- MCP tool not available (Claude Code reports tool not found) → CLI fallback
- MCP tool call fails with connection/timeout → CLI fallback
- MCP tool returns scan results with error content → Report error directly

## R4: Command Routing Architecture

**Decision**: The routing logic lives entirely in the `kusari.scan.md` skill command. The command markdown instructs a two-phase approach:
1. Attempt MCP scan (call `mcp__kusari-inspector__scan_local_changes`)
2. On availability failure → fall back to existing `bash .claude/scripts/kusari/scan.sh`

The bash `scan.sh` remains unchanged — it is the CLI-only path. The MCP path bypasses `scan.sh` entirely but feeds its SARIF output into `parse-sarif.sh` and `persist-results.sh` for consistent downstream processing.

**Rationale**: Keeping routing in the command markdown (not bash) is correct because MCP tool calls are agent-level operations. Bash cannot invoke MCP tools. The command markdown is where the agent's decision-making happens.

**Alternatives considered**:
- Unified scan.sh that handles both paths: Not possible — bash cannot call MCP tools.
- New wrapper script: Unnecessary indirection — the command markdown is the natural decision point.

## R5: SARIF Handoff from MCP to Bash Pipeline

**Decision**: When the MCP path succeeds, the command instructs the agent to:
1. Write the SARIF response to a temp file
2. Call `parse-sarif.sh` functions (source the script and invoke `parse_scan_result`, `extract_code_mitigations`, `extract_dependency_mitigations`)
3. Call `persist-results.sh` to save results
4. Output the same JSON structure as `scan.sh`

This means the agent orchestrates the bash pipeline steps that `scan.sh` normally runs, but with MCP-sourced SARIF instead of CLI-sourced SARIF.

**Rationale**: This reuses 100% of the existing parsing and persistence code. The only difference is the source of the SARIF file.

**Alternatives considered**:
- Have scan.sh accept a pre-existing SARIF file: Would require modifying scan.sh to support a `--sarif-file` flag. Viable but adds complexity to the bash layer unnecessarily — the command markdown can orchestrate the individual functions directly.
