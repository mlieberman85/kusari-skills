# Feature Specification: Agent Skills Spec Compliance

**Feature Branch**: `004-skill-spec-compliance`  
**Created**: 2026-04-02  
**Status**: Draft  
**Input**: User description: "Audit and update skill definitions to comply with the Agent Skills specification at agentskills.io, particularly enforcing kebab-case naming."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Skill Names Comply with Agent Skills Spec (Priority: P1)

As a plugin distributor, I want all skill `name` fields and directory names to follow the Agent Skills specification naming rules (lowercase kebab-case, no dots, name matches directory), so that the skills can be validated by standard tooling and listed in skill registries/marketplaces.

**Why this priority**: The `name` field is the primary identifier. Non-compliant names will fail validation and prevent listing in any spec-compliant registry.

**Independent Test**: Run `skills-ref validate` against each skill directory and verify zero validation errors.

**Acceptance Scenarios**:

1. **Given** a skill directory, **When** the `name` field is inspected, **Then** it contains only lowercase letters, numbers, and hyphens.
2. **Given** a skill directory, **When** the `name` field is compared to its parent directory name, **Then** they match exactly.
3. **Given** a skill with the name `kusari-change-evaluate`, **When** validated against the spec rules, **Then** it passes: 1-64 chars, no leading/trailing hyphens, no consecutive hyphens, no dots.
4. **Given** a skill previously invoked as `/kusari.change.evaluate`, **When** the name is changed to kebab-case, **Then** it becomes invocable as `/kusari-change-evaluate`.

---

### User Story 2 - SKILL.md Frontmatter Compliance (Priority: P1)

As a plugin distributor, I want all SKILL.md frontmatter fields to comply with the Agent Skills specification field constraints, so that skills pass validation and are correctly interpreted by any spec-compliant agent.

**Why this priority**: Invalid frontmatter prevents proper skill loading. This is co-equal with naming since both are required for spec compliance.

**Independent Test**: Inspect each SKILL.md frontmatter and verify all fields meet the spec constraints (description length, field types, etc.).

**Acceptance Scenarios**:

1. **Given** a SKILL.md file, **When** the `description` field is inspected, **Then** it is 1-1024 characters, non-empty, and describes both what the skill does and when to use it.
2. **Given** a SKILL.md file, **When** the `license` field is inspected, **Then** it is a short license name or reference.
3. **Given** a SKILL.md file, **When** the `metadata` field is inspected, **Then** it is a map of string keys to string values.
4. **Given** a SKILL.md file, **When** the `compatibility` field is checked, **Then** it exists if there are environment requirements (or is absent if none).

---

### User Story 3 - Install Script and Documentation Updated (Priority: P2)

As a user installing kusari skills, I want the installer and documentation to reflect the new skill names, so that I can discover and invoke skills correctly after installation.

**Why this priority**: Without updated docs and installer, users will try old names and fail.

**Independent Test**: Run `bash install.sh /tmp/test-repo` and verify the installed command files use the new kebab-case names.

**Acceptance Scenarios**:

1. **Given** the install script is run against a target repo, **When** skills are installed, **Then** the command files use kebab-case names (e.g., `kusari-change-evaluate.md`).
2. **Given** a user reads the README, **When** they look for skill commands, **Then** the documented names match the actual kebab-case skill names.
3. **Given** a user with a previous installation, **When** they run the updated installer, **Then** old dot-notation command files are cleaned up.

---

### Edge Cases

- What happens if a user has both old-style (dot-notation) and new-style (kebab-case) command files? The installer should clean up old files and install new ones.
- What happens if a skill name exceeds 64 characters? The current names are well under this limit.
- What happens to references to old skill names in SKILL.md body text (e.g., "Suggest running `/kusari.change.fix`")? These must be updated to the new names.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All skill `name` fields MUST contain only lowercase letters, numbers, and hyphens.
- **FR-002**: All skill `name` fields MUST NOT start or end with a hyphen, and MUST NOT contain consecutive hyphens.
- **FR-003**: All skill `name` fields MUST match their parent directory name exactly.
- **FR-004**: All skill `name` fields MUST be 1-64 characters.
- **FR-005**: All skill `description` fields MUST be 1-1024 characters and describe both what the skill does and when to use it.
- **FR-006**: The `compatibility` field SHOULD be added to skills that require external tools (Kusari CLI, jq, MCP server).
- **FR-007**: The `metadata` field MUST use string keys and string values only (version as string, not number).
- **FR-008**: The install script MUST install skills with kebab-case command names.
- **FR-009**: The install script MUST clean up old dot-notation command files during installation.
- **FR-010**: All documentation (README, CONTRIBUTING, plugin README, CHANGELOG) MUST reference the new kebab-case skill names.
- **FR-011**: All cross-references between skills (e.g., "suggest running /kusari.change.fix") MUST use the new kebab-case names.
- **FR-012**: All skill directories MUST pass `skills-ref validate` with zero errors.

### Key Entities

- **Skill Name**: The unique identifier for a skill. Must be kebab-case, 1-64 chars, matching the directory name. Current names: `kusari.change.evaluate` → `kusari-change-evaluate`, `kusari.change.fix` → `kusari-change-fix`.
- **Skill Directory**: The folder containing SKILL.md. Must be named identically to the `name` field.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `skills-ref validate` returns zero errors for every skill directory.
- **SC-002**: 100% of SKILL.md frontmatter fields comply with the spec constraints (field lengths, types, required fields).
- **SC-003**: The install script produces kebab-case command files and cleans up old-style files on every run.
- **SC-004**: Zero references to old dot-notation skill names remain in any documentation or skill body text.

## Assumptions

- The Agent Skills specification at https://agentskills.io/specification is the authoritative source for naming and format rules.
- The kebab-case naming conversion is: `kusari.change.evaluate` → `kusari-change-evaluate`, `kusari.change.fix` → `kusari-change-fix` (dots become hyphens).
- The Claude Code plugin system supports kebab-case skill names (Ghost Security uses this pattern: `ghost-scan-code`, `ghost-scan-deps`, etc.).
- Future skills will also follow this convention from the start.
- The `compatibility` field is recommended but not required by the spec; we add it for discoverability.
