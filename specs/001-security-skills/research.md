# Research: Security Skills

**Feature**: 001-security-skills
**Date**: 2026-03-03

## R1: Kusari CLI Scan Output Format

**Decision**: Use `--output-format sarif` for programmatic parsing;
present results to developers in human-readable markdown.

**Rationale**: SARIF 2.1.0 provides structured JSON with typed
fields (rule IDs, severity levels, file locations, code snippets)
that are straightforward to parse in shell scripts using `jq`.
The markdown format uses glamour terminal rendering which is
harder to parse. Using SARIF internally and converting to readable
output gives us the best of both worlds.

**Alternatives considered**:
- Markdown output (`--output-format markdown`): Human-readable but
  requires regex parsing to extract file paths, line numbers, and
  mitigations. Fragile and error-prone.
- Raw API response: Not directly available via CLI; would require
  reimplementing the HTTP client.

### SARIF Schema Details

The Kusari Inspector SARIF output contains 3 rule types:

1. **`security-analysis`** (1 per scan): Overall result with
   `should_proceed`, `health_score` (0-5), `justification`, and
   `recommendation`. Severity is `error` (should not proceed),
   `warning` (mitigations exist), or `note` (clean).

2. **`code-mitigation`** (0-N per scan): Per-file code fix. Each
   has `locations[0].physicalLocation` with `artifactLocation.uri`
   (file path), `region.startLine` (line number), and
   `region.snippet.text` (code snippet/fix). The `message.text`
   describes the issue.

3. **`dependency-mitigation`** (0-M per scan): Dependency concern.
   Has `message.text` describing the issue and action. No file
   location (location-independent findings).

### Inspector API Response Structure

The CLI receives a `SecurityAnalysis` containing:
- `recommendation` (string): Action to take
- `justification` (string): Why the recommendation
- `code_mitigations[]`: Array of `{line_number, path, content, code}`
- `dependency_mitigations[]`: Array of `{content}`
- `should_proceed` (bool): Whether code is safe to merge
- `health_score` (int): 0-5 score
- `failed_analysis` (bool): Inspector processing failure

## R2: Skill Authoring Patterns

**Decision**: Follow the existing `speckit.*` pattern for skill
file structure with YAML front matter, structured execution steps,
and shared Bash script infrastructure.

**Rationale**: Consistency with the existing 9 speckit skills
ensures developers familiar with the project can understand and
extend the kusari skills. The pattern is proven and well-documented.

**Key patterns to follow**:
- YAML front matter with `description` and `handoffs`
- `## User Input` section referencing `$ARGUMENTS`
- Numbered execution steps with prerequisite checking
- Bash scripts for reusable logic (`.claude/scripts/kusari/`)
- JSON output from scripts for machine-readable results
- Atomic file operations (save after each integration)
- Error-first validation (check CLI, auth, git before proceeding)

**Alternatives considered**:
- Standalone Python/Node scripts: Would add dependencies violating
  constitution Principle III (Supply Chain Integrity) and V
  (Agent-Agnostic Design).
- Inline-only skill logic: Would duplicate auth checking, error
  handling, and output parsing across skills, violating DRY.

## R3: Authentication Detection

**Decision**: Check for Kusari CLI auth by running
`kusari repo scan` and detecting auth errors, OR by checking for
JWT token files in the CLI's config directory.

**Rationale**: The Kusari CLI stores JWT tokens locally after
`kusari auth login`. The scan command validates tokens before
uploading. Rather than duplicating token validation logic, we can:
(a) attempt the scan and catch auth errors, or (b) check if the
token file exists as a pre-flight check.

**Approach**: Pre-flight check for token existence + graceful error
handling if the token is expired (detected at scan time).

**Alternatives considered**:
- Always require manual `kusari auth login` first: Poor UX; the
  skill should guide the developer through auth if needed.
- Embed auth in the skill: Would require OAuth2 client credentials;
  the CLI already handles this well.

## R4: Result Persistence Strategy

**Decision**: Persist scan results as timestamped markdown files in
`.claude/security/scans/` directory at the repository root.

**Rationale**: Markdown is human-readable without tooling, can be
committed to version control for tracking, and can be reviewed in
any text editor or git diff tool. Timestamping preserves history
per FR-005.

**File naming**: `.claude/security/scans/scan-YYYY-MM-DDTHH-MM-SS.md`

**Alternatives considered**:
- JSON files: Machine-readable but not developer-friendly for review.
- Overwrite single file: Loses history, violates FR-005.
- Store SARIF directly: Useful for tooling integration but not
  human-readable; could store alongside markdown as optional output.

## R5: Extensibility Architecture

**Decision**: Shared Bash scripts in `.claude/scripts/kusari/` provide
common functions; each skill is a standalone `.claude/commands/`
file that calls shared scripts.

**Rationale**: Matches the existing `speckit` pattern where
`.specify/scripts/bash/` provides reusable logic and
`.claude/commands/speckit.*.md` provides agent-specific triggers.
New skills only need: (1) a new command file, (2) optionally a
new script for command-specific logic.

**Shared infrastructure**:
- `common.sh`: CLI detection, auth checking, git helpers, error
  formatting, result persistence
- `parse-sarif.sh`: SARIF-specific extraction (reusable if future
  commands also output SARIF)

**Alternatives considered**:
- Plugin framework: Over-engineered for 2 initial skills + planned
  extensions. The file-per-skill pattern is sufficient and simpler.
- Monolithic skill: Would require modifying the single file for
  every new command, violating FR-016.

## R6: Git Revision Default

**Decision**: Default to the repository's default branch (`main` or
`master`), detected via `git symbolic-ref refs/remotes/origin/HEAD`
or fallback to common branch names.

**Rationale**: Comparing against the default branch shows all
changes on the current feature branch, which is the standard CI/CD
comparison point and matches developer mental models.

**Detection approach**:
```bash
# Try symbolic ref first (most reliable)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^refs/remotes/origin/@@')

# Fallback: check common names
if [ -z "$DEFAULT_BRANCH" ]; then
  for branch in main master; do
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
      DEFAULT_BRANCH="$branch"
      break
    fi
  done
fi
```

**Alternatives considered**:
- Always use `HEAD~1`: Only shows last commit, misses broader context.
- Always ask: Adds friction to the common case.
