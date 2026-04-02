# Implementation Plan: MCP Scan Fallback

**Branch**: `002-mcp-scan-fallback` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-mcp-scan-fallback/spec.md`

## Summary

Update the `/kusari.scan` skill to prefer the `kusari-inspector` MCP server (`scan_local_changes` tool) when available, falling back to the existing CLI-based pipeline otherwise. Both paths produce SARIF output, which is parsed by the existing `parse-sarif.sh` pipeline and persisted identically to `.claude/security/scans/`.

## Technical Context

**Language/Version**: Bash (shell scripts) + Markdown (skill command definitions)
**Primary Dependencies**: Kusari CLI v0.21.0+ (fallback), kusari-inspector MCP server (preferred), jq
**Storage**: Local filesystem (`.claude/security/scans/` for persisted markdown results)
**Testing**: Manual skill invocation tests + automated bash script tests (bats or shell assertions)
**Target Platform**: macOS/Linux (developer workstations running Claude Code)
**Project Type**: CLI skill (Claude Code slash command + supporting shell scripts)
**Performance Goals**: <2s overhead for MCP detection and method selection
**Constraints**: Must preserve backward compatibility with existing CLI workflow; MCP server SARIF output must be parseable by existing `parse-sarif.sh`
**Scale/Scope**: 1 command markdown updated (+ mirrored copy), existing bash scripts reused unchanged, ~2-3 files modified total

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Security-First | PASS | Scan results are security artifacts; no secrets exposed. MCP server communicates via standard MCP protocol. |
| II. Specification-Driven | PASS | Full spec completed and clarified before planning. |
| III. Supply Chain Integrity | PASS | No new dependencies added. Reusing existing SARIF parsing. MCP server is a first-party tool. |
| IV. Test-First Discipline | PASS | Test plan defined: acceptance tests for MCP path, CLI fallback, and output consistency. |
| V. Agent-Agnostic Design | PASS | Markdown command + bash scripts remain the canonical sources. MCP detection is a runtime capability check, not an agent lock-in. |

## Project Structure

### Documentation (this feature)

```text
specs/002-mcp-scan-fallback/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
.claude/commands/
└── kusari.scan.md           # Updated: MCP-first scan routing logic

.claude/scripts/kusari/
├── common.sh                # Existing: shared utilities (no changes expected)
├── scan.sh                  # Existing: CLI-only orchestrator (no changes needed)
├── parse-sarif.sh           # Existing: SARIF parser (no changes expected)
└── persist-results.sh       # Existing: result persistence (no changes expected)

ai/skills/kusari/
├── commands/kusari.scan.md  # Updated: mirrors .claude/commands/ version
├── scripts/                 # Updated: mirrors .claude/scripts/kusari/
└── tests/                   # New: test scripts for MCP and CLI paths
```

**Structure Decision**: This feature modifies existing files in the established structure. The primary changes are to `kusari.scan.md` (command routing logic) and `scan.sh` (orchestrator). No new directories or structural changes needed. The skill command markdown is the key integration point — it contains the MCP detection and routing logic that Claude Code executes.

## Complexity Tracking

No constitution violations. No complexity justifications needed.
