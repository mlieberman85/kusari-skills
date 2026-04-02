# Skill Interface Contracts

**Feature**: 001-security-skills
**Date**: 2026-03-03

## Overview

Each skill is a Markdown command file in `.claude/commands/` with YAML
front matter. Skills invoke shared Bash scripts in `.claude/scripts/kusari/`
for reusable logic. This contract defines the interface between the
skill prompt templates and the shared infrastructure.

---

## Skill Command Interface

### kusari.scan

**Trigger**: `/kusari.scan [arguments]`

**Arguments** (via `$ARGUMENTS`):
- Optional git revision (e.g., `main`, `HEAD~3`, `abc1234`)
- If empty, defaults to repository's default branch

**Preconditions**:
1. Current directory is a git repository
2. Kusari CLI is installed and in `$PATH`
3. Developer is authenticated (`kusari auth login` completed)

**Execution Flow**:
1. Validate preconditions (git repo, CLI installed, jq available)
2. Detect default branch if no revision specified
3. Run `kusari repo scan . <revision> --output-format sarif --wait`
4. Parse SARIF output → ScanResult entity
5. Format results as human-readable markdown
6. Persist results to `.claude/security/scans/scan-<timestamp>.md`
7. Present summary with next steps

**Outputs**:
- Persisted scan result file (markdown)
- Terminal output with findings summary and guidance
- Console URL for full analysis (when available)

**Error Conditions**:
| Error | Detection | User Guidance |
|-------|-----------|---------------|
| CLI not installed | `command -v kusari` fails | Provide installation instructions |
| Not authenticated | Scan command returns auth error | Guide through `kusari auth login` |
| Not a git repo | `git rev-parse` fails | Inform user git repo is required |
| Monorepo detected | CLI rejects scan | Advise on subrepo-level scanning |
| Scan timeout | CLI timeout/network error | Surface error with retry guidance |
| Inspector failure | `failed_analysis = true` in SARIF | Report failure with support link |

---

### kusari.remediate

**Trigger**: `/kusari.remediate [arguments]`

**Arguments** (via `$ARGUMENTS`):
- Optional path to specific scan result file
- If empty, uses most recent scan result in `.claude/security/scans/`

**Preconditions**:
1. At least one scan result exists in `.claude/security/scans/`
2. Scan result contains actionable mitigations

**Execution Flow**:
1. Locate scan result file (specified or most recent)
2. Parse scan result for code and dependency mitigations
3. For each code mitigation:
   a. Present file path, line number, current code, and suggested fix
   b. Wait for developer to approve or skip
   c. If approved, apply the fix to the file
4. For each dependency mitigation:
   a. Present the dependency concern and recommended action
   b. Provide manual guidance (cannot auto-apply)
5. Summarize all changes made
6. Suggest re-running scan to verify fixes

**Outputs**:
- Modified source files (for approved code mitigations)
- Terminal output with remediation summary
- Suggestion to re-scan

**Error Conditions**:
| Error | Detection | User Guidance |
|-------|-----------|---------------|
| No scan results | `.claude/security/scans/` empty or missing | Suggest running `/kusari.scan` first |
| Scan has no mitigations | Parse finds 0 mitigations | Report clean scan, no action needed |
| File conflict | Target file changed since scan | Show conflict, let developer resolve manually |
| File not found | Mitigation references missing file | Skip with warning, continue to next |

---

## Shared Script Interface

### common.sh

**Location**: `.claude/scripts/kusari/common.sh`
**Source**: Sourced by skill command execution

**Functions**:

```
check_kusari_cli() -> exit_code
  Returns 0 if kusari CLI is installed and in PATH.
  Prints installation guidance to stderr on failure.

print_auth_guidance() -> void (stderr)
  Prints authentication guidance to stderr.
  Call when a kusari command fails with an auth error.

check_git_repo() -> exit_code
  Returns 0 if current directory is a git repository.
  Prints guidance to stderr on failure.

detect_default_branch() -> string (stdout)
  Prints the default branch name (e.g., "main" or "master").
  Uses git symbolic-ref with fallback to common names.
  Returns exit code 1 if no default branch detected.

format_error(message: string) -> string (stdout)
  Formats an error message for consistent user presentation.

format_warning(message: string) -> string (stdout)
  Formats a warning message for consistent user presentation.
```

### parse-sarif.sh

**Location**: `.claude/scripts/kusari/parse-sarif.sh`
**Source**: Sourced by skill command execution
**Dependency**: Requires `jq` in `$PATH`

**Functions**:

```
parse_scan_result(sarif_file: path) -> JSON (stdout)
  Extracts ScanResult entity from SARIF file.
  Output: { "should_proceed": bool, "health_score": int,
            "severity": string, "justification": string,
            "recommendation": string,
            "code_mitigation_count": int,
            "dependency_mitigation_count": int }

extract_code_mitigations(sarif_file: path) -> JSON (stdout)
  Extracts CodeMitigation array from SARIF file.
  Output: [{ "file_path": string, "line_number": int,
             "code_snippet": string, "description": string,
             "severity": string }]

extract_dependency_mitigations(sarif_file: path) -> JSON (stdout)
  Extracts DependencyMitigation array from SARIF file.
  Output: [{ "description": string, "severity": string }]
```

### persist-results.sh

**Location**: `.claude/scripts/kusari/persist-results.sh`
**Source**: Sourced by skill command execution

**Functions**:

```
persist_scan_result(scan_json: JSON, sarif_file: path) -> path (stdout)
  Creates timestamped markdown file in .claude/security/scans/.
  Formats ScanResult + mitigations as human-readable markdown.
  Prints the path to the created file.
  Creates .claude/security/scans/ directory if it does not exist.

get_latest_scan() -> path (stdout)
  Prints the path to the most recent scan result file.
  Returns exit code 1 if no scan results exist.
```
