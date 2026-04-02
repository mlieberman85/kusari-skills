# Quickstart: ShellCheck CI Integration

## For Developers

### Run linting locally

```bash
bash scripts/lint.sh
```

This checks all project-owned shell scripts (excluding `.specify/`). Exit code 0 means all scripts pass; non-zero means issues were found.

### Fix a ShellCheck issue

1. Run `bash scripts/lint.sh` to see issues with file paths and line numbers
2. Open the flagged file at the indicated line
3. Fix the issue (ShellCheck error codes like SC2086 link to https://www.shellcheck.net/wiki/SCXXXX)
4. Re-run `bash scripts/lint.sh` to verify

### Suppress a specific warning

If a warning is intentional, add an inline directive above the flagged line:

```bash
# shellcheck disable=SC2034
UNUSED_VAR="this is intentional"
```

### Install ShellCheck locally

- **macOS**: `brew install shellcheck`
- **Linux**: `apt-get install shellcheck` or `snap install shellcheck`

## For CI

The GitHub Actions workflow at `.github/workflows/shellcheck.yml` runs automatically on:
- Push to `main`
- Pull requests targeting any branch

No configuration needed. The workflow calls the same `scripts/lint.sh` used locally.
