# Contract: `scripts/release/validate-release.sh`

**Purpose**: Check all release-time invariants before any artifact is produced. Maps directly to FR-005 (fail safely and visibly on invariant violations) and implements the pre-tag gate used by both the PR validation workflow and the tag-triggered release workflow.

## Invocation

```bash
scripts/release/validate-release.sh <version> [--from <ref>]
```

| Argument | Required | Meaning |
|----------|----------|---------|
| `<version>` | yes | Target version in canonical tag form (`v<major>.<minor>.<patch>[-<prerelease>]`). May or may not be an existing tag; the script does not require the tag to exist (the release workflow creates it by pushing; the PR validator runs before the tag exists). |
| `--from <ref>` | no | Git ref to treat as the "release-bump commit" being validated. Defaults to `HEAD`. The release workflow passes the tagged commit; the PR validator passes the PR head. |

## Behavior

The script performs the following checks, in order, against the repository state at `--from`:

| Check | Failure condition | Error message (prefix) |
|-------|-------------------|------------------------|
| C1 | `<version>` matches `^v\d+\.\d+\.\d+(-[\w.]+)?$` | `E1: version format invalid:` |
| C2 | No other tag already exists with the same name | `E2: version already released:` |
| C3 | `plugins/kusari/.claude-plugin/plugin.json`'s `version` field (unprefixed SemVer) equals the numeric part of `<version>` | `E3: plugin.json version mismatch:` |
| C4 | `plugins/kusari/CHANGELOG.md` contains exactly one heading matching `^## <unprefixed-version> —` (em-dash OR double-hyphen accepted) and that heading is not inside an `## Unreleased` block | `E4: CHANGELOG missing entry for:` |
| C5 | The CHANGELOG section for `<version>` is non-empty (contains at least one bulleted change in at least one `### <Category>` subsection) | `E5: CHANGELOG entry empty:` |
| C6 | `.claude-plugin/marketplace.json`'s plugin entry (the one with `name == "kusari"`) has `source.ref == <version>` AND `source.source == "github"` AND `source.path == "plugins/kusari"` | `E6: marketplace.json source.ref mismatch:` |
| C7 | The git working tree at `--from` is clean (no uncommitted or staged changes relative to `--from`). When `--from == HEAD`, this checks the live working tree. | `E7: working tree has uncommitted changes` |
| C8 | No other `## Unreleased` content precedes the `<version>` section (i.e., there is exactly one `## Unreleased` heading and it has no change bullets; having pending unreleased content while tagging is the bug pattern caught here) | `E8: Unreleased section is non-empty:` |
| C9 | `plugins/kusari/README.md` contains a heading matching `^##\s+Verifying` (case-insensitive) under which both the strings `slsa-verifier` and `cosign` appear at least once; this enforces FR-028 at release time | `E9: README missing verification section:` |

All checks run; all failures are reported (not short-circuited). This means a single run shows the maintainer every thing that needs to be fixed.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All checks pass |
| `1` | One or more checks failed (see stderr for details) |
| `2` | Usage error (missing argument, unknown flag) |
| `3` | Environment error (jq not found, not in a git repo, `--from` ref doesn't exist) |

## Output

- **stdout**: On success, a one-line summary: `OK: v<version> release invariants validated`.
- **stderr**: On failure, one line per failed check, each beginning with its error code (e.g., `E3: plugin.json version mismatch: expected 0.3.0, found 0.2.0`). After all failures are listed, a summary line `<N> check(s) failed` is emitted.

No normal-operation output is produced to stderr. This keeps the script composable with other CI tooling.

## Side effects

None. The script is pure read-only against the filesystem and git. It does not modify any file, create tags, or push.

## Examples

```bash
# From the release workflow (tag just pushed), version parsed from GITHUB_REF:
scripts/release/validate-release.sh "v0.3.0"
echo $?  # → 0

# From the PR validator on a release-bump PR whose head is at SHA abc1234:
scripts/release/validate-release.sh "v0.3.0" --from abc1234
echo $?  # → 0 if the PR is ready; 1 otherwise

# Typical maintainer pre-push check:
bash scripts/release/bump-release.sh 0.3.0
scripts/release/validate-release.sh "v0.3.0"
# Review, commit, then:
git tag v0.3.0
```

## Test coverage contract

Per the spec's Edge Cases and Functional Requirements, the test suite at `tests/release/test-validate-release.sh` MUST cover:

- **Happy path**: a fixture representing a correct post-bump state passes all checks (exit 0).
- **E1**: malformed versions (`0.3.0` without `v`, `v0.3`, `vfoo`) are rejected.
- **E2**: a version whose tag already exists is rejected. (Uses a git-tag-bearing fixture or a mocked `git tag -l` invocation.)
- **E3**: plugin.json at `0.2.0` with a target of `v0.3.0` is rejected.
- **E4**: CHANGELOG missing the target version's heading is rejected.
- **E5**: CHANGELOG has the heading but no bullets under any subsection.
- **E6**: marketplace.json's source.ref is stale (points at the previous version) or has the wrong shape (plain string rather than the pinned-ref object form).
- **E7**: working tree has an unstaged modification.
- **E8**: `## Unreleased` still contains bullets that haven't been graduated.
- **E9**: README has no `Verifying` section; README has the section but is missing `slsa-verifier`; README has the section but is missing `cosign`.
- **Multiple simultaneous failures**: a fixture where E3 and E4 both hold; the script reports both and exits 1.
