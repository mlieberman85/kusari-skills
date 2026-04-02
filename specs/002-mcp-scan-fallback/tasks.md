# Tasks: MCP Scan Fallback

**Input**: Design documents from `/specs/002-mcp-scan-fallback/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in the feature specification. Test tasks are omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Skill commands**: `.claude/commands/` (installed location) and `ai/skills/kusari/commands/` (source)
- **Scripts**: `.claude/scripts/kusari/` (installed location) and `ai/skills/kusari/scripts/` (source)
- **Tests**: `ai/skills/kusari/tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify existing files and understand current state before making changes

- [x] T001 Read current skill command at `.claude/commands/kusari.scan.md` to capture existing content as baseline
- [x] T002 Read current scripts at `.claude/scripts/kusari/scan.sh`, `.claude/scripts/kusari/parse-sarif.sh`, and `.claude/scripts/kusari/persist-results.sh` to confirm no changes are needed to bash scripts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify MCP server tool availability and SARIF compatibility before implementing routing logic

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Verify the `mcp__kusari-inspector__scan_local_changes` tool is discoverable by calling ToolSearch with query `+kusari-inspector` and document its exact parameter schema (repo_path, base_ref, output_format)
- [x] T004 Verify MCP server supports `output_format: "sarif"` by calling `mcp__kusari-inspector__scan_local_changes` with `output_format: "sarif"` on the current repo and inspecting the response structure
- [x] T005 If SARIF not supported by MCP server: document the gap and flag as coordination dependency with MCP server developer. Proceed with implementation assuming SARIF will be available.

**Checkpoint**: MCP tool schema confirmed, SARIF compatibility verified or flagged

---

## Phase 3: User Story 1 — Scan via MCP Server (Priority: P1) 🎯 MVP

**Goal**: Enable scanning via the `kusari-inspector` MCP server when available, with SARIF output parsed and persisted using the existing pipeline.

**Independent Test**: Configure the `kusari-inspector` MCP server, run `/kusari.scan`, verify scan completes via MCP and results are persisted to `.claude/security/scans/`.

### Implementation for User Story 1

- [x] T006 [US1] Write the updated `kusari.scan.md` command in `ai/skills/kusari/commands/kusari.scan.md` with MCP-first routing logic per the behavior contract: (1) attempt `mcp__kusari-inspector__scan_local_changes` with `repo_path`, `base_ref`, `output_format: "sarif"`, (2) on success write SARIF to temp file and run parse-sarif.sh + persist-results.sh pipeline via bash, (3) present findings with "Scanned via MCP server" indicator
- [x] T007 [US1] Copy the updated command to the installed location at `.claude/commands/kusari.scan.md` (must be identical to `ai/skills/kusari/commands/kusari.scan.md`)
- [x] T008 [US1] Manually test the MCP path: run `/kusari.scan` with the MCP server configured, verify (a) scan completes, (b) results include health score, code mitigations, dependency mitigations, (c) result file is persisted to `.claude/security/scans/`, (d) output indicates MCP method

**Checkpoint**: User Story 1 complete — MCP scanning works end-to-end when the server is available

---

## Phase 4: User Story 2 — Automatic CLI Fallback (Priority: P1)

**Goal**: Ensure the CLI-based scan workflow continues to work when the MCP server is unavailable, with no change in behavior from the current experience.

**Independent Test**: Run `/kusari.scan` without the MCP server configured, verify CLI scan works exactly as before.

### Implementation for User Story 2

- [x] T009 [US2] Add CLI fallback logic to `ai/skills/kusari/commands/kusari.scan.md`: when MCP tool is unavailable or unreachable, fall back to `bash .claude/scripts/kusari/scan.sh $ARGUMENTS` with existing exit code handling (1=prereq, 2=scan failure, 3=parse failure), present findings with "Scanned via CLI" indicator
- [x] T010 [US2] Add error routing logic to `ai/skills/kusari/commands/kusari.scan.md`: when MCP tool returns a scan-level error (not availability), report the error directly without CLI fallback per FR-008
- [x] T011 [US2] Add dual-unavailable handling to `ai/skills/kusari/commands/kusari.scan.md`: when both MCP server and CLI are unavailable, report that no scanning method is available and provide setup guidance for both options
- [x] T012 [US2] Copy the updated command to `.claude/commands/kusari.scan.md` (sync with source)
- [ ] T013 [US2] Manually test the CLI fallback path: run `/kusari.scan` without MCP server, verify (a) CLI scan completes, (b) results match existing format, (c) output indicates CLI method

