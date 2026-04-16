# Releasing the Kusari Plugin

This document describes how to cut a release, verify it, handle prereleases, withdraw a broken release, and extend the release process. It also covers CHANGELOG authoring conventions.

## Before you begin (one-time setup)

These steps are performed once by a repo admin before the first release:

1. **Tag protection rule**: configure a ruleset on `kusaridev/kusari-skills` that restricts push permission on tags matching `v*` to the `release-maintainers` team. (Settings → Rules → Rulesets → New tag ruleset.)
2. **`release-maintainers` team**: create the team under the `kusaridev` organization. Add the humans authorized to cut releases. 2FA required.
3. **Branch protection on `main`**: already enforced via the org-level "Security Baseline" ruleset (required reviews, no force-push). Verify with `gh api repos/kusaridev/kusari-skills/rulesets`.
4. **Dependabot** (recommended): enable Dependabot version updates for `.github/workflows/release.yml` and `.github/workflows/release-validate.yml` to keep SHA-pinned actions current.
5. **Sigstore public-good**: no credential setup needed — the release workflow uses the GitHub Actions OIDC token with Sigstore's public-good instance.

## Per-release procedure

### Step 1 — Confirm readiness

```bash
git checkout main && git pull
```

Review the `## Unreleased` section of `plugins/kusari/CHANGELOG.md`. Every bullet there becomes part of the release notes consumers read. If anything isn't ready, hold it for the next release.

