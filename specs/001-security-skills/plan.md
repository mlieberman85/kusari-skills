# Implementation Plan: Security Skills

**Branch**: `001-security-skills` | **Date**: 2026-03-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-security-skills/spec.md`

## Summary

Build two agent skills (`kusari.scan` and `kusari.remediate`) that
wrap the Kusari CLI's `repo scan` command into guided developer
workflows. The scan skill runs `kusari repo scan`, parses SARIF
output, and presents findings with actionable guidance. The
remediation skill reads scan results, presents each suggested code
and dependency mitigation for developer approval, and applies
approved fixes. The architecture uses shared infrastructure (auth
checking, CLI detection, output parsing, result persistence) so
future skills for additional Kusari CLI commands can be added
without modifying existing implementations.

## Technical Context

**Language/Version**: Markdown (skill command definitions) + Bash (shared scripts)
**Primary Dependencies**: Kusari CLI v0.21.0+ (Go binary, installed separately)
**Storage**: Markdown files in repository (`.claude/security/scans/` directory)
**Testing**: Manual validation against test repositories; SARIF output parsing validation
**Target Platform**: macOS, Linux (any platform where Claude Code runs)
**Project Type**: Agent skill definitions (Markdown command files + shared shell infrastructure)
**Performance Goals**: Skill invocation overhead < 5 seconds (excluding Kusari Inspector processing)
**Constraints**: No compiled code; skills are Markdown prompt templates + Bash helpers; must work offline for remediation (scan requires network)
**Scale/Scope**: 2 skills for initial release, extensible to 5+ future skills

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Pre-Design | Post-Design | Notes |
|-----------|-----------|-------------|-------|
| I. Security-First | PASS | PASS | Skills wrap security tooling. Auth tokens handled by Kusari CLI (not stored/logged by skills). No sensitive data in persisted artifacts. External inputs validated (git revision, file paths). Scan result files contain only findings metadata, no source code or credentials. |
| II. Specification-Driven | PASS | PASS | Full spec with 2 user stories, Given-When-Then acceptance scenarios, RFC 2119 keywords, clarification sessions completed. Data model derived from spec entities. Contracts define all interfaces. |
| III. Supply Chain Integrity | PASS | PASS | Only dependencies: Kusari CLI binary (version-pinnable) and `jq` (system utility). No new library dependencies introduced. Project itself wraps supply chain security tools. |
| IV. Test-First | PASS | PASS with adaptation | Skills are Markdown command definitions, not compiled code. Testing adapted to: (a) validate SARIF parsing logic in shell scripts using fixture files, (b) run skills against test repositories with known findings, (c) verify output format matches scan-result-format contract. |
| V. Agent-Agnostic | PASS | PASS with adaptation | Initial delivery targets Claude Code (`.claude/commands/`). Core logic lives in shared Bash scripts under `.claude/scripts/kusari/` that any agent can invoke. Command files are agent-specific wrappers. SARIF parsing and result persistence are fully agent-independent. |

No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/001-security-skills/
├── plan.md              # This file
├── research.md          # Phase 0: SARIF format, skill patterns, auth detection
├── data-model.md        # Phase 1: Scan result structure, mitigation entities
├── quickstart.md        # Phase 1: Developer guide for using the skills
├── contracts/           # Phase 1: Skill command interface, output schemas
└── tasks.md             # Phase 2: Implementation tasks (/speckit.tasks)
```

### Source Code (repository root)

```text
.claude/commands/                 # Claude Code skill command definitions
├── kusari.scan.md                # Scan skill prompt template
└── kusari.remediate.md           # Remediation skill prompt template

.claude/scripts/kusari/                   # Agent-agnostic shared infrastructure
├── common.sh                     # Shared functions: auth check, CLI detection,
│                                 #   git helpers, error formatting
├── parse-sarif.sh                # SARIF output parser (extracts mitigations)
└── persist-results.sh            # Result file persistence with timestamping

.claude/security/scans/            # Persisted scan results (committed to repo)
└── (timestamped scan result files created at runtime)

tests/                            # Validation scripts
├── test-sarif-parser.sh          # SARIF parsing unit tests
└── fixtures/                     # Sample SARIF outputs for testing
    ├── clean-scan.json           # No findings
    ├── code-mitigations.json     # Code mitigation findings
    └── dependency-mitigations.json # Dependency mitigation findings
```

**Structure Decision**: Single project with three concerns separated
by directory: command definitions (`.claude/commands/`), shared
scripts (`.claude/scripts/kusari/`), and persisted output (`.claude/security/scans/`).
Test fixtures provide known SARIF samples for validation. This
mirrors the existing `speckit` pattern where `.claude/commands/` holds
agent-specific triggers and `.specify/scripts/bash/` holds reusable
logic.

## Phase Completion Log

### Phase 0: Research (COMPLETE)

- `research.md`: 6 research decisions (R1-R6) covering SARIF format,
  skill authoring patterns, authentication detection, result persistence,
  extensibility architecture, and git revision defaults.

### Phase 1: Design & Contracts (COMPLETE)

- `data-model.md`: 5 entities (ScanResult, CodeMitigation,
  DependencyMitigation, RemediationSession, DependencyAction) with
  fields mapped to SARIF 2.1.0 schema, validation rules, lifecycles,
  and entity relationships.
- `contracts/skill-interface.md`: Skill command interfaces for
  kusari.scan and kusari.remediate (triggers, arguments, preconditions,
  execution flows, outputs, error conditions) plus shared script
  function signatures (common.sh, parse-sarif.sh, persist-results.sh).
- `contracts/scan-result-format.md`: Persisted scan result markdown
  format contract with section rules and parsing markers for
  remediation skill consumption.
- `quickstart.md`: Developer guide covering prerequisites, setup,
  usage of both skills, typical workflow, and troubleshooting.
- Agent context updated (`CLAUDE.md`).
- Constitution re-check: All 5 principles PASS post-design.

### Phase 2: Tasks (PENDING)

To be generated via `/speckit.tasks`.

## Complexity Tracking

No constitution violations to justify.
