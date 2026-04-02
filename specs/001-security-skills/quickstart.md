# Quickstart: Kusari Security Skills

**Feature**: 001-security-skills
**Date**: 2026-03-03

## Prerequisites

1. **Kusari CLI** (v0.21.0+): Install from
   [kusaridev/kusari-cli](https://github.com/kusaridev/kusari-cli)
2. **jq**: Required for SARIF parsing (`brew install jq` on macOS)
3. **Git repository**: Skills operate on the current local repo
4. **Kusari account**: Required for authentication with the Kusari
   platform

## Setup

### 1. Install the Kusari CLI

Follow the installation instructions at the Kusari CLI repository.
Verify installation:

```bash
kusari --version
```

### 2. Authenticate

```bash
kusari auth login
```

This opens a browser for OAuth2 authentication. Once complete, a JWT
token is stored locally for subsequent CLI operations.

### 3. Verify

Run a scan to confirm everything works:

```bash
kusari repo scan . main --output-format sarif --wait
```

## Usage

### Scan Your Repository

Run a security scan comparing your current branch against the default
branch:

```
/kusari.scan
```

To compare against a specific revision:

```
/kusari.scan main
/kusari.scan HEAD~5
/kusari.scan abc1234
```

**What happens**:
1. The skill verifies CLI installation and authentication
2. Detects the default branch (if no revision specified)
3. Runs `kusari repo scan` and waits for Kusari Inspector results
4. Parses SARIF output and presents findings
5. Saves results to `.claude/security/scans/scan-<timestamp>.md`

**Output example** (flagged scan):
```
Health Score: 3/5 | Status: Flagged

Summary: Found 2 code mitigations and 1 dependency concern.

Code Mitigations:
  1. src/auth.js:45 (warning) - SQL injection vulnerability
  2. src/api.js:112 (warning) - Missing input validation

Dependency Mitigations:
  1. (warning) - lodash@4.17.20 has known prototype pollution

Results saved to: .claude/security/scans/scan-2026-03-03T14-30-45.md

Next: Run /kusari.remediate to review and apply fixes.
```

### Remediate Findings

After reviewing scan results, apply suggested fixes:

```
/kusari.remediate
```

To remediate a specific scan result:

```
/kusari.remediate .claude/security/scans/scan-2026-03-03T14-30-45.md
```

**What happens**:
1. Loads the most recent (or specified) scan result
2. For each code mitigation:
   - Shows the file, line, issue, and suggested fix
   - Asks you to approve or skip
   - Applies approved fixes to the source files
3. For each dependency mitigation:
   - Shows the concern and recommended action
   - Provides manual guidance (cannot auto-apply)
4. Summarizes all changes and suggests re-scanning

## Workflow

The typical developer workflow is:

```
/kusari.scan          # 1. Scan for issues
                      # 2. Review findings in terminal + saved file
/kusari.remediate     # 3. Apply approved fixes
/kusari.scan          # 4. Re-scan to verify fixes
```

## File Structure

After running the skills, your repository will contain:

```
.claude/security/scans/                   # Scan result history
  scan-2026-03-03T14-30-45.md             # Timestamped results
  scan-2026-03-03T15-10-22.md             # Re-scan after fixes
```

These files can be committed to version control for tracking security
posture over time.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Kusari CLI not found" | Install from kusaridev/kusari-cli |
| "Not authenticated" | Run `kusari auth login` |
| "Not a git repository" | Initialize with `git init` or navigate to a repo |
| "Monorepo detected" | Scan individual subdirectories instead |
| Scan times out | Check network connectivity; retry with `/kusari.scan` |
| No mitigations found | Clean scan; no action needed |
