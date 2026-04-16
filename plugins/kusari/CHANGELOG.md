# Changelog

## Unreleased

### Added
- CI-driven release process producing signed, SLSA L3 provenance-attested, SBOM-accompanied releases
- Tag-triggered release workflow (`.github/workflows/release.yml`) with four named extension points
- Release invariant validator (`scripts/release/validate-release.sh`) enforcing 9 pre-publication checks
- Canonical `prerequisites.json` declaration consumed by install-time prerequisite check
- Consumer-facing release verification procedure in README
- Maintainer runbook (`docs/RELEASING.md`) covering releases, prereleases, withdrawals, and extension points
- Marketplace.json pinned-ref mechanism so default subscribers get the latest released version

### Changed
- **Requires action:** `hooks/check-prerequisites.sh` now reads `plugins/kusari/prerequisites.json` instead of hardcoding tool names. Behavior is unchanged for users with Kusari CLI installed.

### Security
- Release tags protected by tag-protection rules; only `release-maintainers` team can initiate releases
- Releases include OpenSSF Baseline compliance audit report
- Withdrawal procedure with GHSA publication for security-motivated withdrawals

## 0.2.0 — 2026-04-08

### Added
- Bundled MCP server configuration (`.mcp.json`) — `kusari-inspector` starts automatically when the plugin is enabled
- `SessionStart` hook to verify Kusari CLI is installed and provide setup guidance

## 0.1.0 -- 2026-04-02

Initial pre-release.

### Skills
- **kusari-change-evaluate** -- Security scanning via Kusari Inspector (MCP server with CLI fallback)
- **kusari-change-fix** -- Interactive review and application of security fixes with enriched remediation guidance