**Checkpoint**: User Story 2 complete — CLI fallback works seamlessly when MCP is unavailable

---

## Phase 5: User Story 3 — Consistent Output (Priority: P2)

**Goal**: Verify that output format, findings structure, and persisted file format are identical regardless of scan method, ensuring `/kusari.remediate` compatibility.

**Independent Test**: Run scans via both methods on the same repo and compare persisted file structure.

### Implementation for User Story 3

- [x] T014 [P] [US3] Verify the MCP path in `ai/skills/kusari/commands/kusari.scan.md` produces the same JSON output structure as `scan.sh`: `{scan, code_mitigations, dependency_mitigations, result_file, revision, scan_method}` — the only addition is `scan_method` field per data-model.md ScanOutput entity
- [x] T015 [P] [US3] Verify persisted markdown files from both methods have identical structure: header (health score, status), code mitigations section, dependency mitigations section, next steps section
- [ ] T016 [US3] Manually test `/kusari.remediate` against an MCP-sourced scan result file to confirm it reads and processes correctly

**Checkpoint**: All user stories complete — output is consistent and remediation works with both scan methods

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final sync, documentation, and validation

- [x] T017 [P] Update `ai/skills/kusari/install.sh` if needed to ensure the updated `kusari.scan.md` is copied correctly during installation
- [x] T018 [P] Verify `ai/skills/kusari/scripts/` mirror matches `.claude/scripts/kusari/` (no script changes expected, but confirm sync)
- [ ] T019 Run quickstart.md validation: follow the quickstart steps end-to-end to confirm both MCP and CLI paths work as documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2 (Phase 4)**: Depends on User Story 1 (US2 adds fallback logic to the command written in US1)
- **User Story 3 (Phase 5)**: Depends on both US1 and US2 (verification requires both paths to exist)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — writes the initial updated command
- **User Story 2 (P1)**: Depends on User Story 1 — adds fallback and error routing to the command US1 created
- **User Story 3 (P2)**: Depends on US1 + US2 — verification task, no new code

### Within Each User Story

- Write command logic before syncing to installed location
- Sync before manual testing
- Manual test validates the story's acceptance scenarios

### Parallel Opportunities

- T001 and T002 can run in parallel (reading different files)
- T003 and T004 can run in parallel (independent MCP verification steps)
- T014 and T015 can run in parallel (independent verification checks)
- T017 and T018 can run in parallel (independent sync/install checks)

---

## Parallel Example: Phase 1

```text
# Read baseline files in parallel:
Task: "Read current skill command at .claude/commands/kusari.scan.md"
Task: "Read current scripts at .claude/scripts/kusari/scan.sh, parse-sarif.sh, persist-results.sh"
```

## Parallel Example: Phase 5 (Verification)

```text
# Run verification checks in parallel:
Task: "Verify JSON output structure matches between MCP and CLI paths"
Task: "Verify persisted markdown file structure is identical"
# Then sequentially:
Task: "Test /kusari.remediate against MCP-sourced scan result"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (read existing files)
2. Complete Phase 2: Foundational (verify MCP tool availability)
3. Complete Phase 3: User Story 1 (MCP scanning)
4. **STOP and VALIDATE**: Test MCP scanning independently
5. This delivers the core new capability

### Incremental Delivery

1. Complete Setup + Foundational → MCP tool verified
2. Add User Story 1 → MCP scanning works → Validate (MVP!)
3. Add User Story 2 → CLI fallback works → Validate
4. Add User Story 3 → Output consistency verified → Validate
5. Polish → Install script sync, quickstart validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US2 depends on US1 because both modify the same file (`kusari.scan.md`) — US1 creates the MCP path, US2 adds fallback logic
- US3 is purely verification — no new code, just confirming consistency
- The main deliverable is a single updated markdown file (`kusari.scan.md`) — this is a command-routing change, not a code-heavy feature
- Commit after each phase for clean rollback points
