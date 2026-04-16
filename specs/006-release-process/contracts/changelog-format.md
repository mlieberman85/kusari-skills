# Contract: `plugins/kusari/CHANGELOG.md` Format

**Purpose**: Define the CHANGELOG structure the release process depends on, so the render and validate scripts have a stable parsing target.

## Document shape

```markdown
# Changelog

## Unreleased

### <Category>
- <bullet>

## <version> — <YYYY-MM-DD>

### <Category>
- <bullet>

## <older-version> — <YYYY-MM-DD>
...
```

## Rules

1. The file MUST begin with `# Changelog` (exactly).
2. The second-highest heading level is `##`, used for one of:
   - `## Unreleased` (exactly this string, top-most `##` heading, always present — may be empty)
   - `## <version> — <date>` where `<version>` is the unprefixed SemVer (e.g., `0.3.0`, `0.3.0-rc.1`) and `<date>` is `YYYY-MM-DD` UTC
3. Versioned `##` sections MUST be ordered newest-to-oldest below the `## Unreleased` section.
4. The separator between version and date MAY be an em-dash (`—`, U+2014) or a double-hyphen (`--`); the release workflow's renderer accepts both. `bump-release.sh` writes em-dash to normalize.
5. Subsections of a versioned section are `### <Category>` where `<Category>` is one of: `Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`. A category subsection MUST be present only if it has at least one bullet.
6. Bullets under a `### <Category>` subsection are `-` prefixed, may wrap across lines with two-space indented continuations, and may include inline markdown.
7. No other `##` heading levels are permitted (no `## Acknowledgements`, no `## Notes`, etc.). Put those at `###` or lower under the relevant version if needed.

## Validation regex (reference)

The canonical regex used by `validate-release.sh` (check C4) to match a version heading:

```text
^##\s+(?P<version>\d+\.\d+\.\d+(?:-[\w.]+)?)\s+(?:—|--)\s+(?P<date>\d{4}-\d{2}-\d{2})\s*$
```

The Unreleased heading matcher:

```text
^##\s+Unreleased\s*$
```

## Example (the current state of `plugins/kusari/CHANGELOG.md`, after this feature ships and one release has been cut)

```markdown
# Changelog

## Unreleased

## 0.3.0 — 2026-04-20

### Added
- Release process producing signed, provenance-attested, SBOM-accompanied releases (kusaridev/kusari-skills#006)

### Security
- Tag-protected release initiation; SLSA L3 provenance

## 0.2.0 — 2026-04-08

### Added
- Bundled MCP server configuration (`.mcp.json`) — `kusari-inspector` starts automatically when the plugin is enabled
- `SessionStart` hook to verify Kusari CLI is installed and provide setup guidance

## 0.1.0 — 2026-04-02

Initial pre-release.

### Skills
- **kusari-change-evaluate** -- Security scanning via Kusari Inspector (MCP server with CLI fallback)
- **kusari-change-fix** -- Interactive review and application of security fixes with enriched remediation guidance
```

Note: the `v0.1.0` entry uses `### Skills` which is outside the sanctioned category set. This is a pre-existing inconsistency; the release process leaves pre-existing entries alone (FR-020c's immutability spirit applies to *published* CHANGELOG entries too). New entries cut by `bump-release.sh` adhere to this contract.

## Renderer contract (`render-release-notes.sh`)

- Input: a version string (unprefixed or prefixed, accepts both).
- Output on stdout: the contents of the matching `## <version> — <date>` section, from the first line after the heading to the line before the next `##` heading or end-of-file — with trailing blank lines trimmed.
- Exit code 0 on success, exit code 1 if no matching section is found.
- Does NOT include the version heading itself in the output; the release entry's title already carries that information.
- Does NOT include any `## Unreleased` content even if the target version happens to be at the top of the file at the time of rendering.
