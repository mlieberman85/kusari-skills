# Feature Specification: Security Skills

**Feature Branch**: `001-security-skills`
**Created**: 2026-03-03
**Status**: Draft
**Input**: User description: "I want to create a system of agent skills that utilize the kusari suite of tools in the right ways to help provide the security analysis and remediations developers need."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Repository Security Scan (Priority: P1)

A developer wants to scan their repository for security issues. They
invoke the scan skill, which runs `kusari repo scan` against the
local repository, waits for Kusari Inspector to analyze the code,
and presents the results — including code mitigations (specific
file/line fixes) and dependency mitigations (library security
concerns) — in a readable format with clear next steps.

The skill MUST verify that the developer is authenticated with the
Kusari platform before scanning. If not authenticated, the skill
MUST guide the developer through the login process.

**Why this priority**: Scanning is the foundational workflow — every
other skill depends on having scan results. Without a scan,
developers cannot identify what needs to be remediated.

**Independent Test**: Can be fully tested by running the skill
against any authenticated repository and verifying that Kusari
Inspector results are returned and presented with actionable
guidance.

**Acceptance Scenarios**:

1. **Given** an authenticated developer with a local git repository,
   **When** the developer invokes the scan skill without specifying
   a git revision,
   **Then** the system defaults to comparing against the repository's
   default branch (e.g., `main`), runs `kusari repo scan`, waits for
   results, and presents findings including code mitigations and
   dependency mitigations with file paths, line numbers, and
   suggested fixes.

2. **Given** a developer who is NOT authenticated with Kusari,
   **When** the developer invokes the scan skill,
   **Then** the system detects the missing authentication and guides
   the developer through `kusari auth login` before proceeding.

3. **Given** a scan that returns no flagged issues,
   **When** results are presented,
   **Then** the system reports a clean scan with a summary of what
   was analyzed and a link to the full analysis in the Kusari
   console.

4. **Given** a scan that returns findings,
   **When** results are presented,
   **Then** each finding includes its severity, the affected file
   and location, a human-readable explanation, and a suggested
   remediation action.

---

### User Story 2 - Guided Remediation (Priority: P2)

A developer has reviewed their scan results and wants to fix the
identified security issues. They invoke a remediation skill that
parses the scan findings, presents the suggested code mitigations
and dependency mitigations for review, and applies the developer's
selected fixes to the codebase.

The skill MUST present each suggested fix for the developer to
review and approve before applying it, since automated code changes
require human judgement to ensure correctness in context.

**Why this priority**: Remediation is the natural next step after
scanning. Translating scan findings into actual code changes is
where most developer friction occurs — this skill bridges the gap
between "knowing what's wrong" and "fixing it."

**Independent Test**: Can be fully tested by running the skill on
scan results that contain code mitigations and verifying that
approved fixes are correctly applied to the specified files and
lines.

**Acceptance Scenarios**:

1. **Given** scan results containing code mitigations,
   **When** the developer invokes the remediation skill,
   **Then** the system presents each code mitigation with the
   affected file, line number, current code, and suggested fix for
   the developer to approve or skip.

2. **Given** scan results containing dependency mitigations,
   **When** the developer invokes the remediation skill,
   **Then** the system presents each dependency concern with the
   library name, the security issue, and recommended action (update,
   replace, or remove).

3. **Given** a developer who approves selected mitigations,
   **When** the fixes are applied,
   **Then** the system modifies the affected files, provides a
   summary of all changes made, and suggests the developer re-run
   the scan to verify the fixes.

4. **Given** scan results with no actionable mitigations (e.g.,
   all findings are informational),
   **When** the developer invokes the remediation skill,
   **Then** the system reports that no automated fixes are available
   and provides manual guidance for each finding.

---

### Future Extensions (out of scope for initial release)

The skill architecture MUST support adding new skills without
modifying existing ones. Planned future skills include:

- **`kusari.risk-check`**: Wraps `kusari repo risk-check` (currently
  under development in the Kusari CLI) for risk assessment.
