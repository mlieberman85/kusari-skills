# Research: ShellCheck CI Integration

**Feature**: 003-shellcheck-ci
**Date**: 2026-04-02

## R1: ShellCheck Availability on GitHub Actions Runners

**Decision**: Use ShellCheck as pre-installed on Ubuntu runners (no install step needed).

**Rationale**: GitHub Actions `ubuntu-latest` runners include ShellCheck by default. This avoids adding an install step, extra dependencies, or version pinning complexity. The pre-installed version is kept reasonably current by GitHub.

**Alternatives considered**:
- Install via `apt-get`: Adds ~5s to CI, allows version pinning, but unnecessary complexity for a linting tool.
- Use the `ludeeus/action-shellcheck` marketplace action: Convenient but adds a third-party dependency (supply chain concern per Constitution Principle III). Running ShellCheck directly is simpler and more transparent.
- Install via `brew` or `snap`: Platform-specific, not needed since the tool is pre-installed.

## R2: ShellCheck Severity Levels and Configuration

**Decision**: Run ShellCheck with default severity (all levels: error, warning, info, style). Use exit code to determine pass/fail.

**Rationale**: FR-004 requires failing on "error or warning." ShellCheck's default behavior reports all severity levels and exits non-zero if any issues are found. Rather than filtering by severity, we run with defaults and address any info/style findings as they arise. This is simpler and catches more issues. If specific rules are too noisy, inline `# shellcheck disable=SCXXXX` directives can suppress them per FR-007.

**Alternatives considered**:
- `--severity=warning`: Would suppress info/style findings. Simpler initially but misses useful catches. Can be added later if noise becomes a problem.
- `.shellcheckrc` config file: Useful for project-wide rule customization. Not needed initially — can be added as a follow-up if the team wants to suppress specific rules globally.

## R3: Script Discovery Strategy

**Decision**: Use `find` to discover `.sh` files, excluding `.specify/` and `.git/` directories.

**Rationale**: Dynamically discovering scripts means new `.sh` files are automatically included without config changes (per edge case in spec). The exclusion list is minimal and unlikely to change. Using `find` is portable and works identically on CI and local.

**Alternatives considered**:
- Hardcoded file list: Simpler but requires manual updates when scripts are added/removed. Violates the edge case requirement for automatic discovery.
- `git ls-files '*.sh'`: Tracks only committed files. Works but misses executable scripts without `.sh` extension. `find` is more inclusive.
- Glob patterns in workflow YAML: GitHub Actions doesn't natively support recursive globs with exclusions in the same way.

## R4: Local Lint Script Design

**Decision**: Create a `scripts/lint.sh` script that CI also calls. Single source of truth for which files to check and how.

**Rationale**: FR-006 requires local and CI to use the same rules. Having CI call the same script the developer runs locally guarantees consistency. The script handles file discovery, exclusion, and ShellCheck invocation.

**Alternatives considered**:
- Makefile target: Adds a `make` dependency. The project doesn't currently use Make.
- Separate CI-only and local scripts: Violates the "same rules" requirement. Drift risk.
- npm/package.json script: Not applicable — this is a Bash/Markdown project.

## R5: Existing Script ShellCheck Compliance

**Decision**: Fix any existing ShellCheck issues as part of implementation (prerequisite task before enabling CI).

**Rationale**: If current scripts have ShellCheck warnings, the CI check will fail immediately on the first run. Fixing existing issues first ensures a clean baseline and a green CI from day one.

**Alternatives considered**:
- Add global suppressions for existing issues: Defeats the purpose. Better to fix them.
- Enable CI as warning-only initially: Complicates the workflow and delays the value of enforcement.
