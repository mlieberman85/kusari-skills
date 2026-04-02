# Scan Result File Format Contract

**Feature**: 001-security-skills
**Date**: 2026-03-03

## Overview

Defines the format of persisted scan result files written to
`.claude/security/scans/scan-YYYY-MM-DDTHH-MM-SS.md`. These files serve as the
interface between the scan skill and the remediation skill.

## File Naming

**Pattern**: `scan-YYYY-MM-DDTHH-MM-SS.md`

- Timestamp is the scan execution time in local timezone
- Dashes replace colons in the time component for filesystem safety
- Example: `scan-2026-03-03T14-30-45.md`

## File Structure

```markdown
# Security Scan Results

**Date**: YYYY-MM-DD HH:MM:SS
**Repository**: <repository name>
**Revision**: <git revision compared against>
**Health Score**: <0-5>/5
**Status**: <Clean | Flagged | Error>

## Summary

<justification text from Kusari Inspector>

**Recommendation**: <recommendation text>

## Code Mitigations

> <N> code mitigation(s) found.

### <file_path>:<line_number>

**Severity**: <error|warning|note>

<description text>

**Suggested fix**:
\```
<code_snippet>
\```

---

(repeat for each code mitigation)

## Dependency Mitigations

> <M> dependency mitigation(s) found.

### Mitigation <index>

**Severity**: <error|warning|note>

<description text>

---

(repeat for each dependency mitigation)

## Next Steps

- [ ] Review code mitigations and apply fixes: `/kusari.remediate`
- [ ] Review dependency mitigations and update packages manually
- [ ] Re-run scan to verify: `/kusari.scan`

[View full analysis in Kusari Console](<console_url>)
```

## Section Rules

### Header Section
- All header fields MUST be present
- **Status** values: `Clean` (severity=note), `Flagged`
  (severity=warning|error), `Error` (failed_analysis=true)
- **Health Score** MUST be in format `N/5`

### Code Mitigations Section
- Present only if `code_mitigation_count > 0`
- If no code mitigations: display "No code mitigations found."
- Each mitigation uses `### file_path:line_number` as heading
- Code snippets wrapped in fenced code blocks

### Dependency Mitigations Section
- Present only if `dependency_mitigation_count > 0`
- If no dependency mitigations: display "No dependency mitigations found."
- Numbered sequentially (`### Mitigation 1`, `### Mitigation 2`, etc.)

### Next Steps Section
- Always present
- Checklist format for developer follow-up
- Console URL included when available; omit line if not available

## Parsing Contract (for kusari.remediate)

The remediation skill parses this markdown format to extract mitigations.
Parsing relies on these structural markers:

- **Code mitigation header**: `### <path>:<line>` under `## Code Mitigations`
- **Code snippet**: Fenced code block immediately after `**Suggested fix**:`
- **Dependency header**: `### Mitigation <N>` under `## Dependency Mitigations`
- **Severity**: `**Severity**: <value>` line within each mitigation block
- **Description**: Text between severity line and either `**Suggested fix**:`
  or the next `---` separator