Choose the target version per [SemVer](https://semver.org/):
- **patch** (0.2.0 → 0.2.1): bug fixes only
- **minor** (0.2.0 → 0.3.0): new capabilities, no breaking changes
- **major** (0.x.y → 1.0.0): breaking changes or first stable release
- **prerelease** (0.3.0-rc.1): release candidate for validation

### Step 2 — Open a release-bump PR

```bash
git checkout -b release/v0.3.0

bash scripts/release/bump-release.sh 0.3.0

git diff  # Review the three coordinated edits

git add plugins/kusari/.claude-plugin/plugin.json \
        plugins/kusari/CHANGELOG.md \
        .claude-plugin/marketplace.json

git commit -m "Release v0.3.0"

git push -u origin release/v0.3.0

gh pr create --title "Release v0.3.0" --body "$(cat <<'EOF'
## Summary
Release v0.3.0 — see CHANGELOG.md for details.

## Test plan
- [ ] `release-validate.yml` workflow passes on this PR
- [ ] CHANGELOG section reviewed for accuracy and required-action call-outs
EOF
)"
```

The `release-validate.yml` workflow runs automatically and invokes `validate-release.sh` with all 9 invariant checks. Fix any failures and push again.

### Step 3 — Get the PR reviewed and merged

Standard review process per the org ruleset (1 approving review required).

### Step 4 — Tag and push

```bash
git checkout main && git pull

git tag v0.3.0

git push origin v0.3.0
```

This triggers `.github/workflows/release.yml`. The workflow:
1. Re-validates invariants.
2. Renders release notes from CHANGELOG.
3. Generates the SBOM.
4. Runs the OpenSSF Baseline audit.
5. Produces SLSA provenance and signs the tag.
6. Creates the GitHub Release with all assets attached.

Expected runtime: under 15 minutes.

### Step 5 — Verify

```bash
gh release view v0.3.0 --repo kusaridev/kusari-skills
gh release download v0.3.0 --repo kusaridev/kusari-skills

slsa-verifier verify-artifact \
  --provenance-path v0.3.0.intoto.jsonl \
  --source-uri github.com/kusaridev/kusari-skills \
  --source-tag v0.3.0 \
  openssf-baseline.json

cosign verify-blob-attestation \
  --certificate-identity "https://github.com/kusaridev/kusari-skills/.github/workflows/release.yml@refs/tags/v0.3.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --bundle v0.3.0.sig \
  <(git cat-file -p v0.3.0)
```

Both verifications must succeed.

### Step 6 — Announce (optional)

The release is public. Announce in any appropriate channels.

## Prerelease / release candidate

Follow the same procedure with a prerelease version:

```bash
bash scripts/release/bump-release.sh 0.3.0-rc.1
# ... PR, merge, tag, push tag ...
git tag v0.3.0-rc.1 && git push origin v0.3.0-rc.1
```

The workflow detects the SemVer prerelease qualifier and sets the GitHub Release `prerelease` flag. Default-install consumers (unpinned) will NOT see it; only consumers who pin to `@v0.3.0-rc.1` will.

When the candidate is validated, cut the corresponding stable release (`v0.3.0`).

## Withdrawing a broken release

### Fix available: cut a superseding release

1. Cut a new patch release (e.g., `v0.3.1`) using the per-release procedure.
2. Annotate the broken release:

```bash
gh release edit v0.3.0 --notes "$(cat <<'EOF'
> ⚠️ **WITHDRAWN** — see [v0.3.1](https://github.com/kusaridev/kusari-skills/releases/tag/v0.3.1) for the corrected release.
> Reason: <brief description>.

<PASTE ORIGINAL RELEASE BODY HERE>
EOF
)"
```

The superseding release naturally becomes "Latest" on GitHub, so no further action is needed for default subscribers.

### No fix yet: emergency exclusion

After annotating (above), demote the withdrawn release so default-install skips it:

```bash
gh release edit v0.3.0 --prerelease
```

Cut the superseding release as soon as the fix is ready.

### Security-motivated withdrawal

Additionally, publish a GitHub Security Advisory:

```bash
gh api repos/kusaridev/kusari-skills/security-advisories \
  -X POST \
  -f summary="<short description>" \
  -f description="<detailed description>" \
  -F severity="<LOW|MODERATE|HIGH|CRITICAL>" \
  -F vulnerabilities[]='{"package":{"ecosystem":"other","name":"kusaridev/kusari-skills"},"vulnerable_version_range":"= 0.3.0","patched_versions":"0.3.1"}'
```

Then update the withdrawal banner to include the GHSA identifier.

## Partial workflow failure

If the workflow fails after the tag was signed in Sigstore but before `gh release create`:

1. Sigstore entries are append-only and cannot be retracted.
2. **Do not re-tag** the same version (FR-001).
3. Investigate the workflow logs; fix the underlying cause.
4. Cut a new patch release (`v0.3.1`). The aborted `v0.3.0` has a Sigstore entry but no GitHub Release — harmless.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `release-validate.yml` fails with "E3" | `bump-release.sh` wasn't run | Run it and commit |
| `release-validate.yml` fails with "E7" | Non-release changes on the PR branch | Split into separate PR |
| `release.yml` fails at audit step | Compliance regression | Fix finding first, then re-release |
| `release.yml` fails at signing | Sigstore outage | Check status.sigstore.dev; retry with new patch version |
| Tag push rejected | Not in `release-maintainers` team | Coordinate with a team member |

## Extension points

The release workflow (`.github/workflows/release.yml`) defines four named extension points where you can add new steps without modifying existing ones. Each extension point is a comment-bracketed region in the YAML.

### How to add a step

1. Open `.github/workflows/release.yml`.
2. Find the extension point you want (e.g., `# === EXTENSION POINT: post-publish ===`).
3. Add your step(s) between the `EXTENSION POINT` and `END EXTENSION POINT` comments.
4. Ensure your step checks its own preconditions (the workflow does not re-validate state for extension steps).
5. Open a PR. The existing steps remain untouched.

### Available extension points

| Extension point | Position | State available | Failure implications |
|----------------|----------|-----------------|---------------------|
| **pre-release** | Before checkout | None (checkout hasn't happened) | Safe: nothing has been produced yet. Failure aborts the workflow cleanly. |
| **post-version-bump** | After invariant validation passes | `steps.version.outputs.tag` and `.bare` are set; all invariants have passed | Safe: no artifacts produced yet. Failure aborts before SBOM/signing. |
| **post-release-marker** | After signature + provenance are issued, before GitHub Release is created | `openssf-baseline.json`, `*.sig`, `*.intoto.jsonl` exist on disk. Sigstore transparency log entries are **append-only** and cannot be retracted. | **Partial state**: Sigstore entries exist but no GitHub Release. Recovery: do NOT re-tag; cut a new patch version instead. |
| **post-publish** | After `gh release create` succeeds (or after dry-run artifact upload) | Everything above + the published release URL (in `${{ steps.version.outputs.tag }}`) | The release is live. Extension failures here are non-fatal to the release itself — the artifact is already published. Handle failures by re-running the extension step out-of-band if idempotent. |

### Example: announce to Slack at post-publish

```yaml
# === EXTENSION POINT: post-publish ===
- name: Notify Slack
  if: inputs.dry_run != 'true'
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_RELEASE_WEBHOOK }}
  run: |
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      -d "{\"text\": \"Released ${{ steps.version.outputs.tag }} — https://github.com/kusaridev/kusari-skills/releases/tag/${{ steps.version.outputs.tag }}\"}"
# === END EXTENSION POINT ===
```

### Rules

- **One region per point**: add your steps inside the existing comment brackets; do not create new extension points.
- **No reordering**: the four points are in pipeline order and cannot be moved.
- **Fail-fast**: a failing extension step halts the workflow (unless you add `continue-on-error: true` — which you should only do for truly optional steps like notifications).
- **Respect partial state**: steps in `post-release-marker` run after Sigstore entries are published. If your step fails there, the signature exists but the GitHub Release does not — see the "Partial workflow failure" section above for recovery.

## CHANGELOG authoring conventions

The CHANGELOG at `plugins/kusari/CHANGELOG.md` follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). The release process parses this format to produce release notes.

### Structure

- `## Unreleased` is always the first version section. Put new entries here during development.
- Version headings use `## <version> — <YYYY-MM-DD>` (em-dash separator, unprefixed SemVer).
- Allowed category subsections: `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Deprecated`, `### Security`. Only include categories that have entries.
- Entries are `-` prefixed bullets.

### Required-action call-outs

When a change requires consumer action (new prerequisite, removed feature, behavior change), lead the entry with `**Requires action:**`:

```markdown
### Changed
- **Requires action:** Minimum Kusari CLI version is now 0.22.0 (was 0.21.0).
```

### Security category

Use `### Security` for vulnerability fixes (reference the CVE/GHSA), new security controls, or changes to trust boundaries.

### What happens at release time

`scripts/release/bump-release.sh <version>` renames `## Unreleased` to `## <version> — <today>` and inserts a new empty `## Unreleased`. The graduated section becomes the release notes on the GitHub Release page.