- **`kusari.upload`**: Wraps `kusari upload` for SBOM and OpenVEX
  document submission to the Kusari platform.
- **`kusari.govern`**: Security governance setup (security policies,
  branch protection, project configuration) using OpenSSF Baseline
  MCP tools.
- **`kusari.threat-model`**: STRIDE-based threat modeling using
  OpenSSF Baseline MCP tools.
- **`kusari.attest`**: Compliance attestation and evidence generation
  using OpenSSF Baseline MCP tools.

---

### Edge Cases

- What happens when the developer is not authenticated with Kusari?
  The system MUST detect missing or expired authentication and guide
  the developer through `kusari auth login` before proceeding.
- What happens when the Kusari CLI is not installed? The system MUST
  detect the missing binary and provide installation instructions.
- What happens when the repository is a monorepo? The Kusari CLI
  rejects full scans of monorepos. The system MUST detect this and
  advise the developer on subrepo-level scanning options.
- What happens when the scan times out or the Kusari platform is
  unreachable? The system MUST surface the error with context and
  suggest retry steps.
- What happens when scan results contain no actionable mitigations?
  The system MUST clearly communicate that no automated fixes are
  available and provide manual guidance for each finding.
- What happens when a suggested code mitigation conflicts with
  existing code changes the developer has made? The system MUST
  show the conflict and let the developer resolve it manually.
- What happens when the repository has no `.git` directory? The
  system MUST detect this and inform the developer that a git
  repository is required for scanning.

## Clarifications

### Session 2026-03-03

- Q: Should skill results (assessment reports, threat models) be persisted to files or displayed as ephemeral agent output? → A: Persist to files (e.g., `security/audit-report.md`) for review, sharing, and tracking over time.
- Q: Should compliance attestation (in-toto signed evidence) be a separate 5th skill, deferred, or folded into assessment? → A: Add a 5th skill for compliance attestation and evidence generation.
- Q: Should the spec prescribe OpenSSF Baseline maturity level support as a first-class feature? → A: No. Skills are thin orchestration wrappers around Kusari CLI and MCP tools. Maturity levels, filtering, and baseline-specific options are handled natively by the underlying tools and passed through as-is.
- Q: What naming prefix should skills use? → A: `kusari.*` (e.g., `kusari.assess`, `kusari.remediate`, `kusari.govern`).
- Q: What is the primary scope for the initial release? → A: Focus on `kusari repo scan` (Kusari CLI) and remediating its findings. Governance, threat modeling, attestation, and OpenSSF Baseline MCP tools are future extensions. Architecture MUST be extensible for adding new Kusari CLI commands as skills.
- Q: What git revision should `kusari repo scan` compare against by default? → A: Default to the repository's default branch (e.g., `main` or `master`). Developer can override via argument.

## Requirements *(mandatory)*

### Functional Requirements

**Scan Skill (`kusari.scan`)**:
- **FR-001**: The system MUST provide a scan skill that runs
  `kusari repo scan` against the developer's local repository and
  presents findings from Kusari Inspector.
- **FR-002**: The scan skill MUST verify Kusari CLI installation
  and authentication status before scanning, guiding the developer
  through setup if either is missing.
- **FR-003**: The scan skill MUST present findings including code
  mitigations (file paths, line numbers, suggested fixes) and
  dependency mitigations (library name, security issue, recommended
  action).
- **FR-004**: The scan skill MUST persist scan results to a file
  in the repository so results can be reviewed and tracked over
  time.
- **FR-005**: When scan results already exist from a prior run,
  the system MUST preserve the previous file (e.g., by
  timestamping) rather than silently overwriting it.
- **FR-006**: The scan skill MUST include a link to the full
  detailed analysis in the Kusari console when available.
- **FR-006a**: The scan skill MUST default to comparing against
  the repository's default branch (e.g., `main` or `master`) when
  the developer does not specify a git revision. The developer
  MUST be able to override this by providing a specific revision.

