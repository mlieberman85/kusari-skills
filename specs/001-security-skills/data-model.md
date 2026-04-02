# Data Model: Security Skills

**Feature**: 001-security-skills
**Date**: 2026-03-03
**Source**: [spec.md](spec.md) entities + [research.md](research.md) SARIF schema

## Entity Definitions

### ScanResult

The output of a `kusari repo scan` invocation, parsed from SARIF 2.1.0
format and persisted as a timestamped markdown file.

| Field | Type | Source (SARIF path) | Description |
|-------|------|---------------------|-------------|
| `should_proceed` | boolean | `results[ruleId=security-analysis].properties.should_proceed` | Whether the code is safe to merge |
| `health_score` | integer (0-5) | `results[ruleId=security-analysis].properties.health_score` | Overall health rating |
| `severity` | enum: error, warning, note | `results[ruleId=security-analysis].level` | Overall scan severity |
| `justification` | string | `results[ruleId=security-analysis].properties.justification` | Why the recommendation was made |
| `recommendation` | string | `results[ruleId=security-analysis].properties.recommendation` | Action to take |
| `code_mitigations` | CodeMitigation[] | `results[ruleId=code-mitigation]` | Per-file code fixes |
| `dependency_mitigations` | DependencyMitigation[] | `results[ruleId=dependency-mitigation]` | Dependency concerns |
| `scan_timestamp` | ISO 8601 datetime | Generated at parse time | When the scan was executed |
| `git_revision` | string | CLI argument | Git revision compared against |
| `repository_path` | string | CLI argument | Local repository path scanned |
| `console_url` | string | `runs[0].properties.console_url` (if present) | Link to Kusari console |

**Identity**: Unique by `(repository_path, scan_timestamp)`.

**Lifecycle**:
```
Initiated → Running → Completed (clean | flagged | failed)
```

- **Initiated**: `kusari repo scan` invoked, upload in progress
- **Running**: Waiting for Kusari Inspector analysis (`--wait` flag)
- **Completed (clean)**: `severity = note`, `should_proceed = true`
- **Completed (flagged)**: `severity = warning|error`, mitigations present
- **Completed (failed)**: `failed_analysis = true` or CLI error

**Persistence**: `.claude/security/scans/scan-YYYY-MM-DDTHH-MM-SS.md`

**Validation Rules**:
- `health_score` MUST be in range [0, 5]
- `severity` MUST be one of: `error`, `warning`, `note`
- At least one `security-analysis` result MUST be present
- `scan_timestamp` MUST be valid ISO 8601

---

### CodeMitigation

A specific suggested code fix within a scan result, identifying the
affected file, line number, and recommended change.

| Field | Type | Source (SARIF path) | Description |
|-------|------|---------------------|-------------|
| `file_path` | string | `locations[0].physicalLocation.artifactLocation.uri` | Affected file relative to repo root |
| `line_number` | integer | `locations[0].physicalLocation.region.startLine` | Line number of the issue |
| `code_snippet` | string | `locations[0].physicalLocation.region.snippet.text` | Code snippet or suggested fix |
| `description` | string | `message.text` | Human-readable issue description |
| `severity` | enum: error, warning, note | `level` | Finding severity |

**Identity**: Unique by `(file_path, line_number, description)`.

**Validation Rules**:
- `file_path` MUST be a valid relative path (no leading `/` or `..`)
- `line_number` MUST be a positive integer
- `description` MUST be non-empty
- `code_snippet` MAY be empty (some findings lack a fix suggestion)

**Relationship**: Belongs to exactly one ScanResult.

---

### DependencyMitigation

A dependency security concern within a scan result, describing the issue
and recommended action. Has no file location (location-independent).

| Field | Type | Source (SARIF path) | Description |
|-------|------|---------------------|-------------|
| `description` | string | `message.text` | Human-readable issue and action |
| `severity` | enum: error, warning, note | `level` | Finding severity |

**Identity**: Unique by `description` within a ScanResult.

**Validation Rules**:
- `description` MUST be non-empty

**Relationship**: Belongs to exactly one ScanResult.

---

### RemediationSession

An interactive review of scan mitigations where the developer approves
or skips each suggested fix. Tracks which mitigations were applied and
which were skipped.

| Field | Type | Description |
|-------|------|-------------|
| `source_scan` | string | Path to the scan result file being remediated |
| `session_timestamp` | ISO 8601 datetime | When remediation started |
| `applied_code_fixes` | CodeMitigation[] | Code mitigations the developer approved |
| `skipped_code_fixes` | CodeMitigation[] | Code mitigations the developer skipped |
| `dependency_actions` | DependencyAction[] | Developer decisions on dependency mitigations |
| `total_findings` | integer | Total mitigations presented |
| `total_applied` | integer | Count of approved and applied fixes |
| `total_skipped` | integer | Count of skipped fixes |

**Identity**: Unique by `(source_scan, session_timestamp)`.

**Lifecycle**:
```
Started → In Progress → Completed (with summary)
```

- **Started**: Developer invokes remediation skill with scan results
- **In Progress**: Developer reviewing individual mitigations
- **Completed**: All mitigations reviewed, summary presented

**Note**: RemediationSession is ephemeral (exists only during skill
execution). It is not persisted to disk; the scan result file and
git diff serve as the audit trail.

---

### DependencyAction

A developer's decision on a dependency mitigation during remediation.

| Field | Type | Description |
|-------|------|-------------|
| `mitigation` | DependencyMitigation | The dependency mitigation being addressed |
| `action_taken` | enum: acknowledged, deferred | Developer's decision |
| `notes` | string (optional) | Developer's notes on the decision |

**Note**: Dependency mitigations cannot be automatically applied (they
require manual package updates, replacements, or removals). The
remediation skill presents them for acknowledgment and provides
guidance.

## Entity Relationships

```
ScanResult
├── has many CodeMitigation
└── has many DependencyMitigation

RemediationSession
├── references one ScanResult (source_scan)
├── categorizes CodeMitigation into applied/skipped
└── categorizes DependencyMitigation into DependencyAction
```

## SARIF Extraction Map

Maps the SARIF 2.1.0 JSON structure to entity fields:

```
$.runs[0].results[]
  ├── ruleId = "security-analysis"  → ScanResult (1 per scan)
  │   ├── .level                    → ScanResult.severity
  │   ├── .message.text             → (contains justification + recommendation)
  │   └── .properties
  │       ├── .should_proceed       → ScanResult.should_proceed
  │       ├── .health_score         → ScanResult.health_score
  │       ├── .justification        → ScanResult.justification
  │       └── .recommendation       → ScanResult.recommendation
  │
  ├── ruleId = "code-mitigation"    → CodeMitigation (0-N per scan)
  │   ├── .level                    → CodeMitigation.severity
  │   ├── .message.text             → CodeMitigation.description
  │   └── .locations[0].physicalLocation
  │       ├── .artifactLocation.uri → CodeMitigation.file_path
  │       └── .region
  │           ├── .startLine        → CodeMitigation.line_number
  │           └── .snippet.text     → CodeMitigation.code_snippet
  │
  └── ruleId = "dependency-mitigation" → DependencyMitigation (0-M)
      ├── .level                    → DependencyMitigation.severity
      └── .message.text             → DependencyMitigation.description
```
