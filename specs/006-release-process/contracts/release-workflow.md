# Contract: Release Workflow (`.github/workflows/release.yml`)

**Purpose**: The tag-triggered pipeline that converts a release-bump commit plus a matching tag into a published release with all required verification artifacts.

## Triggers

| Trigger | Condition | Behavior |
|---------|-----------|----------|
| `push` to a tag matching `v*.*.*` (including prerelease suffixes) | The commit the tag points at has a release-bump commit shape — see `validate-release.md` | Runs the full pipeline; publishes the release |
| `workflow_dispatch` with `dry_run: true` | Manual invocation from the Actions UI or `gh workflow run` | Runs all pipeline steps *except* the `gh release create` step and the push of provenance/signature to Sigstore's production instance (uses the Sigstore staging instance or `--bundle` output only). Produces workflow-artifact uploads of each intermediate file for inspection. |
| `workflow_dispatch` with `dry_run: false` on a branch | Manual invocation | Rejected: the workflow body asserts `github.ref_type == 'tag'` when `dry_run` is not set. |

## Inputs

| Input | Type | Required | Default | Effect |
|-------|------|----------|---------|--------|
| `dry_run` | boolean | only for `workflow_dispatch` | `false` | Skip publishing steps; produce workflow artifacts only |

## Outputs (observable effects)

**On success** (tag-triggered or `dry_run: false`):

1. Sigstore transparency log gains an entry for the tag signature (FR-014).
2. Sigstore transparency log gains an entry for the SLSA provenance attestation (FR-015).
3. A GitHub Release entry is created for the tag, with:
   - Title: the version in canonical form (e.g., `v0.3.0`).
   - Body: output of `render-release-notes.sh <version>` (the CHANGELOG section for this version).
   - `prerelease` flag: `true` if the version has a SemVer prerelease qualifier, else `false`.
   - Assets attached: `sbom.spdx.json`, `openssf-baseline.json`, `<version>.intoto.jsonl`, `<version>.sig`.
4. No other repository state is modified. In particular, the workflow MUST NOT push commits, rewrite history, or modify branches.

**On failure** at any step:

1. The workflow exits non-zero with the offending step clearly identified in the run log.
2. No GitHub Release entry is created (unless the failure is strictly after `gh release create`, in which case see Partial-state recovery below).
3. Previous successful-release state is untouched.

## Pipeline steps (ordered)

| # | Step | Fails the workflow on | Extension point |
|---|------|----------------------|-----------------|
| 1 | Checkout at tagged commit with full history | Any checkout error | `pre-release` *runs before this step* |
| 2 | Parse tag name → version (SemVer regex) | Tag name doesn't match `^v\d+\.\d+\.\d+(-[\w.]+)?$` | — |
| 3 | Run `scripts/release/validate-release.sh <version>` | Any invariant violation (see `validate-release.md`) | — |
| 4 | — | — | `post-version-bump` *runs here* |
| 5 | Run `scripts/release/render-release-notes.sh <version>` → release-notes body | CHANGELOG has no heading for `<version>` | — |
| 6 | Run `scripts/release/generate-sbom.sh <version>` → `sbom.spdx.json` | syft fails or produces empty/invalid SPDX | — |
| 7 | Run OpenSSF Baseline audit → `openssf-baseline.json` | Audit fails (exit non-zero) OR reports regression from baseline OR any new HIGH/CRITICAL finding | — |
| 8 | Call `slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml` with subjects = { source tree hash, `sbom.spdx.json` hash, `openssf-baseline.json` hash } | Provenance generator failure | — |
| 9 | `cosign sign --yes` the tag object | Signing failure (OIDC token issue, Sigstore outage) | — |
| 10 | — | — | `post-release-marker` *runs here* |
| 11 | `gh release create <tag> --title <version> --notes-file notes.md [--prerelease] sbom.spdx.json openssf-baseline.json <version>.intoto.jsonl <version>.sig` | Release creation or asset upload fails | — |
| 12 | — | — | `post-publish` *runs here* |

## Extension-point contract

Each extension point is a commented region in the YAML with exactly this shape:

```yaml
# === EXTENSION POINT: <name> ===
# (describe what state is available at this point; document any side-effect
#  constraints — e.g., "post-release-marker runs AFTER signature is in Sigstore's
#  transparency log, which is append-only; failures here do NOT retract the
#  signature.")
# === END EXTENSION POINT ===
```

Invariants (FR-007):
- Adding a step at an extension point MUST NOT require editing any line between two extension-point markers for a *different* extension point, nor any non-commented line outside all extension points.
- Existing step ordering MUST NOT be changed by extension additions.
- Extension steps MUST check their own preconditions; the workflow will not re-validate state on their behalf.

## Partial-state recovery

If a step in `post-release-marker` or later fails *after* the Sigstore transparency log has accepted the signature/provenance entry:

- Transparency-log entries are append-only; they cannot be retracted.
- The release entry on GitHub may or may not have been created depending on where the failure occurred.
- Recovery procedure (documented in `docs/RELEASING.md`):
  1. Do NOT re-tag with the same version identifier. FR-001 forbids reuse.
  2. Investigate the failure; fix the underlying cause.
  3. Cut a new release with the next patch version (e.g., `v0.3.1`) that supersedes the aborted one. The aborted `v0.3.0` has a Sigstore entry but no GitHub Release entry, which is a benign inconsistency (the signature exists; no consumer resolves to the missing release because `gh release create` never ran).
  4. If `gh release create` *did* succeed but a post-publish extension step failed, treat the release as published; fix the extension step; re-run only the extension step out-of-band if idempotent, or cut a new release otherwise.

## Authorization

- Tag push on `v*` patterns: restricted by tag-protection rules to the `release-maintainers` GitHub team (FR-019).
- `workflow_dispatch` invocation: restricted to users with `write` repository permission by default; tightening to the same `release-maintainers` team is a documented configuration in `docs/RELEASING.md`.

## Non-goals

- The workflow does NOT bump the version, edit `plugin.json`, edit `CHANGELOG.md`, or edit `marketplace.json`. Those are the maintainer's responsibility (via `scripts/release/bump-release.sh`) before tagging. Keeping the workflow free of mutating operations on repo files is what makes the release tag a pure trigger and makes provenance identity bind to the workflow's read-only shape.
- The workflow does NOT merge branches, push commits, or create PRs.
- The workflow does NOT retry Sigstore on failure. Signing/provenance issues surface directly to the maintainer.