**Remediation Skill (`kusari.remediate`)**:
- **FR-007**: The system MUST provide a remediation skill that
  parses scan results and presents suggested code mitigations and
  dependency mitigations for developer review and approval.
- **FR-008**: The remediation skill MUST present each suggested fix
  individually, showing the affected file, line, current code, and
  proposed change, allowing the developer to approve or skip each.
- **FR-009**: The remediation skill MUST apply only
  developer-approved changes to the codebase.
- **FR-010**: After applying fixes, the remediation skill MUST
  provide a summary of all changes made and suggest re-running the
  scan to verify.

**Shared / Cross-Cutting Requirements**:
- **FR-011**: Each skill MUST be independently invocable — a
  developer can use any single skill without having run the others
  first.
- **FR-012**: Each skill MUST provide clear feedback on progress,
  including what step is currently executing and what steps remain.
- **FR-013**: Each skill MUST handle errors gracefully, surfacing
  actionable messages when the Kusari CLI fails, authentication
  expires, or prerequisites are missing.
- **FR-014**: Each skill MUST pass through configuration options
  supported by the underlying Kusari CLI commands (e.g.,
  `--output-format`, `--wait`) without reimplementing or
  constraining them at the skill layer.
- **FR-015**: The system MUST operate on the developer's current
  local repository only. Organization-wide and remote repository
  workflows are out of scope for the initial release.

**Extensibility Requirements**:
- **FR-016**: The skill architecture MUST support adding new skills
  for additional Kusari CLI commands (e.g., `risk-check`, `upload`)
  without modifying existing skill implementations.
- **FR-017**: Skills MUST share common infrastructure for
  authentication checking, CLI invocation, error handling, and
  output persistence so that new skills can reuse these capabilities.

### Key Entities

- **Skill**: A named, independently invocable agent capability
  under the `kusari.*` namespace that wraps a Kusari CLI command
  into a guided developer workflow. Each skill has a defined
  trigger, required inputs, execution steps, and expected outputs.
  The architecture supports adding new skills for new CLI commands.
- **Scan Result**: The output of `kusari repo scan` as analyzed by
  Kusari Inspector, persisted as a file in the repository. Contains
  an overall status (flagged/clean), a justification summary, code
  mitigations, dependency mitigations, and a console link.
- **Code Mitigation**: A specific suggested code fix within a scan
  result. Identifies the affected file path, line number, current
  code, and recommended change.
- **Dependency Mitigation**: A specific dependency security concern
  within a scan result. Identifies the library/package, the security
  issue, and recommended action (update, replace, or remove).
- **Remediation Session**: An interactive review of scan mitigations
  where the developer approves or skips each suggested fix. Tracks
  which mitigations were applied and which were skipped.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can complete a full repository scan from
  first skill invocation to viewing results within 5 minutes
  (excluding Kusari Inspector processing time).
- **SC-002**: 90% of developers can successfully complete the
  scan-to-remediation workflow (scan, review findings, apply fixes,
  re-scan to verify) on their first attempt without external
  documentation.
- **SC-003**: Every finding presented to a developer includes a
  clear, actionable next step — no finding is presented without
  guidance on how to address it.
- **SC-004**: After applying approved mitigations and re-scanning,
  the number of flagged issues decreases by the count of applied
  fixes.
- **SC-005**: Adding a new skill for an additional Kusari CLI
  command requires no modifications to existing skill
  implementations — only new skill files.

### Assumptions

- The developer has the Kusari CLI installed (or the skill provides
  installation guidance).
- The developer has (or can obtain) a Kusari platform account for
  authentication.
- The developer has a local git repository to scan.
- Skills use the `kusari.*` namespace prefix (e.g., `kusari.scan`,
  `kusari.remediate`).
- The initial release targets `kusari repo scan` + remediation only.
  Additional Kusari CLI commands and OpenSSF Baseline MCP tools are
  deferred to future extensions.
- The Kusari CLI source is at
  https://github.com/kusaridev/kusari-cli for reference during
  implementation.
