# Feature Specification: ShellCheck CI Integration

**Feature Branch**: `003-shellcheck-ci`  
**Created**: 2026-04-02  
**Status**: Draft  
**Input**: User description: "Can we use shellcheck for testing the shell scripts and create a github action for it?"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automated Shell Script Linting on Push (Priority: P1)

As a developer, I want shell scripts in the repository to be automatically checked for correctness and best practices whenever code is pushed or a pull request is opened, so that common scripting errors (quoting bugs, undefined variables, portability issues) are caught before they reach the main branch.

**Why this priority**: This is the core value proposition — catching bugs automatically before merge. Without this, every other story has no foundation.

**Independent Test**: Can be fully tested by pushing a commit containing a shell script with a known ShellCheck warning and verifying the CI check reports the issue.

**Acceptance Scenarios**:

1. **Given** a pull request that adds a shell script with ShellCheck warnings, **When** the CI pipeline runs, **Then** the check fails and the specific warnings are visible in the GitHub Actions log.
2. **Given** a pull request where all shell scripts pass ShellCheck, **When** the CI pipeline runs, **Then** the check passes with a green status.
3. **Given** a push to the main branch, **When** the CI pipeline runs, **Then** ShellCheck analyzes all project-owned shell scripts in the repository.

---

### User Story 2 - Local ShellCheck Validation (Priority: P2)

As a developer, I want to run the same ShellCheck validation locally before pushing, so that I can fix issues without waiting for CI feedback.

**Why this priority**: Shortens the feedback loop. Developers can fix issues locally before pushing, reducing failed CI runs.

**Independent Test**: Can be fully tested by running a local command that checks all shell scripts and reports the same results as CI would.

**Acceptance Scenarios**:

1. **Given** a developer has ShellCheck installed locally, **When** they run the validation command from the repository root, **Then** all project-owned shell scripts are checked and results are displayed.
2. **Given** a developer runs the local validation on clean scripts, **When** all scripts pass, **Then** the command exits with success (exit code 0).
3. **Given** a developer runs the local validation on scripts with issues, **When** issues are found, **Then** the command exits with failure (exit code non-zero) and lists the specific issues.

---

### User Story 3 - Targeted Script Scope (Priority: P2)

As a project maintainer, I want ShellCheck to analyze only the project's own shell scripts (not vendored or framework scripts), so that CI results are relevant and actionable.

**Why this priority**: The repository contains `.specify/` framework scripts that are managed externally and should not generate noise in CI results. Without scoping, the CI check may fail on code the team doesn't control.

**Independent Test**: Can be fully tested by verifying that CI only reports issues from project-owned scripts and ignores framework-managed directories.

**Acceptance Scenarios**:

1. **Given** the repository contains shell scripts under `.specify/` (speckit framework), **When** CI runs, **Then** those scripts are excluded from analysis.
2. **Given** the repository contains shell scripts under `plugins/`, `tests/`, and the project root (`install.sh`), **When** CI runs, **Then** all of those scripts are included in analysis.

---

### Edge Cases

- What happens when a new shell script is added to the repository? It should be automatically picked up by CI without configuration changes.
- What happens when there are no shell scripts to check? The CI step should succeed gracefully rather than fail.
- What happens when a script uses a ShellCheck inline directive (`# shellcheck disable=SC2034`) to suppress a specific warning? The directive should be respected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CI pipeline MUST run ShellCheck against all project-owned shell scripts on every push to the main branch and on every pull request.
- **FR-002**: The CI pipeline MUST exclude shell scripts in the `.specify/` directory from analysis.
- **FR-003**: The CI pipeline MUST include shell scripts under `plugins/`, `tests/`, and the repository root.
- **FR-004**: The CI pipeline MUST fail (report a non-passing status) when any ShellCheck error or warning is found.
- **FR-005**: The CI pipeline MUST display specific file paths, line numbers, and ShellCheck error codes in its output so developers can locate and fix issues.
- **FR-006**: A local validation command MUST be available that checks the same set of scripts with the same rules as CI.
- **FR-007**: The CI pipeline MUST support ShellCheck inline directives (`# shellcheck` comments) for intentional suppressions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every pull request receives automated shell script linting feedback within the CI check results.
- **SC-002**: Developers can reproduce CI linting results locally with a single command before pushing.
- **SC-003**: Only project-owned scripts are analyzed — framework/vendored scripts produce zero CI noise.
- **SC-004**: The CI check completes within 2 minutes for the current set of repository scripts.

## Assumptions

- GitHub Actions is the CI platform (the repository is hosted on GitHub and already has a `.github/` directory).
- ShellCheck is available as a pre-installed tool in GitHub Actions runners (Ubuntu runners include it by default) or can be trivially installed.
- The project uses `bash` as the shell dialect for all scripts (consistent with existing `#!/usr/bin/env bash` shebangs).
- Existing ShellCheck inline directives in test files (`# shellcheck source=...`) should continue to work.
- The `.specify/` directory is the only directory to exclude; all other directories containing `.sh` files are project-owned.
