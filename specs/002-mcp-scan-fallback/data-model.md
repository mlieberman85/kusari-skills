# Data Model: MCP Scan Fallback

**Feature**: 002-mcp-scan-fallback | **Date**: 2026-03-09

## Entities

### ScanMethod (enum)

The method used to execute the scan. Determined at runtime.

| Value | Description |
|-------|-------------|
| `mcp` | Scan executed via `kusari-inspector` MCP server |
| `cli` | Scan executed via `kusari` CLI binary |

### ScanResult (unchanged from existing)

The structured output from a scan, regardless of method. No schema changes.

| Field | Type | Description |
|-------|------|-------------|
| `should_proceed` | boolean | Whether the repo is safe to proceed |
| `health_score` | number | Health score (0-5) |
| `severity` | string | SARIF severity level |
| `justification` | string | Explanation of the score |
| `recommendation` | string | Suggested action |
| `failed_analysis` | boolean | Whether analysis encountered an error |
| `code_mitigation_count` | number | Count of code mitigations |
| `dependency_mitigation_count` | number | Count of dependency mitigations |
| `console_url` | string (nullable) | Link to Kusari Console |

### CodeMitigation (unchanged)

| Field | Type | Description |
|-------|------|-------------|
| `file_path` | string | Path to affected file |
| `line_number` | number | Line number of finding |
| `code_snippet` | string | Flagged code text |
| `description` | string | Mitigation description |
| `severity` | string | SARIF severity level |

### DependencyMitigation (unchanged)

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Mitigation description |
| `severity` | string | SARIF severity level |

### ScanOutput (extended)

The final JSON output from the scan pipeline. Extended with `scan_method`.

| Field | Type | Description |
|-------|------|-------------|
| `scan` | ScanResult | Scan result object |
| `code_mitigations` | CodeMitigation[] | Array of code findings |
| `dependency_mitigations` | DependencyMitigation[] | Array of dependency findings |
| `result_file` | string | Path to persisted markdown file |
| `revision` | string | Git revision scanned against |
| `scan_method` | ScanMethod | Which method was used (`mcp` or `cli`) |

## State Transitions

```text
[Start]
  │
  ├─ MCP server available? ──YES──▶ [MCP Scan]
  │                                    │
  │                                    ├─ Success → [Parse SARIF] → [Persist] → [Output]
  │                                    └─ Scan error → [Report MCP Error]
  │
  └─ NO (unreachable/not configured)
     │
     ▼
  [CLI Scan (existing scan.sh)]
     │
     ├─ Success → [Parse SARIF] → [Persist] → [Output]
     ├─ Prereq failure (exit 1) → [Report prereq error]
     ├─ Scan failure (exit 2) → [Report scan error]
     └─ Parse failure (exit 3) → [Report parse error]
```

## Relationships

- ScanOutput contains exactly one ScanResult, zero or more CodeMitigations, zero or more DependencyMitigations
- ScanMethod is metadata on ScanOutput; does not affect downstream consumers
- Persisted markdown file format is identical regardless of ScanMethod
- `/kusari.remediate` reads persisted markdown files — no ScanMethod awareness needed
