# Tasks: ShellCheck CI Integration

**Input**: Design documents from `/specs/003-shellcheck-ci/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Tests**: Not explicitly requested. ShellCheck itself validates scripts; the lint script is verified by running it.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create the lint script that both CI and local usage depend on

- [x] T001 Create `scripts/lint.sh` — ShellCheck runner that discovers all `.sh` files excluding `.specify/` and `.git/`, runs `shellcheck` on each, and exits non-zero if any fail. Use `find` for discovery per research decision R3. Script must be executable (`chmod +x`).

---

## Phase 2: Foundational (Fix Existing Issues)

**Purpose**: Ensure all project-owned scripts pass ShellCheck before enabling CI enforcement

**CRITICAL**: CI will fail immediately if existing scripts have warnings. These must be fixed first.

- [x] T002 Run `bash scripts/lint.sh` to identify all current ShellCheck issues in project-owned scripts
- [x] T003 [P] Fix ShellCheck issues in `plugins/kusari/skills/change-evaluate/scripts/common.sh` (no issues found)
- [x] T004 [P] Fix ShellCheck issues in `plugins/kusari/skills/change-evaluate/scripts/scan.sh`
- [x] T005 [P] Fix ShellCheck issues in `plugins/kusari/skills/change-evaluate/scripts/parse-sarif.sh`
- [x] T006 [P] Fix ShellCheck issues in `install.sh` (no issues found)
- [x] T007 [P] Fix ShellCheck issues in `tests/test-run-kusari-scan.sh`
- [x] T008 [P] Fix ShellCheck issues in `tests/test-sarif-parser.sh`
- [x] T009 Verify clean baseline by running `bash scripts/lint.sh` — must exit 0 with no warnings

**Checkpoint**: All project-owned scripts pass ShellCheck. Ready for CI enablement.

---

## Phase 3: User Story 1 — Automated Shell Script Linting on Push (Priority: P1) MVP

**Goal**: GitHub Actions workflow runs ShellCheck on every push to main and on every pull request

**Independent Test**: Push a commit to a PR branch and verify the ShellCheck check appears in GitHub Actions with pass/fail status

- [x] T010 [US1] Create `.github/workflows/shellcheck.yml` — GitHub Actions workflow that triggers on push to `main` and on pull requests. Workflow checks out the repo and runs `bash scripts/lint.sh`. Use `ubuntu-latest` runner (ShellCheck pre-installed per research R1). No third-party actions.
- [x] T011 [US1] Verify workflow syntax is valid by running `cat .github/workflows/shellcheck.yml | python3 -c "import sys,yaml;yaml.safe_load(sys.stdin)"` or equivalent YAML validation

**Checkpoint**: Pushing to main or opening a PR triggers ShellCheck CI. US1 is independently functional.

---

## Phase 4: User Story 2 — Local ShellCheck Validation (Priority: P2)

**Goal**: Developers can run the same ShellCheck checks locally with a single command

**Independent Test**: Run `bash scripts/lint.sh` locally and verify it checks all project-owned scripts with the same rules as CI

- [x] T012 [US2] Add ShellCheck install instructions to `scripts/lint.sh` output when ShellCheck is not found (exit with helpful message instead of cryptic error)
- [x] T013 [US2] Update `README.md` to document the local lint command under the Development/Testing section
- [x] T014 [US2] Update `specs/003-shellcheck-ci/quickstart.md` (already accurate) if any details changed during implementation

**Checkpoint**: Developers can run `bash scripts/lint.sh` locally and get identical results to CI. US2 is independently functional.

---

## Phase 5: User Story 3 — Targeted Script Scope (Priority: P2)

**Goal**: Only project-owned scripts are analyzed; `.specify/` framework scripts are excluded

**Independent Test**: Confirm that `bash scripts/lint.sh` lists only files outside `.specify/` and that adding a file to `.specify/` does not trigger linting

- [x] T015 [US3] Verify `scripts/lint.sh` exclusion logic by checking that no `.specify/**/*.sh` files appear in the discovered file list (add a `--list` or `--dry-run` flag that prints discovered files without running ShellCheck)
- [x] T016 [US3] Verify that a new `.sh` file added to `plugins/` is automatically discovered by lint.sh without config changes

**Checkpoint**: Scope is correct — framework scripts excluded, project scripts included. US3 is independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and final validation

- [x] T017 [P] Update `.github/CONTRIBUTING.md` to mention running `bash scripts/lint.sh` before submitting PRs
- [x] T018 Run existing test suite (`bash tests/test-sarif-parser.sh && bash tests/test-run-kusari-scan.sh`) to confirm ShellCheck fixes did not break functionality
- [x] T019 Run quickstart.md validation — walk through each step in `specs/003-shellcheck-ci/quickstart.md` and verify accuracy

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (lint script must exist to identify issues) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (scripts must pass before CI enforces)
- **US2 (Phase 4)**: Depends on Phase 1 (lint script exists). Can proceed in parallel with US1.
- **US3 (Phase 5)**: Depends on Phase 1 (lint script exists). Can proceed in parallel with US1.
- **Polish (Phase 6)**: Depends on US1, US2, US3 completion

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational — clean baseline required before CI enforcement
- **User Story 2 (P2)**: Depends only on Setup (Phase 1) — lint script is the local tool
- **User Story 3 (P2)**: Depends only on Setup (Phase 1) — scope validation uses lint script

### Within Each Phase

- T003–T008 (fix issues) are all [P] parallel — different files, no conflicts
- T010–T011 are sequential (create workflow, then validate)
- T012–T014 are sequential (enhance script, update docs)

### Parallel Opportunities

- After Phase 1: T003–T008 can all run in parallel (different script files)
- After Phase 2: US1, US2, US3 phases can proceed in parallel
- T017 (CONTRIBUTING.md) can run in parallel with any Phase 6 task

---

## Parallel Example: Phase 2 (Fix Existing Issues)

```bash
# All fix tasks target different files — run in parallel:
Task: "Fix ShellCheck issues in plugins/kusari/skills/change-evaluate/scripts/common.sh"
Task: "Fix ShellCheck issues in plugins/kusari/skills/change-evaluate/scripts/scan.sh"
Task: "Fix ShellCheck issues in plugins/kusari/skills/change-evaluate/scripts/parse-sarif.sh"
Task: "Fix ShellCheck issues in install.sh"
Task: "Fix ShellCheck issues in tests/test-run-kusari-scan.sh"
Task: "Fix ShellCheck issues in tests/test-sarif-parser.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Create lint script
2. Complete Phase 2: Fix all existing ShellCheck issues
3. Complete Phase 3: Create GitHub Actions workflow
4. **STOP and VALIDATE**: Push a branch, verify CI check runs and passes
5. Merge — CI enforcement is live

### Incremental Delivery

1. Create lint script → Foundation ready
2. Fix existing issues → Clean baseline
3. Add CI workflow → US1 complete (MVP!)
4. Enhance local experience → US2 complete
5. Validate scope → US3 complete
6. Polish docs → Feature complete

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- T003–T008 may have zero issues (in which case, mark complete immediately)
- Existing tests must still pass after ShellCheck fixes (verified by T018)
- Commit after each task or logical group
