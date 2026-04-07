# Tasks: Agent Skills Spec Compliance

**Input**: Design documents from `/specs/004-skill-spec-compliance/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Tests**: Not separately requested. `skills-ref validate` serves as the acceptance test.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Rename skill directories to match the new kebab-case names

- [x] T001 Rename `plugins/kusari/skills/change-evaluate/` to `plugins/kusari/skills/kusari-change-evaluate/`
- [x] T002 Rename `plugins/kusari/skills/change-fix/` to `plugins/kusari/skills/kusari-change-fix/`

---

## Phase 2: Foundational (SKILL.md Frontmatter Updates)

**Purpose**: Update both SKILL.md files to comply with Agent Skills spec — blocks all downstream tasks

- [x] T003 [P] Update `name` field from `"kusari.change.evaluate"` to `"kusari-change-evaluate"` in `plugins/kusari/skills/kusari-change-evaluate/SKILL.md`
- [x] T004 [P] Update `name` field from `"kusari.change.fix"` to `"kusari-change-fix"` in `plugins/kusari/skills/kusari-change-fix/SKILL.md`
- [x] T005 [P] Add `compatibility` field to `plugins/kusari/skills/kusari-change-evaluate/SKILL.md`: `"Requires Kusari CLI v0.21.0+ or kusari-inspector MCP server. jq required for CLI fallback."`
- [x] T006 [P] Add `compatibility` field to `plugins/kusari/skills/kusari-change-fix/SKILL.md`: `"Requires kusari-inspector MCP server for enriched remediation guidance."`
- [x] T007 Run `skills-ref validate plugins/kusari/skills/kusari-change-evaluate` — must return zero errors
- [x] T008 Run `skills-ref validate plugins/kusari/skills/kusari-change-fix` — must return zero errors

**Checkpoint**: Both skills pass `skills-ref validate`. US1 and US2 are satisfied.

---

## Phase 3: User Story 1 & 2 — Skill Names and Frontmatter Compliance (Priority: P1)

**Goal**: All skill names and frontmatter comply with the Agent Skills spec

**Independent Test**: `skills-ref validate` returns zero errors for both skill directories

- [x] T009 [US1] Update cross-reference in `plugins/kusari/skills/kusari-change-evaluate/SKILL.md` body: change `/kusari.change.fix` to `/kusari-change-fix`
- [x] T010 [US1] Update cross-reference in `plugins/kusari/skills/kusari-change-fix/SKILL.md` body: change `/kusari.change.evaluate` to `/kusari-change-evaluate`
- [x] T011 [US2] Re-run `skills-ref validate` on both skills to confirm body changes didn't break compliance

**Checkpoint**: Skills are fully compliant with the Agent Skills spec.

---

## Phase 4: User Story 3 — Install Script and Documentation Updated (Priority: P2)

**Goal**: Installer and all documentation reflect the new kebab-case names

**Independent Test**: Run `bash install.sh /tmp/test-repo` and verify kebab-case command files are installed

- [x] T012 [US3] Update `install.sh` — change source paths from `change-evaluate/` and `change-fix/` to `kusari-change-evaluate/` and `kusari-change-fix/`. Update old-name cleanup to remove both dot-notation (`kusari.change.*`) and previous kebab (`kusari-change-*`) files.
- [x] T013 [P] [US3] Update `plugins/kusari/README.md` — change all skill name references from dot-notation to kebab-case
- [x] T014 [P] [US3] Update `plugins/kusari/CHANGELOG.md` — change skill name references to kebab-case
- [x] T015 [P] [US3] Update root `README.md` — change skill name references to kebab-case
- [x] T016 [P] [US3] Update `CLAUDE.md` — change skill command references to kebab-case
- [x] T017 [US3] Test install.sh: run `bash install.sh /tmp/test-repo` (after `git init /tmp/test-repo`) and verify installed files use kebab-case names and old files are cleaned up

**Checkpoint**: All docs and installer use kebab-case names. US3 complete.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and regression checks

- [x] T018 Run existing test suite (`bash tests/test-sarif-parser.sh && bash tests/test-run-kusari-scan.sh`) to confirm no functional regressions
- [x] T019 Run `skills-ref validate` on both skills one final time as acceptance test
- [x] T020 Grep entire repo for remaining old dot-notation references (`kusari.change.evaluate`, `kusari.change.fix`) excluding specs/ — must find zero matches

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — directory renames first
- **Foundational (Phase 2)**: Depends on Phase 1 (directories must exist at new paths)
- **US1/US2 (Phase 3)**: Depends on Phase 2 (frontmatter must be correct before body updates)
- **US3 (Phase 4)**: Depends on Phase 1 (new directory paths needed for install.sh)
- **Polish (Phase 5)**: Depends on all prior phases

### Parallel Opportunities

- T001 and T002 are sequential (rename one at a time to avoid confusion)
- T003–T006 can all run in parallel (different files)
- T013–T016 can all run in parallel (different doc files)

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Complete Phase 1: Rename directories
2. Complete Phase 2: Update frontmatter + validate
3. Complete Phase 3: Update cross-references
4. **STOP and VALIDATE**: `skills-ref validate` passes for both skills

### Full Delivery

1. MVP above
2. Complete Phase 4: Update installer and docs
3. Complete Phase 5: Final validation and regression checks

---

## Notes

- T001–T002 use `git mv` for clean rename tracking
- T007–T008 and T011 use `skills-ref validate` as acceptance tests
- T020 ensures no stale references survive — search excludes `specs/` since spec docs intentionally reference old names in context
