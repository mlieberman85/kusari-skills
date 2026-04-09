# Future: Kusari CLI Install Path

> **STATUS: NOT YET AVAILABLE — DO NOT PUBLISH**
>
> This document contains draft content for when `kusari ai install` supports
> installing skills. Do not add this to user-facing docs until all prerequisites
> are met.

## Prerequisites Before Publishing

- [ ] `kusari ai serve` released (currently only in main, not in a CLI release)
- [ ] Skills plugin released and installable via `claude plugin install kusari`
- [ ] `kusari ai install` updated to fetch and install skills from kusari-skills releases
- [ ] This content reviewed and merged into README.md and CHANGELOG.md

---

## Content to Add to README.md

Add as a second install option under `## Installation`:

```markdown
### Alternative: Kusari CLI

Install via the Kusari CLI — works with Claude Code and other supported agents:

\`\`\`bash
kusari ai install claude-code    # Claude Code
kusari ai install cursor    # Cursor
kusari ai install windsurf  # Windsurf
\`\`\`

This configures the MCP server and installs skills for the selected agent.
```

## Content to Add to install.sh Usage

Add to the `usage()` help text:

```
echo "  kusari ai install claude-code              # Via Kusari CLI"
```

## Content to Add to CHANGELOG.md

Add under the relevant version:

```markdown
### Added
- Documented `kusari ai install` as alternative install path
```
