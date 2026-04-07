# Research: Agent Skills Spec Compliance

**Feature**: 004-skill-spec-compliance
**Date**: 2026-04-02

## R1: Naming Convention — Dots to Hyphens

**Decision**: Convert `kusari.change.evaluate` → `kusari-change-evaluate` and `kusari.change.fix` → `kusari-change-fix`.

**Rationale**: The Agent Skills spec requires `name` to contain only `[a-z0-9-]` with no dots. The simplest conversion replaces dots with hyphens. This also aligns with Ghost Security's naming pattern (`ghost-scan-code`, `ghost-scan-deps`).

**Alternatives considered**:
- Drop the vendor prefix: `change-evaluate`, `change-fix`. Too generic — loses the `kusari` namespace that identifies the skill provider.
- Use underscores: `kusari_change_evaluate`. Underscores are not allowed by the spec.
- Flatten to shorter names: `kusari-scan`, `kusari-remediate`. Would break the future extensibility plan for `kusari-repo-evaluate`, `kusari-repo-fix`, etc.

## R2: Directory Naming — Must Match `name`

**Decision**: Rename directories from `change-evaluate/` and `change-fix/` to `kusari-change-evaluate/` and `kusari-change-fix/`.

**Rationale**: The spec requires "Must match the parent directory name." Current directories don't include the `kusari` prefix. Renaming the directories to match the full `name` field is required.

**Alternatives considered**:
- Keep short directory names and change `name` to match: Would require names like `change-evaluate` which loses the vendor namespace.

## R3: `compatibility` Field

**Decision**: Add `compatibility` field to both skills: `"Requires Kusari CLI v0.21.0+ or kusari-inspector MCP server. jq required for CLI fallback."`

**Rationale**: The spec recommends including `compatibility` when skills have environment requirements. Both skills depend on external tools. The field is 1-500 characters and optional but adds discoverability.

## R4: `allowed-tools` Format

**Decision**: Keep current comma-separated format. The `skills-ref` validator does not flag this, and the spec says the field is "experimental" with "space-delimited" as a recommendation.

**Rationale**: The validator accepts the current format. Changing to space-delimited is a minor improvement but not a validation failure. We can adjust if the spec tightens this later.

**Alternatives considered**:
- Switch to space-delimited now: Proactive compliance but not required. The validator doesn't enforce it.

## R5: `metadata.version` Type

**Decision**: Keep `version: 1.0.0` as-is. YAML parses this as a string when quoted in the frontmatter.

**Rationale**: The `skills-ref` validator does not flag this. The spec says metadata is "arbitrary key-value mapping" without strict type constraints. The current format works.

## R6: Validation Approach

**Decision**: Use `skills-ref validate` as the primary acceptance test. Run it against each skill directory after all changes.

**Rationale**: The spec itself recommends using `skills-ref validate`. It catches naming violations, missing required fields, and directory mismatches. Zero errors = compliant.

**Current validation output** (before changes):
```
change-evaluate:
  - Skill name 'kusari.change.evaluate' contains invalid characters.
  - Directory name 'change-evaluate' must match skill name 'kusari.change.evaluate'

change-fix:
  - Skill name 'kusari.change.fix' contains invalid characters.
  - Directory name 'change-fix' must match skill name 'kusari.change.fix'
```
