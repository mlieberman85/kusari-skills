# Kusari Security Skills

AI-native security scanning and remediation skills for Claude Code, powered by [Kusari Inspector](https://kusari.dev).

## Skills

| Skill | Description |
|-------|-------------|
| `/kusari.change.evaluate` | Run a security scan against a git revision. Presents health score, code mitigations, and dependency mitigations. |
| `/kusari.change.fix` | Walk through scan findings interactively. Apply code fixes with approval and get enriched dependency remediation guidance. |

## Prerequisites

- **Git** repository
- **[Kusari CLI](https://github.com/kusaridev/kusari-cli)** v0.21.0+ installed and authenticated (`kusari auth login`), OR the `kusari-inspector` MCP server configured
- **jq** for JSON parsing (`brew install jq` on macOS) -- only needed for CLI fallback
- [Claude Code](https://docs.claude.ai/en/docs/claude-code-overview)

## How It Works

### Scanning (`/kusari.change.evaluate`)

The scan skill tries the `kusari-inspector` MCP server first. If unavailable, it falls back to the CLI pipeline which flows through three bash scripts:

1. **`common.sh`** -- Shared utilities: prerequisite checks, default branch detection, error formatting, and the `run_kusari_scan` wrapper that captures SARIF output
2. **`scan.sh`** -- Orchestrator that validates prerequisites, runs the scan, parses SARIF, and outputs structured JSON
3. **`parse-sarif.sh`** -- Extracts `ScanResult`, `CodeMitigation[]`, and `DependencyMitigation[]` from SARIF 2.1.0 output using jq

### Remediation (`/kusari.change.fix`)

The remediation skill uses scan results from the conversation context:

- For each **code mitigation**: shows context, severity, and suggested fix. Applies approved fixes via the Edit tool.
- For each **dependency mitigation**: enriches findings with remediation guidance from Kusari Inspector (when available). Notes that manual resolution is required.

## Scan Output

Scan results are presented directly in the conversation with:

- Health score (0-5) and status (Clean/Flagged/Error)
- Summary and recommendation
- Code mitigations with file path, line number, severity, and flagged code
- Dependency mitigations with severity and description
- Link to the Kusari Console (when available)
