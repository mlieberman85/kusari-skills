# Implementation Plan: Agent Skills Spec Compliance

**Branch**: `004-skill-spec-compliance` | **Date**: 2026-04-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-skill-spec-compliance/spec.md`

## Summary

Rename skill directories and update `name` fields to comply with the Agent Skills specification kebab-case naming rules. Update all SKILL.md frontmatter fields (compatibility, allowed-tools format, metadata types). Update install.sh, README, CHANGELOG, and all cross-references. Validate with `skills-ref validate`.

## Technical Context

**Language/Version**: Markdown (SKILL.md) + Bash (install.sh, scripts) + YAML (frontmatter)
**Primary Dependencies**: `skills-ref` validator (Python, installed via `uv tool install`)
**Storage**: N/A
**Testing**: `skills-ref validate` for spec compliance + existing bash test harness
**Target Platform**: Claude Code plugin system, any Agent Skills spec-compliant agent
**Project Type**: CLI skills plugin (Markdown + Bash)
**Constraints**: Must maintain backward compatibility in install.sh (clean up old names). Must pass `skills-ref validate` with zero errors.
**Scale/Scope**: 2 skills, ~10 files to update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Security-First | PASS | Rename only — no security-relevant changes. Skill functionality unchanged. |
| II. Specification-Driven Development | PASS | Spec completed before this plan. Driven by external Agent Skills specification. |
| III. Supply Chain Integrity | PASS | No new dependencies added to the project. `skills-ref` is a dev tool, not a project dependency. |
| IV. Test-First Discipline | PASS | Validation via `skills-ref validate` serves as the acceptance test. Existing tests confirm no functional regression. |
| V. Agent-Agnostic Design | PASS | Aligning with the Agent Skills open spec improves agent portability. Kebab-case naming is the spec-mandated standard. |

**Gate result**: PASS

## Project Structure

### Documentation (this feature)

```text
specs/004-skill-spec-compliance/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
plugins/kusari/skills/
├── kusari-change-evaluate/          # RENAMED from change-evaluate/
│   ├── SKILL.md                     # UPDATED: name, compatibility, allowed-tools
│   └── scripts/                     # UNCHANGED
│       ├── common.sh
│       ├── scan.sh
│       └── parse-sarif.sh
└── kusari-change-fix/               # RENAMED from change-fix/
    └── SKILL.md                     # UPDATED: name, compatibility, allowed-tools

plugins/kusari/
├── .claude-plugin/plugin.json       # UNCHANGED
├── README.md                        # UPDATED: skill names
└── CHANGELOG.md                     # UPDATED: skill names

install.sh                           # UPDATED: new paths, old-name cleanup
README.md                            # UPDATED: skill names
.github/CONTRIBUTING.md              # UNCHANGED (no skill names referenced)
CLAUDE.md                            # UPDATED: skill names
```

**Structure Decision**: Rename skill directories to match the kebab-case `name` field. All other structure remains the same.

### Name Mapping

| Current | New | Rule |
|---------|-----|------|
| `change-evaluate/` dir + `kusari.change.evaluate` name | `kusari-change-evaluate/` dir + `kusari-change-evaluate` name | name must match dir, kebab-case only |
| `change-fix/` dir + `kusari.change.fix` name | `kusari-change-fix/` dir + `kusari-change-fix` name | name must match dir, kebab-case only |

## Complexity Tracking

No violations to justify — all constitution gates pass.
