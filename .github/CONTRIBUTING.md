# Contributing to Kusari Skills

Thank you for your interest in contributing to Kusari Skills.

## Getting Started

1. Fork and clone this repository
2. Create a feature branch from `main`
3. Make your changes
4. Run the linter: `bash scripts/lint.sh`
5. Run the test suite: `bash tests/test-run-kusari-scan.sh && bash tests/test-sarif-parser.sh`
6. Submit a pull request

## Skill Development

Skills live under `plugins/kusari/skills/<skill-name>/`. Each skill has:

- `SKILL.md` -- Skill definition with YAML frontmatter and step-by-step instructions
- `scripts/` -- Supporting bash scripts (if needed)

See existing skills for examples of the expected format.

## Reporting Issues

Open an issue on GitHub with:
- Steps to reproduce
- Expected vs actual behavior
- Claude Code version and OS

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 License.
