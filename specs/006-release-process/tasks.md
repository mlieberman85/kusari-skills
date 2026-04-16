---

description: "Task list for Release Process feature (006-release-process)"
---

# Tasks: Release Process

**Input**: Design documents in `/Users/mlieberman/Projects/kusari-skills/specs/006-release-process/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test tasks are included per Constitution §IV (Test-First Discipline is NON-NEGOTIABLE). Tests are authored before the implementation they cover.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3). Setup and Polish phases omit the story label.
- All file paths are absolute-repo-root-relative

## Path Conventions

- Shell scripts: `scripts/release/*.sh`, `plugins/kusari/hooks/*.sh`
- Test harnesses: `tests/release/test-*.sh` with fixtures under `tests/release/fixtures/`
- GitHub Actions: `.github/workflows/*.yml`, `.github/actions/<name>/action.yml`
- Plugin-distributed content: `plugins/kusari/`
- Maintainer docs: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the new directory structure the feature introduces. No existing paths are reorganized.

- [x] T001 Create new directory structure: `scripts/release/`, `tests/release/`, `tests/release/fixtures/`, `.github/actions/release-validate/`, `docs/` (create only the ones that do not already exist)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Files and refactors that every user story depends on. No user story work can begin until this phase is complete.

**⚠️ CRITICAL**: T002 and T003 are written first because T004 (refactor of existing hook) depends on T002, and every script under `scripts/release/` depends on T003.

- [x] T002 [P] Author `plugins/kusari/prerequisites.json` with initial entries for `kusari` (minVersion 0.21.0), `jq` (minVersion null), `bash` (minVersion 4.0) following the schema in `specs/006-release-process/contracts/prerequisites-declaration.md`
- [x] T003 [P] Author `scripts/release/common.sh` with shared bash helpers: `parse_semver`, `read_plugin_version` (reads `plugins/kusari/.claude-plugin/plugin.json`), `fail_with_message`, `require_jq`, `normalize_version` (strips/adds `v` prefix). All helpers use `set -euo pipefail`-safe patterns per the existing repo convention in `scripts/lint.sh`.
- [x] T004 Refactor `plugins/kusari/hooks/check-prerequisites.sh` to load `plugins/kusari/prerequisites.json` via `jq` and iterate `tools[]` per the consumer contract in `contracts/prerequisites-declaration.md` (fail with a human-readable message per tool; skip version check gracefully if parse fails). Depends on T002. MUST NOT hardcode tool names, versions, or download URLs.
- [x] T005 [P] Author `tests/release/test-prerequisites-declaration.sh` exercising: schema-valid file loads, missing tool fails with correct message, outdated version fails, bad/missing `prerequisites.json` fails with clear error, unparseable version output surfaces warning (does not fail). Follows the existing harness pattern of `tests/test-run-kusari-scan.sh`.

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Cut a versioned plugin release (Priority: P1) 🎯 MVP

**Goal**: A maintainer can cut a signed, provenance-attested, SBOM-accompanied release by tagging the repo; unpinned marketplace subscribers resolve to the released version; consumers can verify the release using publicly documented commands.

**Independent Test**: Execute the release workflow end-to-end via `workflow_dispatch` with `dry_run: true` on a test branch; confirm: (a) invariant validator rejects bad fixtures and accepts good ones, (b) SBOM, OpenSSF Baseline audit, SLSA provenance, and tag signature are all produced, (c) release-bump PR flow from `bump-release.sh` produces the three coordinated file edits correctly, (d) no release is actually published when `dry_run: true`. Final end-to-end validation comes via T024 (dry-run) and T031 (first real release in Polish).

### Tests for User Story 1 (Constitution §IV: written before implementation) ⚠️

- [x] T006 [P] [US1] Create fixtures for `validate-release.sh` at `tests/release/fixtures/validate-release/` — one directory per named error mode: `repo-valid-release/`, `repo-version-format-invalid/`, `repo-version-already-tagged/`, `repo-plugin-version-mismatch/`, `repo-changelog-missing-entry/`, `repo-changelog-entry-empty/`, `repo-marketplace-ref-mismatch/`, `repo-working-tree-dirty/` (documents how the test harness simulates this), `repo-unreleased-non-empty/`, `repo-readme-missing-verify-section/`, `repo-multiple-failures/`. Each fixture contains the minimum tree needed to exercise its case (plugin.json, CHANGELOG.md, marketplace.json, README.md).
- [x] T007 [P] [US1] Author `tests/release/test-validate-release.sh` asserting each fixture from T006 produces the expected exit code and stderr error-code prefix (E1–E9) per `contracts/validate-release.md`. Follows the repo's existing bash-harness style.
- [x] T008 [P] [US1] Create fixtures for `render-release-notes.sh` at `tests/release/fixtures/render-release-notes/`: `changelog-single-version/`, `changelog-multi-version/`, `changelog-missing-version/`, `changelog-em-dash/`, `changelog-double-hyphen/`, `changelog-with-unreleased/`.
- [x] T009 [P] [US1] Author `tests/release/test-render-release-notes.sh` asserting correct stdout extraction, trailing-blank-line trim, exit code 1 on missing version, and em-dash / double-hyphen tolerance per `contracts/changelog-format.md`.
- [x] T010 [P] [US1] Create fixtures for `generate-sbom.sh` at `tests/release/fixtures/generate-sbom/` containing: minimal plugin tree + `prerequisites.json` with varied `purl` forms, with/without `minVersion`, and a `.mcp.json` whose command overlaps with a declared prerequisite (no double-listing) and another whose command does not (emitted separately).
- [x] T011 [P] [US1] Author `tests/release/test-generate-sbom.sh` validating the emitted SPDX JSON against `contracts/release-artifact-shape.md` SBOM expectations: presence of `creationInfo.comment` scope disclaimer, exactly one primary `Package` with `filesAnalyzed: true`, one external `Package` per prerequisite with `filesAnalyzed: false` + `purl` in `externalRefs`, one `HAS_PREREQUISITE` Relationship per prerequisite, no `CONTAINS` / linking relationships to prerequisites.
- [x] T012 [P] [US1] Create fixtures for `bump-release.sh` at `tests/release/fixtures/bump-release/`: `repo-clean-post-v0.2.0/` (starting state), `repo-expected-post-bump-v0.3.0/` (expected output state).
- [x] T013 [P] [US1] Author `tests/release/test-bump-release.sh` asserting post-bump state equals the expected fixture byte-for-byte (`plugin.json.version` advanced, `CHANGELOG.md`'s `## Unreleased` graduated to `## 0.3.0 — <today>` with a fresh empty `## Unreleased` prepended, `marketplace.json`'s plugin `source` rewritten to the pinned-ref shape per `contracts/marketplace-source-pin.md`). Tolerates today's date.

### Implementation for User Story 1

- [x] T014 [US1] Implement `scripts/release/validate-release.sh` with all nine checks (C1–C9) per `contracts/validate-release.md`: argument parsing (`<version>` positional, `--from <ref>` optional), exit-code semantics (0 success / 1 check-failed / 2 usage error / 3 environment error), stderr error-code prefix format, non-short-circuiting check loop. Depends on T003 (`common.sh`). Runs against the fixtures in T006 to pass.
- [x] T015 [P] [US1] Implement `scripts/release/render-release-notes.sh` per the renderer contract in `contracts/changelog-format.md`: accept version argument (with or without `v` prefix), emit the matching `## <version> — <date>` section's body to stdout with trailing blank lines trimmed, exit 1 if no match. Depends on T003.
- [x] T016 [P] [US1] Implement `scripts/release/generate-sbom.sh`: (1) invoke `syft plugins/kusari -o spdx-json` for the file-inventory portion; (2) read `plugins/kusari/prerequisites.json` and `plugins/kusari/.mcp.json`; (3) merge in external `Package` entries with `filesAnalyzed: false`, `downloadLocation`, and `externalRefs[].referenceLocator = <purl>`; (4) emit `HAS_PREREQUISITE` relationships from the plugin Package to each external Package; (5) set `creationInfo.comment` to the scope-disclaimer text per `contracts/release-artifact-shape.md`; (6) write to `sbom.spdx.json` in the working directory. Depends on T002 and T003. MCP-server overlap rule: if an MCP server `command` equals a prerequisite `name`, emit only the prerequisite Package (no double-counting).
- [x] T017 [P] [US1] Implement `scripts/release/bump-release.sh` with argument `<new-version>` (unprefixed SemVer): (1) rewrite `plugins/kusari/.claude-plugin/plugin.json` `version` field; (2) graduate `plugins/kusari/CHANGELOG.md`'s `## Unreleased` to `## <new-version> — <UTC-today>` and prepend a fresh empty `## Unreleased`; (3) rewrite `.claude-plugin/marketplace.json`'s plugin entry's `source` field to the pinned-ref object shape with `ref = v<new-version>`, per `contracts/marketplace-source-pin.md`. Idempotent. Does NOT stage, commit, or push. Depends on T003.
- [x] T018 [P] [US1] Add a "Verifying a release" section to `plugins/kusari/README.md` (FR-028) with copy-pastable `slsa-verifier verify-artifact` and `cosign verify-blob-attestation` commands, parameterized by `vX.Y.Z`, and a brief 1–2 sentence explanation of what each verifies. The heading MUST match `^##\s+Verifying` (case-insensitive) and the section body MUST contain the strings `slsa-verifier` and `cosign` so that `validate-release.sh` check C9 passes.
- [x] T019 [US1] Author `.github/actions/release-validate/action.yml` as a composite action that accepts `version` and optional `from-ref` inputs and calls `scripts/release/validate-release.sh`. All external GitHub Actions referenced (if any) pinned by commit SHA per Constitution §III and existing repo practice (example pattern: `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`). Depends on T014.
- [x] T020 [US1] Author `.github/workflows/release-validate.yml` — PR gate triggered on `pull_request` for PRs touching `plugins/kusari/.claude-plugin/plugin.json`, `plugins/kusari/CHANGELOG.md`, `.claude-plugin/marketplace.json`, or `plugins/kusari/README.md`. Parses target version from the plugin.json diff; invokes the composite action from T019 with `--from <PR head sha>`. All actions SHA-pinned. Depends on T019.
- [x] T021 [US1] Author `.github/workflows/release.yml` — the tag-triggered release pipeline per `contracts/release-workflow.md`. Triggers: `push` on tags matching `v*.*.*`; `workflow_dispatch` with `dry_run: boolean` input. Steps (ordered): `# === EXTENSION POINT: pre-release ===` marker → checkout (full history) → parse tag to version → invariants via composite action (T019) → `# === EXTENSION POINT: post-version-bump ===` marker → render release notes (T015) → generate SBOM (T016) → OpenSSF Baseline audit via darnit, comparing against the previous release's `openssf-baseline.json` asset fetched via `gh release download`; skip comparison gracefully on the bootstrap case (no prior release) per Assumptions; fail on regression or new HIGH/CRITICAL → call `slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@<SHA>` with subjects = { source tree hash + SBOM hash + audit hash } → sign tag with `cosign sign --yes --identity-token` → `# === EXTENSION POINT: post-release-marker ===` marker → `gh release create <tag> --title <version> --notes-file <file> [--prerelease] sbom.spdx.json openssf-baseline.json <version>.intoto.jsonl <version>.sig` (skipped when `dry_run: true`; intermediate files uploaded as workflow artifacts instead) → `# === EXTENSION POINT: post-publish ===` marker. All external actions SHA-pinned. Depends on T014, T015, T016 (and T019 via release-validate composite).
- [x] T022 [US1] Author `docs/RELEASING.md` maintainer runbook based on `specs/006-release-process/quickstart.md` Steps 0–6: before-you-begin (tag-protection rule configuration, release-maintainers team membership, Dependabot configuration note, Sigstore public-good — no setup needed), per-release procedure, verification procedure. Excludes the "Extension points" section (that lands in T027 under US3).
- [ ] T023 [US1] **BLOCKED: requires push to remote** Execute an end-to-end dry-run of `.github/workflows/release.yml` via `gh workflow run release.yml -f dry_run=true` on a throwaway branch. Verify: all intermediate files uploaded as workflow artifacts; SBOM validates against the `test-generate-sbom.sh` expectations; OpenSSF Baseline audit runs (bootstrap: skip comparison); SLSA provenance file is produced; `cosign` signing step completes (may use Sigstore staging for dry-run); no GitHub Release created. Document any deltas between dry-run behavior and expected tag-triggered behavior.

**Checkpoint**: User Story 1 is fully functional — a maintainer can cut a release by following the runbook, and the output is reproducible, verifiable, and resolvable by marketplace consumers.

---

## Phase 4: User Story 2 - Discover what changed in a release (Priority: P2)

**Goal**: Consumers can read a release's notes and understand what changed, what's new, and whether any action is required — without needing to read commits or code.

**Independent Test**: Inspect the release notes rendered by T023's dry-run (or the first real release in T031). Confirm the notes are categorized (Added, Changed, Fixed, Removed, Security, per FR-004) and that any user-action item (e.g., removed config, new prerequisite) is explicitly called out rather than implied.

- [x] T024 [P] [US2] Author `docs/CHANGELOG-AUTHORING.md` describing: the Keep a Changelog 1.1.0 structure the release process parses (per `contracts/changelog-format.md`), the seven permissible `### <Category>` subsection names, the required-action call-out pattern for user-visible breaking changes or new prerequisites (e.g., lead the entry with `**Requires action:**` or equivalent explicit marker so acceptance scenario 2 of US2 is testable by a casual reader), and guidance on using the `Security` category for security-impacting changes.
- [x] T025 [P] [US2] Author `.github/pull_request_template.md` reminding contributors to update `plugins/kusari/CHANGELOG.md`'s `## Unreleased` section when their change is user-visible, with a short pointer to `docs/CHANGELOG-AUTHORING.md` for conventions.

**Checkpoint**: User Story 2 complete — CHANGELOG conventions are documented and reinforced at PR time; the rendered release notes meet both acceptance scenarios.

---

## Phase 5: User Story 3 - Extend the release process without rewriting it (Priority: P3)

**Goal**: A contributor can add a new step (e.g., SBOM to external registry, auto-changelog from commits, release-notification webhook) at a defined extension point without editing any existing step.

**Independent Test**: A contributor unfamiliar with the feature reads `docs/RELEASING.md` and identifies the four named extension points, their responsibilities, and how to insert a new step; adding a trivial step (e.g., `echo "post-publish hook"`) at `post-publish` and running the dry-run workflow shows the step executed at the expected stage. The YAML extension-point markers are already in place (T021); this phase is primarily documentation.

- [x] T026 [US3] Extend `docs/RELEASING.md` with an "Extension points" section: documents each of the four named points (`pre-release`, `post-version-bump`, `post-release-marker`, `post-publish`), what state is available at each, what a failure at that point implies for partial state (especially the post-release-marker Sigstore-transparency-log append-only property), the adding-a-step rule (edit only within the comment-bracketed region for the target point), and one worked example (e.g., adding a step at `post-publish` that announces the release to a Slack channel or re-publishes the SBOM to a separate registry).

**Checkpoint**: All three user stories complete and independently validated.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification, quality gates, and the first real release.

- [x] T027 [P] Run `bash scripts/lint.sh` (syntax-checked locally; ShellCheck runs on CI) and confirm ShellCheck passes on all new scripts (`scripts/release/*.sh`, `tests/release/test-*.sh`, the refactored `plugins/kusari/hooks/check-prerequisites.sh`). No warnings ignored; fix the scripts rather than the lint config.
- [x] T028 [P] Audit all GitHub Actions referenced in `.github/workflows/release.yml`, `.github/workflows/release-validate.yml`, and `.github/actions/release-validate/action.yml`; confirm each is pinned by 40-hex commit SHA with a human-readable version comment per Constitution §III (example pattern visible in `.github/workflows/shellcheck.yml`).
- [ ] T029 **BLOCKED: requires push + tag on remote** Cut the inaugural release `v0.3.0` following `docs/RELEASING.md` Steps 1–6: bump via `scripts/release/bump-release.sh 0.3.0`, open release-bump PR, merge, tag, push tag, observe workflow execution, download release assets, verify the tag signature and provenance using the procedure in `plugins/kusari/README.md`'s "Verifying a release" section. This release establishes the Baseline-audit bootstrap state per Assumptions.
- [x] T030 Re-run the Constitution Check (plan.md §Constitution Check) against the now-concrete artifacts. Confirm all five principles still PASS; record any adjustments needed. No deviations expected.
- [x] T031 Update `plugins/kusari/CHANGELOG.md`'s `## Unreleased` section (via a subsequent PR, not part of the v0.3.0 release) to document the release-process feature itself under `### Added` for the next release to capture (a meta-release entry).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — T001 creates the structure everything else lives in.
- **Foundational (Phase 2)**: Depends on Setup completion. BLOCKS all user-story work.
  - T002 (prerequisites.json), T003 (common.sh), T005 (test) are [P] with each other.
  - T004 (check-prerequisites refactor) depends on T002.
- **User Story 1 (Phase 3)**: Depends on Foundational completion.
  - Tests T006–T013 are all [P] (different files).
  - Implementations T014 depends on T003. T015, T016, T017 each depend on T003 but are [P] with each other. T016 additionally depends on T002.
  - T018 (README section) is [P] with the script implementations.
  - T019 (composite action) depends on T014.
  - T020 (release-validate.yml) depends on T019.
  - T021 (release.yml) depends on T014, T015, T016, T019.
  - T022 (RELEASING.md) is [P] with code work — can start as soon as Foundational is done.
  - T023 (dry-run) depends on T021.
- **User Story 2 (Phase 4)**: Depends on US1 completion (because T024's CHANGELOG-authoring doc references the render-release-notes behavior delivered in US1, and T025's PR template references CHANGELOG conventions). US2 is authoring-only; T024 and T025 are [P].
- **User Story 3 (Phase 5)**: Depends on US1 completion (T026 documents extension-point markers that T021 introduces). US3 is documentation-only; T026 is a single task.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1) 🎯 MVP**: Requires only Foundational. No dependencies on other stories.
- **US2 (P2)**: Builds on US1's CHANGELOG rendering infrastructure; authoring-only tasks.
- **US3 (P3)**: Builds on US1's `release.yml` extension-point markers; authoring-only task.

### Within Each User Story

Per Constitution §IV (Test-First, NON-NEGOTIABLE): tests are written before the code they cover. For US1, that means T006–T013 (fixtures + test harnesses) are authored before T014–T017 (script implementations). The tests fail (red) until the implementations land; the implementations make them pass (green); refactoring as needed preserves green.

### Parallel Opportunities

- **Phase 2**: T002, T003, T005 in parallel; T004 after T002.
- **Phase 3 test block (T006–T013)**: all eight tasks [P]; different fixture directories and test files.
- **Phase 3 implementation block (T015, T016, T017, T018)**: all [P] after T003 (and T002 for T016). T014 is sequential-ish only because T019 depends on it.
- **Phase 4 (T024, T025)**: both [P].
- **Phase 6 (T027, T028)**: both [P].

---

## Parallel Example: User Story 1 test authoring

Once Foundational is complete, the following can run in parallel (different files, no shared state):

```text
- tests/release/fixtures/validate-release/ (T006) — fixture dirs
- tests/release/test-validate-release.sh (T007) — harness
- tests/release/fixtures/render-release-notes/ (T008)
- tests/release/test-render-release-notes.sh (T009)
- tests/release/fixtures/generate-sbom/ (T010)
- tests/release/test-generate-sbom.sh (T011)
- tests/release/fixtures/bump-release/ (T012)
- tests/release/test-bump-release.sh (T013)
```

Then implementations in parallel (after T003 common.sh is ready, and T002 prerequisites.json for T016):

```text
- scripts/release/render-release-notes.sh (T015)
- scripts/release/generate-sbom.sh (T016)
- scripts/release/bump-release.sh (T017)
- plugins/kusari/README.md "Verifying a release" section (T018)
- docs/RELEASING.md (T022)
```

`scripts/release/validate-release.sh` (T014) proceeds in sequence because the composite action (T019) depends on it.

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 (Setup): T001.
2. Complete Phase 2 (Foundational): T002–T005.
3. Complete Phase 3 (US1): T006–T023 — the full release machinery.
4. **Stop and validate**: T023 (dry-run) confirms the pipeline works end-to-end without publishing anything.
5. If validated, proceed to Polish and cut the first real release (T029). This IS the MVP — a maintainer can now cut signed, attested, SBOM-accompanied releases.

### Incremental Delivery

1. **MVP**: Phases 1–3, then T029 (first release). Users can now install `v0.3.0` with verifiable provenance.
2. **Authoring conventions**: Phase 4 (T024, T025). CHANGELOG quality baseline established.
3. **Extensibility documentation**: Phase 5 (T026). Future contributors can add workflow steps without editing existing ones.
4. **Polish**: remaining Phase 6 items.

### Parallel Team Strategy

With two developers:

1. Dev A: T001 → T002 → T004 (check-prerequisites refactor chain).
2. Dev B: T003 → T005 (common.sh + test in parallel).
3. Both: split the test-authoring block (T006–T013) and the implementation block (T014–T017) across themselves; T014 goes to whoever finishes their test block first (since T019 waits for it).
4. Either: T018 (README), T022 (RELEASING.md) in parallel with code work.
5. Either: T019 → T020 → T021 in sequence once T014 lands; T023 dry-run as the integration gate.
6. Polish and first release done together.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks.
- Tests in this feature are bash-harness style (per existing repo convention at `tests/test-run-kusari-scan.sh`); they must pass ShellCheck (T027).
- All GitHub Actions referenced in new workflows MUST be pinned by commit SHA (Constitution §III). Dependabot is suggested in T022 as the mechanism for keeping these current.
- The bootstrap case for FR-026 (first release has no prior OpenSSF Baseline audit to compare against) is handled in T021's workflow logic: if `gh release download` for the previous release fails with "no prior release," skip the comparison and treat the current audit's absence of HIGH/CRITICAL findings as the gate.
- Cross-repo admin actions (tag-protection rule, release-maintainers team, Dependabot config) are documented as prerequisites in T022 (RELEASING.md before-you-begin) but must be executed by a repo admin; they are not something the LLM can perform on the user's behalf.
- T023 (dry-run) and T029 (inaugural release) are the two end-to-end validation points. T023 is safe (no public artifacts); T029 is public and permanent.
- If T030's re-run of Constitution Check surfaces a deviation that wasn't anticipated, document it in plan.md's Complexity Tracking table and resolve before closing the feature branch.
