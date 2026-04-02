# Feature Specification: MCP Scan Fallback

**Feature Branch**: `002-mcp-scan-fallback`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "Update kusari scan skill to utilize the kusari-inspector MCP server if available, with CLI fallback"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scan via MCP Server (Priority: P1)

A developer invokes the `/kusari.scan` skill in a Claude Code session where the `kusari-inspector` MCP server is configured and available. The scan executes through the MCP server directly, without requiring the Kusari CLI to be installed locally.

**Why this priority**: This is the core new capability — enabling a faster, more integrated scanning experience that doesn't depend on local CLI installation. It removes a setup barrier for developers.

**Independent Test**: Can be tested by configuring the `kusari-inspector` MCP server and running `/kusari.scan`. The scan should complete and return findings without invoking the Kusari CLI.

**Acceptance Scenarios**:

1. **Given** the `kusari-inspector` MCP server is available in the session, **When** the developer runs `/kusari.scan`, **Then** the scan executes via the MCP server and returns structured findings (health score, code mitigations, dependency mitigations).
2. **Given** the `kusari-inspector` MCP server is available, **When** the developer runs `/kusari.scan main`, **Then** the scan uses the specified revision and returns findings via the MCP server.
3. **Given** the `kusari-inspector` MCP server is available, **When** the scan completes, **Then** results are persisted to the `.claude/security/scans/` directory in the same format as CLI-based scans.

---

### User Story 2 - Automatic CLI Fallback (Priority: P1)

A developer invokes the `/kusari.scan` skill in a session where the `kusari-inspector` MCP server is not configured or unavailable. The scan falls back to the existing CLI-based workflow transparently.

**Why this priority**: Equally critical as P1 — existing CLI-based scanning must continue working without disruption. Developers without the MCP server configured should have no change in their experience.

**Independent Test**: Can be tested by running `/kusari.scan` in a session without the `kusari-inspector` MCP server. The scan should complete using the CLI exactly as it does today.

**Acceptance Scenarios**:

1. **Given** the `kusari-inspector` MCP server is not available, **When** the developer runs `/kusari.scan`, **Then** the scan falls back to the CLI-based workflow and completes successfully.
2. **Given** the `kusari-inspector` MCP server is not available and the Kusari CLI is not installed, **When** the developer runs `/kusari.scan`, **Then** the existing CLI-not-found error guidance is displayed.
3. **Given** the `kusari-inspector` MCP server becomes unreachable mid-detection, **When** the scan has not yet started, **Then** the system falls back to the CLI-based workflow.

---

### User Story 3 - Consistent Output Regardless of Scan Method (Priority: P2)

A developer receives scan results and cannot tell whether the scan was performed via the MCP server or the CLI. The output format, findings structure, and remediation workflow are identical.

**Why this priority**: Consistency ensures the downstream `/kusari.remediate` skill and any other tooling that reads scan results continues to work regardless of scan method.

**Independent Test**: Can be tested by running scans via both methods on the same repository at the same revision and comparing the output structure (health score, mitigations format, persisted file format).

**Acceptance Scenarios**:

1. **Given** a scan was performed via the MCP server, **When** the developer views the results, **Then** the output includes health score, status, code mitigations, and dependency mitigations in the same structure as CLI scans.
2. **Given** a scan was performed via the MCP server, **When** the developer runs `/kusari.remediate`, **Then** the remediation skill reads and processes the results without errors.
3. **Given** a scan was performed via either method, **When** the results are persisted, **Then** the file is saved in the same format and location (`.claude/security/scans/`).

---

### Edge Cases

- What happens when the MCP server is configured but returns a scan-level error (e.g., auth failure)? The system reports the MCP error directly without falling back to CLI, since the CLI would likely encounter the same issue.
- What happens when both the MCP server and CLI are unavailable? The system should report that no scanning method is available and provide setup guidance for both options.
- What happens when the MCP server returns results in an unexpected format? The system should report a parse error and suggest retrying, consistent with current CLI parse error handling.
- What happens when the developer explicitly wants to use a specific scan method? The current scope does not include method selection — the system always prefers MCP when available.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect whether the `kusari-inspector` MCP server is available in the current session before initiating a scan.
- **FR-002**: System MUST use the `kusari-inspector` MCP server as the preferred scan method when it is available.
- **FR-003**: System MUST fall back to the CLI-based scan workflow when the MCP server is unavailable.
- **FR-004**: System MUST produce output in the same structured format (health score, status, code mitigations, dependency mitigations, result file path) regardless of which scan method was used.
- **FR-005**: System MUST persist scan results to the `.claude/security/scans/` directory in the same file format for both scan methods.
- **FR-006**: System MUST support passing an optional git revision argument to the scan regardless of method.
- **FR-007**: System MUST indicate to the developer which scan method was used (MCP server or CLI) in its status output.
- **FR-008**: System MUST fall back to CLI only when the MCP server is unreachable or unavailable. If the MCP server is reachable but returns a scan-level error (e.g., authentication failure, invalid repository), the system MUST report that error directly without retrying via CLI.

### Key Entities

- **Scan Method**: The mechanism used to perform the scan (MCP server or CLI). Determined automatically based on availability.
- **Scan Result**: The structured output from a scan, containing health score, status, code mitigations, and dependency mitigations. Format is consistent across scan methods.
- **MCP Server Availability**: A runtime check that determines whether the `kusari-inspector` MCP server is accessible in the current session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Scans complete successfully via the MCP server when it is available, with no manual intervention required from the developer.
- **SC-002**: Scans complete successfully via the CLI when the MCP server is not available, with no change in behavior from the current experience.
- **SC-003**: 100% of scan results from either method can be consumed by the existing `/kusari.remediate` skill without modification.
- **SC-004**: Developers can determine which scan method was used from the scan output.
- **SC-005**: The transition between MCP and CLI scan methods adds no more than 2 seconds of overhead to the scan initiation process.

## Clarifications

### Session 2026-03-09

- Q: Should MCP errors fall back to CLI on any error, or only availability errors? → A: Fall back to CLI only when MCP server is unreachable/unavailable. Report scan-level errors (auth, invalid repo) directly.
- Q: What output format should be requested from the MCP server? → A: Request SARIF format to reuse existing SARIF parsing pipeline. If MCP server doesn't yet support SARIF, coordinate with MCP server developer to add it.

## Assumptions

- The `kusari-inspector` MCP server, when available, provides equivalent scanning capabilities to the Kusari CLI `repo scan` command.
- The MCP server returns results in SARIF format (or will be updated to support it), allowing reuse of the existing SARIF parsing pipeline.
- MCP server availability can be detected reliably at the start of the scan process.
- The existing result persistence format and `.claude/security/scans/` directory structure remain unchanged.
- The `/kusari.remediate` skill does not need modification to work with MCP-sourced scan results.
- The `kusari-inspector` MCP server supports (or will support) SARIF as an `output_format` option. If not yet available, this is a coordination dependency with the MCP server developer.

## Scope

### In Scope

- Detecting `kusari-inspector` MCP server availability
- Routing scans through the MCP server when available
- Falling back to CLI when MCP server is unavailable
- Normalizing MCP server output to match existing result format
- Updating the scan skill command to support both methods
- Persisting results consistently regardless of method

### Out of Scope

- Allowing developers to explicitly choose a scan method (force CLI or force MCP)
- Modifying the `/kusari.remediate` skill
- Installing or configuring the MCP server
- Changes to the MCP server itself
