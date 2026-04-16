# kusari-skills Development Guidelines

Claude Code plugin marketplace repository for Kusari security skills.

## Project Structure

```text
.claude-plugin/                              # Marketplace manifest
plugins/kusari/                              # Distributable plugin
  .claude-plugin/plugin.json                 # Plugin manifest
  skills/
    kusari-change-evaluate/
      SKILL.md                               # Scan skill definition
      scripts/                               # Bash scripts for CLI scan pipeline
        common.sh                            # Shared utilities
        scan.sh                              # Scan orchestrator
        parse-sarif.sh                       # SARIF parser
    kusari-change-fix/
      SKILL.md                               # Remediation skill definition
  CHANGELOG.md
  README.md                                  # Plugin usage docs
specs/                                       # Feature specifications (dev only)
tests/                                       # Test harnesses and fixtures (dev only)
install.sh                                   # Manual installer for target repos
```

## Active Technologies
- Bash (POSIX-compatible shell scripts with `#!/usr/bin/env bash`) + ShellCheck (pre-installed on GitHub Actions Ubuntu runners) (003-shellcheck-ci)
- Markdown (SKILL.md) + Bash (install.sh, scripts) + YAML (frontmatter) + `skills-ref` validator (Python, installed via `uv tool install`) (004-skill-spec-compliance)
- Bash (POSIX-compatible, `#!/usr/bin/env bash`, `set -euo pipefail`) for release scripts; YAML for GitHub Actions workflows; JSON for manifest manipulation (via `jq`). (006-release-process)
- Git repo (tags, release-bump commits); GitHub Releases (release entries + assets); Sigstore transparency log (provenance + signatures); GitHub Security Advisories database (for security withdrawals). (006-release-process)

- Markdown (SKILL.md definitions) + Bash (scan pipeline scripts) + Kusari CLI v0.21.0+ (Go binary, installed separately)

## Commands

- `/kusari-change-evaluate` -- Run a security scan on the current repository
- `/kusari-change-fix` -- Review and apply security fixes from scan results

## Code Style

- Markdown skill definitions: Use YAML frontmatter with `name`, `description`, `allowed-tools`, `license`
- Bash scripts: Follow existing conventions in `plugins/kusari/skills/kusari-change-evaluate/scripts/`

## Testing

```bash
bash tests/test-run-kusari-scan.sh
bash tests/test-sarif-parser.sh
```

## Speckit

This repo uses speckit for feature specification management.
- **Speckit root**: `.specify/`
- **Specs**: `specs/`
- Run speckit commands (`/speckit.*`) from the repo root.

## Recent Changes
- 006-release-process: Added Bash (POSIX-compatible, `#!/usr/bin/env bash`, `set -euo pipefail`) for release scripts; YAML for GitHub Actions workflows; JSON for manifest manipulation (via `jq`).
- 003-shellcheck-ci: Added Bash (POSIX-compatible shell scripts with `#!/usr/bin/env bash`) + ShellCheck (pre-installed on GitHub Actions Ubuntu runners)
- 004-skill-spec-compliance: Added Markdown (SKILL.md) + Bash (install.sh, scripts) + YAML (frontmatter) + `skills-ref` validator (Python, installed via `uv tool install`)
