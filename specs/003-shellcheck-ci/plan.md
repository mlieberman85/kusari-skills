# Implementation Plan: ShellCheck CI Integration

**Branch**: `003-shellcheck-ci` | **Date**: 2026-04-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-shellcheck-ci/spec.md`

## Summary

Add ShellCheck linting to the CI pipeline via a GitHub Actions workflow, plus a local lint script that runs the same checks. The workflow triggers on push to main and on pull requests, analyzing all project-owned shell scripts while excluding the `.specify/` framework directory.

## Technical Context

**Language/Version**: Bash (POSIX-compatible shell scripts with `#!/usr/bin/env bash`)
**Primary Dependencies**: ShellCheck (pre-installed on GitHub Actions Ubuntu runners)
**Storage**: N/A
**Testing**: ShellCheck static analysis + existing bash test harness (`tests/test-*.sh`)
**Target Platform**: GitHub Actions (Ubuntu latest), macOS/Linux for local development
**Project Type**: CLI skills plugin (Markdown + Bash)
**Performance Goals**: CI check completes within 2 minutes (per SC-004)
**Constraints**: Must exclude `.specify/` directory; no new external dependencies beyond ShellCheck
**Scale/Scope**: ~6 project-owned shell scripts currently

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Security-First | PASS | ShellCheck catches security-relevant script bugs (injection via unquoted variables, unsafe eval). Adding linting to CI strengthens the security posture. No secrets or credentials involved. |
| II. Specification-Driven Development | PASS | Spec completed and clarified before this plan. User stories use Given-When-Then format. |
| III. Supply Chain Integrity | PASS | No new dependencies added to the project. ShellCheck is a pre-installed runner tool, not a project dependency. |
| IV. Test-First Discipline | PASS | The lint script itself will be validated by running it against the existing scripts. CI workflow tested by push/PR triggers. |
| V. Agent-Agnostic Design | PASS | All artifacts are standard Markdown and Bash. GitHub Actions YAML is portable. No agent-specific formats. |

**Gate result**: PASS — no violations, no complexity justification needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-shellcheck-ci/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    └── shellcheck.yml       # NEW: GitHub Actions workflow

scripts/
└── lint.sh                  # NEW: Local ShellCheck runner (shared with CI)
```

**Structure Decision**: Minimal footprint — one workflow file and one lint script. The lint script lives at the repo root `scripts/` directory (not inside `plugins/`) because it's a development tool, not a distributed skill artifact. The CI workflow calls this script to ensure local and CI behavior are identical.

## Complexity Tracking

No violations to justify — all constitution gates pass.
