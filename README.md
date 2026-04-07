# Kusari Security Skills for Claude Code

Plugin marketplace repository for [Kusari](https://kusari.dev) security scanning and remediation skills.

## Installation

### Via Plugin Marketplace

```
claude plugin marketplace add kusaridev/kusari-skills
claude plugin install kusari@kusari-security
```

Or from within Claude Code:

```
/plugin marketplace add kusaridev/kusari-skills
/plugin install kusari@kusari-security
```

> Currently, you will need to restart Claude Code for the plugin to load.

### Manual Installation

```bash
bash install.sh /path/to/target-repo
```

## Skills

| Skill | Description |
|-------|-------------|
| `/kusari-change-evaluate` | Run a security scan against a git revision |
| `/kusari-change-fix` | Review and apply security fixes from scan results |

## Kusari Plugin ([plugins/kusari/](plugins/kusari/README.md))

Detailed usage documentation, prerequisites, and scan output format.

## Prerequisites

- Git repository
- [Kusari CLI](https://github.com/kusaridev/kusari-cli) v0.21.0+ OR the `kusari-inspector` MCP server
- [Claude Code](https://docs.claude.ai/en/docs/claude-code-overview)

## Development

### Linting

```bash
bash scripts/lint.sh
```

Runs [ShellCheck](https://www.shellcheck.net/) on all project-owned shell scripts (excludes `.specify/` framework scripts). This is the same check that runs in CI.

### Testing

```bash
bash tests/test-run-kusari-scan.sh
bash tests/test-sarif-parser.sh
```

Tests use fixture data and do not require the Kusari CLI or network access.

### Project Structure

```
.claude-plugin/          # Marketplace manifest
plugins/kusari/          # Distributable plugin
  .claude-plugin/        # Plugin manifest
  skills/                # Skill definitions
  CHANGELOG.md
  README.md
specs/                   # Feature specifications (dev only)
tests/                   # Test harnesses and fixtures (dev only)
install.sh               # Manual installer
```

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

## License

[Apache-2.0](LICENSE)
