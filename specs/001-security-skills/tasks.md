# Tasks: Security Skills

**Input**: Design documents from `/specs/001-security-skills/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: SARIF parser validation tests are included per the adapted test strategy in plan.md (Constitution Principle IV). Skill-level validation is manual against test repositories.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Skill commands**: `.claude/commands/kusari.*.md`
- **Shared scripts**: `.claude/scripts/kusari/*.sh`
- **Test fixtures**: `tests/fixtures/*.json`
- **Test scripts**: `tests/test-*.sh`
- **Runtime output**: `.claude/security/scans/` (created at runtime)

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create directory structure and SARIF test fixtures needed by all subsequent phases

- [x] T001 Create project directory structure: `.claude/scripts/kusari/`, `tests/fixtures/`, `.claude/security/scans/.gitkeep`
- [x] T002 [P] Create clean scan SARIF fixture in tests/fixtures/clean-scan.json — Valid SARIF 2.1.0 with one `security-analysis` result: `level: "note"`, `should_proceed: true`, `health_score: 5`, zero code/dependency mitigations. Follow the SARIF extraction map from data-model.md.
- [x] T003 [P] Create code mitigations SARIF fixture in tests/fixtures/code-mitigations.json — Valid SARIF 2.1.0 with one `security-analysis` result (`level: "warning"`, `should_proceed: false`, `health_score: 3`) plus 2 `code-mitigation` results with `physicalLocation` (file path, line number, snippet) and 1 `dependency-mitigation` result. Use realistic file paths and code snippets.
- [x] T004 [P] Create dependency-only mitigations SARIF fixture in tests/fixtures/dependency-mitigations.json — Valid SARIF 2.1.0 with one `security-analysis` result (`level: "warning"`, `should_proceed: true`, `health_score: 4`) plus 2 `dependency-mitigation` results and zero `code-mitigation` results.

**Checkpoint**: Directory structure exists, all 3 SARIF fixtures are valid JSON conforming to the schema in data-model.md SARIF Extraction Map.

---

## Phase 2: Foundational (Shared Infrastructure)

**Purpose**: Implement the shared Bash scripts that BOTH user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [P] Implement common.sh in .claude/scripts/kusari/common.sh — 6 functions per skill-interface contract: `check_kusari_cli()` (runs `which kusari`), `check_auth()` (checks JWT token file existence), `check_git_repo()` (runs `git rev-parse --git-dir`), `detect_default_branch()` (uses `git symbolic-ref refs/remotes/origin/HEAD` with fallback per research.md R6), `format_error()`, `format_warning()`. All error messages to stderr. Script must be sourceable (no top-level execution).
- [x] T006 [P] Implement parse-sarif.sh in .claude/scripts/kusari/parse-sarif.sh — 3 functions per skill-interface contract: `parse_scan_result()` (extracts ScanResult JSON from SARIF using jq, following the SARIF extraction map in data-model.md), `extract_code_mitigations()` (extracts CodeMitigation array with file_path, line_number, code_snippet, description, severity), `extract_dependency_mitigations()` (extracts DependencyMitigation array with description, severity). Requires `jq` — validate availability at source time. Script must be sourceable.
- [x] T007 [P] Implement persist-results.sh in .claude/scripts/kusari/persist-results.sh — 2 functions per skill-interface contract: `persist_scan_result()` (takes scan JSON + SARIF path, creates `.claude/security/scans/scan-YYYY-MM-DDTHH-MM-SS.md` following the exact format in contracts/scan-result-format.md, creates directory if missing), `get_latest_scan()` (finds most recent file in `.claude/security/scans/` by name sort, exit 1 if none). Script must be sourceable.
- [x] T008 Create SARIF parser validation script in tests/test-sarif-parser.sh — Source parse-sarif.sh, run all 3 extraction functions against each of the 3 fixtures (clean-scan.json, code-mitigations.json, dependency-mitigations.json). Validate: (a) clean scan returns `should_proceed: true`, `health_score: 5`, 0 code mitigations, 0 dependency mitigations; (b) code mitigations fixture returns 2 code mitigations with correct file paths and line numbers, 1 dependency mitigation; (c) dependency fixture returns 0 code mitigations, 2 dependency mitigations. Print PASS/FAIL per test case. Exit 0 if all pass, exit 1 if any fail. Make executable.

**Checkpoint**: All 3 scripts are sourceable, `tests/test-sarif-parser.sh` passes (exit 0) against all 3 fixtures.

---

## Phase 3: User Story 1 — Repository Security Scan (Priority: P1) MVP

**Goal**: A developer can invoke `/kusari.scan`, have the skill verify prerequisites, run `kusari repo scan`, parse SARIF output, present findings in readable format, and persist results to `.claude/security/scans/`.

**Independent Test**: Run `/kusari.scan` against an authenticated repository. Verify: (a) prerequisites checked (CLI, auth, git), (b) scan executes with `--output-format sarif --wait`, (c) results display code and dependency mitigations with file paths, line numbers, severity, and suggested fixes, (d) results persisted to timestamped file in `.claude/security/scans/`, (e) console URL displayed when available.

### Implementation for User Story 1

- [x] T009 [US1] Create kusari.scan.md skill command in .claude/commands/kusari.scan.md — YAML front matter with `description` and `handoffs` (to kusari.remediate). `## User Input` section referencing `$ARGUMENTS` (optional git revision). Execution steps: (1) Source common.sh and run `check_git_repo`, `check_kusari_cli`, `check_auth` with error guidance per skill-interface contract error table; (2) Parse `$ARGUMENTS` for git revision, if empty call `detect_default_branch`; (3) Run `kusari repo scan . <revision> --output-format sarif --wait`, capture SARIF output to temp file; (4) Source parse-sarif.sh, call `parse_scan_result` and `extract_code_mitigations` and `extract_dependency_mitigations`; (5) Source persist-results.sh, call `persist_scan_result` to save markdown; (6) Present summary to developer: health score, status, mitigation counts, each finding with severity/file/line/description/fix, console URL, next steps including `/kusari.remediate`. Handle all error conditions from skill-interface contract.
- [x] T010 [US1] Validate scan result output format — Run persist-results.sh against code-mitigations.json fixture. Verify the generated markdown file matches the scan-result-format contract: header section (Date, Repository, Revision, Health Score, Status), Summary section, Code Mitigations section with `### file_path:line_number` headings and fenced code blocks, Dependency Mitigations section with numbered headings, Next Steps checklist. Fix any format deviations.
- [ ] T011 [US1] End-to-end validation of kusari.scan skill — Run `/kusari.scan` in a repository with the Kusari CLI installed and authenticated. Verify all 4 acceptance scenarios from spec.md US1: (a) default branch detection works, (b) unauthenticated developer gets auth guidance, (c) clean scan shows summary with console link, (d) flagged scan shows each finding with severity, file, location, explanation, and remediation action. Document any issues and fix.

**Checkpoint**: `/kusari.scan` is fully functional. Developer can scan any authenticated repository, view findings, and find persisted results in `.claude/security/scans/`.

---

## Phase 4: User Story 2 — Guided Remediation (Priority: P2)

**Goal**: A developer can invoke `/kusari.remediate`, have the skill parse the most recent (or specified) scan results, present each code mitigation and dependency mitigation for review, apply approved code fixes, and summarize changes.

**Independent Test**: Run `/kusari.remediate` against scan results containing code and dependency mitigations. Verify: (a) most recent scan auto-detected or specified path used, (b) each code mitigation presented with file/line/current/fix for approve/skip, (c) approved fixes applied to files, (d) dependency mitigations presented with guidance, (e) summary of changes shown, (f) re-scan suggested.

### Implementation for User Story 2

- [x] T012 [US2] Create kusari.remediate.md skill command in .claude/commands/kusari.remediate.md — YAML front matter with `description` and `handoffs` (to kusari.scan for re-verification). `## User Input` section referencing `$ARGUMENTS` (optional path to scan result file). Execution steps: (1) If `$ARGUMENTS` specifies a file path, use it; otherwise source persist-results.sh and call `get_latest_scan` to find most recent scan; handle "no scan results" error per skill-interface contract; (2) Read the scan result markdown file; (3) Parse the file to extract code mitigations (using `### file_path:line_number` markers per scan-result-format parsing contract) and dependency mitigations (using `### Mitigation N` markers); (4) For each code mitigation: present file path, line number, severity, description, current code context (read the actual file at that line), and suggested fix from code snippet; ask developer to approve or skip; if approved, apply the fix using the Edit tool; handle file-not-found and conflict errors per skill-interface contract; (5) For each dependency mitigation: present severity, description, and recommended action; note these require manual resolution; (6) After all mitigations reviewed, present summary: N approved and applied, M skipped, K dependency items acknowledged; (7) Suggest running `/kusari.scan` to verify fixes.
- [ ] T013 [US2] End-to-end validation of kusari.remediate skill — Create a test scenario: generate a scan result file (manually or via `/kusari.scan`) that contains at least 1 code mitigation and 1 dependency mitigation. Run `/kusari.remediate` against it. Verify all 4 acceptance scenarios from spec.md US2: (a) code mitigations presented with file/line/current/fix for approve/skip, (b) dependency mitigations presented with library/issue/action, (c) approved fixes applied and summary shown with re-scan suggestion, (d) scan with no actionable mitigations reports "no automated fixes available" with manual guidance. Document any issues and fix.

**Checkpoint**: `/kusari.remediate` is fully functional. Developer can review and apply mitigations from any scan result file.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Validate end-to-end workflow, extensibility, and error handling across both skills

- [ ] T014 Validate full quickstart.md workflow end-to-end — Follow the quickstart.md guide from scratch: verify prerequisites check, `kusari auth login`, `/kusari.scan` (default branch), review findings, `/kusari.remediate` (apply fixes), `/kusari.scan` (re-scan to verify). Confirm SC-001 (< 5 min excluding Inspector time) and SC-003 (every finding has actionable next step). Fix any workflow gaps.
- [x] T015 Verify extensibility architecture per FR-016 and SC-005 — Confirm that a new skill (e.g., `kusari.risk-check.md`) can be created by: (a) adding a new `.claude/commands/kusari.risk-check.md` file that sources the shared scripts, (b) verifying no modifications to existing `kusari.scan.md`, `kusari.remediate.md`, `common.sh`, `parse-sarif.sh`, or `persist-results.sh` are required. Document the extensibility pattern.
- [x] T016 Review error handling paths across all skills and scripts — Walk through each error condition in the skill-interface contract error tables. Verify: (a) CLI not installed shows installation guidance, (b) not authenticated shows `kusari auth login` guidance, (c) not a git repo shows clear message, (d) no scan results shows `/kusari.scan` guidance, (e) file conflict during remediation shows conflict and allows manual resolution, (f) scan timeout surfaces error with retry steps. Fix any missing or unclear error messages.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 - Scan (Phase 3)**: Depends on Foundational phase completion
- **US2 - Remediation (Phase 4)**: Depends on Foundational phase completion. Can start in parallel with US1 (skill file has no build dependency on scan skill), but end-to-end validation (T013) requires scan results from US1.
- **Polish (Phase 5)**: Depends on both US1 and US2 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) — skill implementation (T012) is independent, but validation (T013) requires scan result files that US1 produces

### Within Each Phase

- **Phase 1**: T001 first (directories), then T002-T004 in parallel (fixtures)
- **Phase 2**: T005-T007 in parallel (scripts), then T008 (validation depends on all scripts + fixtures)
- **Phase 3**: T009 first (skill file), T010 second (format validation), T011 third (end-to-end)
- **Phase 4**: T012 first (skill file), T013 second (end-to-end validation)
- **Phase 5**: T014-T016 can run in parallel

### Parallel Opportunities

```
Phase 1 parallel group:
  T002: Create clean-scan.json in tests/fixtures/
  T003: Create code-mitigations.json in tests/fixtures/
  T004: Create dependency-mitigations.json in tests/fixtures/

Phase 2 parallel group:
  T005: Implement common.sh in .claude/scripts/kusari/
  T006: Implement parse-sarif.sh in .claude/scripts/kusari/
  T007: Implement persist-results.sh in .claude/scripts/kusari/

Phase 3+4 partial parallel (skill creation only):
  T009: Create kusari.scan.md in .claude/commands/
  T012: Create kusari.remediate.md in .claude/commands/

Phase 5 parallel group:
  T014: Quickstart workflow validation
  T015: Extensibility verification
  T016: Error handling review
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational scripts (T005-T008)
3. Complete Phase 3: User Story 1 — Scan skill (T009-T011)
4. **STOP and VALIDATE**: `/kusari.scan` works end-to-end independently
5. Developer can scan repositories and view findings

### Incremental Delivery

1. Setup + Foundational → Shared infrastructure ready
2. Add User Story 1 (Scan) → Test independently → MVP
3. Add User Story 2 (Remediation) → Test independently → Full workflow
4. Polish → Validate end-to-end → Production-ready

### Suggested MVP Scope

**User Story 1 only** (T001-T011): Delivers a complete scan workflow. Remediation can follow as a natural extension since the scan result format contract ensures compatibility.

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | 16 |
| Phase 1 (Setup) | 4 tasks |
| Phase 2 (Foundational) | 4 tasks |
| Phase 3 (US1 - Scan) | 3 tasks |
| Phase 4 (US2 - Remediation) | 2 tasks |
| Phase 5 (Polish) | 3 tasks |
| Parallel opportunities | 4 groups (12 tasks parallelizable) |
| MVP scope | T001-T011 (11 tasks, US1 complete) |

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
- All Bash scripts must be sourceable (no top-level execution) and use `set -euo pipefail`
- SARIF fixtures must be valid JSON conforming to SARIF 2.1.0 schema
- Skill command files follow the speckit pattern: YAML front matter + execution steps
