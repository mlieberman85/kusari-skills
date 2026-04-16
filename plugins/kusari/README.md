# Kusari Security Skills

AI-native security scanning and remediation skills for Claude Code, powered by [Kusari Inspector](https://kusari.dev).

## Skills

| Skill | Description |
|-------|-------------|
| `/kusari-change-evaluate` | Run a security scan against a git revision. Presents health score, code mitigations, and dependency mitigations. |
| `/kusari-change-fix` | Walk through scan findings interactively. Apply code fixes with approval and get enriched dependency remediation guidance. |

## Installation

Install from the Claude Code plugin marketplace:

```bash
claude plugin install kusari
```

### Prerequisites

- **[Kusari CLI](https://github.com/kusaridev/kusari-cli)** v1.0.0+ installed and authenticated (`kusari auth login`)
- **Git** repository
- **jq** for JSON parsing (`brew install jq` on macOS) -- only needed for CLI fallback

## How It Works

### Scanning (`/kusari-change-evaluate`)

The scan skill tries the `kusari-inspector` MCP server first. If unavailable, it falls back to the CLI pipeline which flows through three bash scripts:

1. **`common.sh`** -- Shared utilities: prerequisite checks, default branch detection, error formatting, and the `run_kusari_scan` wrapper that captures SARIF output
2. **`scan.sh`** -- Orchestrator that validates prerequisites, runs the scan, parses SARIF, and outputs structured JSON
3. **`parse-sarif.sh`** -- Extracts `ScanResult`, `CodeMitigation[]`, and `DependencyMitigation[]` from SARIF 2.1.0 output using jq

### Remediation (`/kusari-change-fix`)

The remediation skill uses scan results from the conversation context:

- For each **code mitigation**: shows context, severity, and suggested fix. Applies approved fixes via the Edit tool.
- For each **dependency mitigation**: enriches findings with remediation guidance from Kusari Inspector (when available). Notes that manual resolution is required.

## Verifying a release

Each release of this plugin is signed and accompanied by SLSA Build Level 3 provenance. You can verify that a release was produced by the canonical release pipeline (and has not been tampered with) using publicly available tools.

Replace `vX.Y.Z` with the release you want to verify:

**Verify provenance** (confirms the release came from the expected source commit and workflow):

```bash
gh release download vX.Y.Z --repo kusaridev/kusari-skills
slsa-verifier verify-artifact \
  --provenance-path vX.Y.Z.intoto.jsonl \
  --source-uri github.com/kusaridev/kusari-skills \
  --source-tag vX.Y.Z \
  openssf-baseline.json
```

**Verify tag signature** (confirms the tag was signed by the release workflow's Sigstore identity):

```bash
cosign verify-blob-attestation \
  --certificate-identity "https://github.com/kusaridev/kusari-skills/.github/workflows/release.yml@refs/tags/vX.Y.Z" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --bundle vX.Y.Z.sig \
  <(git cat-file -p vX.Y.Z)
```

Both commands use only publicly known information — no publisher-only credential is required.

## Scan Output

Scan results are presented directly in the conversation with:

- Health score (0-5) and status (Clean/Flagged/Error)
- Summary and recommendation
- Code mitigations with file path, line number, severity, and flagged code
- Dependency mitigations with severity and description
- Link to the Kusari Console (when available)
