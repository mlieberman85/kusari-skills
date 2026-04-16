# Quickstart: Cutting a Release

**Feature**: 006-release-process
**Audience**: A maintainer cutting a release for the first time.
**Goal**: A signed, provenance-attested, SBOM-accompanied GitHub Release for version `v<N>`, with `marketplace.json` advanced so default-install consumers see the new version.

This is the runbook form of the release process — the detailed, step-by-step procedure. The authoritative documentation in-repo will live at `docs/RELEASING.md` once implementation is complete; this file is the reference version used to author it.

---

## Before you begin (one-time setup)

These are performed once, by a repo admin, before the first release is cut. They are out-of-scope for the per-release procedure but are preconditions.

1. **Tag protection rule**: configure a rule on `kusaridev/kusari-skills` that restricts push permission on tags matching `v*` to the `release-maintainers` team. (Settings → Rules → Rulesets → Tag rule.)
2. **Branch protection on `main`**: already in place (per Constitution §II and existing practice); no changes needed.
3. **`release-maintainers` team**: add the humans authorized to cut releases. Initially: the repo admin. 2FA is required for team membership.
4. **Dependabot** (recommended): configure Dependabot to propose SHA bumps for actions referenced by `.github/workflows/release.yml`. PRs go through normal review.
5. **Sigstore public-good** (no setup): the workflow uses the public-good Sigstore instance via the GitHub Actions OIDC token. No credential configuration needed.

---

## Per-release procedure

### Step 1 — Confirm readiness

```bash
# On main, up-to-date
git checkout main && git pull

# Confirm the Unreleased section reflects what you intend to ship
cat plugins/kusari/CHANGELOG.md | sed -n '/^## Unreleased/,/^## /p' | head -n -1
```

Review the `## Unreleased` section. Every bullet there is about to become part of the release notes consumers will read. If something isn't ready, remove the bullet (and ideally revert or gate the change it refers to) before proceeding.

Choose the target version per SemVer:
- **patch** (e.g., `0.2.0` → `0.2.1`) — fixes only, no behavior or interface changes.
- **minor** (e.g., `0.2.0` → `0.3.0`) — new capabilities, no breaking changes.
- **major** (e.g., `0.x.y` → `1.0.0`) — breaking changes, or the first stable release.
- **prerelease** (e.g., `0.3.0-rc.1`) — a release candidate for validation before the stable release of the same version.

### Step 2 — Open a release-bump PR

```bash
git checkout -b release/v0.3.0

# Apply the three coordinated edits via the helper:
bash scripts/release/bump-release.sh 0.3.0

# Review what changed
git diff

# Commit
git add plugins/kusari/.claude-plugin/plugin.json \
        plugins/kusari/CHANGELOG.md \
        .claude-plugin/marketplace.json
git commit -m "Release v0.3.0"

# Push and open a PR
git push -u origin release/v0.3.0
gh pr create --title "Release v0.3.0" --body "$(cat <<'EOF'
## Summary
Release v0.3.0 — see CHANGELOG.md for details.

## Test plan
- [ ] `release-validate.yml` workflow passes on this PR
- [ ] CHANGELOG section reviewed for accuracy and upgrade-action call-outs
EOF
)"
```

The `release-validate.yml` workflow runs automatically on this PR and invokes `validate-release.sh v0.3.0 --from <PR-head-sha>`. If any invariant fails, fix it and push again.

### Step 3 — Get the PR reviewed and merged

Standard review process. Merge into `main` when approved.

### Step 4 — Tag and push

```bash
git checkout main && git pull

# The release-bump commit is now HEAD. Tag it:
git tag v0.3.0

# Push the tag. This triggers .github/workflows/release.yml.
git push origin v0.3.0
```

At this point your involvement pauses. The workflow will:
1. Re-validate invariants against the tagged commit.
2. Generate the SBOM.
3. Run the OpenSSF Baseline audit.
4. Produce the SLSA provenance via the slsa-github-generator reusable workflow.
5. Sign the tag via Sigstore keyless signing.
6. Create the GitHub Release with the notes body, prerelease flag, and all assets attached.

Expected runtime: under 15 minutes (per SC-001).

### Step 5 — Verify

Once the workflow completes:

```bash
# Fetch the release assets
gh release view v0.3.0 --repo kusaridev/kusari-skills
gh release download v0.3.0 --repo kusaridev/kusari-skills

# Verify the provenance
slsa-verifier verify-artifact \
  --provenance-path v0.3.0.intoto.jsonl \
  --source-uri github.com/kusaridev/kusari-skills \
  --source-tag v0.3.0 \
  sbom.spdx.json openssf-baseline.json

# Verify the tag signature
cosign verify-blob-attestation \
  --certificate-identity "https://github.com/kusaridev/kusari-skills/.github/workflows/release.yml@refs/tags/v0.3.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --bundle v0.3.0.sig \
  <(git cat-file -p v0.3.0)
```

Both verifications must succeed. If either fails, treat the release as broken and proceed to the withdrawal runbook below.

### Step 6 — Announce (optional, recommended)

The release entry is public. Announce in any channels appropriate for the project (Slack, discussion thread, blog post).

---

## Scenario: Prerelease / release candidate

Follow the same procedure with a prerelease version identifier:

```bash
bash scripts/release/bump-release.sh 0.3.0-rc.1
# ... PR, merge, tag ...
git tag v0.3.0-rc.1
git push origin v0.3.0-rc.1
```

The workflow detects the SemVer prerelease qualifier and sets the GitHub Release `prerelease` flag automatically (FR-013). Default-install consumers (who don't pin) will NOT resolve to this version; only consumers who explicitly pin to `@v0.3.0-rc.1` will see it.

When the candidate is validated, cut the corresponding stable release (`v0.3.0`) — it is a distinct release and gets its own tag, its own CHANGELOG entry (typically with the same changes), and its own artifacts.

---

## Scenario: Withdraw a broken release

When a published release is identified as broken or compromised:

### If the fix already exists

Cut a new patch release (e.g., `v0.3.1` superseding `v0.3.0`) using the per-release procedure. Then annotate the broken release:

```bash
gh release edit v0.3.0 --notes "$(cat <<'EOF'
> ⚠️ **WITHDRAWN** — see [v0.3.1](https://github.com/kusaridev/kusari-skills/releases/tag/v0.3.1) for the corrected release.
> Reason: <brief description>.

<ORIGINAL RELEASE BODY>
EOF
)"
```

Paste the original release body under the banner. Do not delete or modify the original notes below the banner — post-publication immutability (FR-020c) allows only prepending a withdrawal notice.

Cutting `v0.3.1` naturally moves `v0.3.0` out of default-install resolution (GitHub's "latest" is the highest non-prerelease version), so no further action is needed for default subscribers.

### If no fix is available yet but the release must be withdrawn immediately

After annotating as above, demote the withdrawn release to prerelease status so default-install resolution skips it:

```bash
gh release edit v0.3.0 --prerelease
```

This does not modify the release content, the signature, or the provenance — it modifies the GitHub distribution metadata. Consumers subscribed without a pinned ref will skip it on their next `/plugin marketplace update`.

Then, as soon as a fix is ready, cut the superseding release (e.g., `v0.3.1`) per the per-release procedure.

### If the withdrawal is security-motivated

Additionally, publish a GitHub Security Advisory:

```bash
gh api repos/kusaridev/kusari-skills/security-advisories \
  -X POST \
  -f summary="<short description>" \
  -f description="<detailed description including affected versions, impact, mitigation>" \
  -F severity="<LOW|MODERATE|HIGH|CRITICAL>" \
  -F vulnerabilities[]='{"package":{"ecosystem":"other","name":"kusaridev/kusari-skills"},"vulnerable_version_range":"= 0.3.0","patched_versions":"0.3.1"}'
```

Fill in the affected version range and patched version as appropriate. The advisory appears in GitHub's advisory database and is consumed by downstream tooling (Dependabot, Renovate) as a machine-readable revocation signal (FR-017).

After publishing the GHSA, edit the withdrawn release's body banner to include the GHSA identifier:

```markdown
> ⚠️ **WITHDRAWN** — see [v0.3.1](...) for the corrected release.
> Security advisory: [GHSA-xxxx-yyyy-zzzz](...).
> Reason: <brief description>.
```

---

## Scenario: Release workflow partially failed

If the workflow failed after the tag was signed in Sigstore but before `gh release create` succeeded:

- The Sigstore transparency log has an entry for `v0.3.0` that cannot be retracted (append-only).
- No GitHub Release entry exists.
- The tag exists in the repo.

**Recovery**:
1. Investigate the workflow logs; identify the failing step.
2. **Do not re-run the workflow on the same tag.** The signing/provenance entries already exist in Sigstore.
3. **Do not re-tag with the same version.** FR-001 forbids identifier reuse.
4. Fix the underlying cause (common cases: a transient GitHub API outage; an action SHA needs bumping; the audit surfaced a regression that needs addressing).
5. If the cause was transient, cut a new patch release (`v0.3.1`) using the normal procedure; the aborted `v0.3.0` has a benign inconsistency (Sigstore entry without release entry) that is harmless.
6. If the cause was the audit surfacing a regression, resolve the compliance finding first (which is a change to repo state), then cut the release.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `release-validate.yml` fails on the PR with "E3: plugin.json version mismatch" | `bump-release.sh` wasn't run, or was run for a different target version | Run `bash scripts/release/bump-release.sh <target-version>` and commit the result |
| `release-validate.yml` fails with "E7: working tree has uncommitted changes" | There are changes on the PR branch beyond the three release-bump edits | Split non-release changes into a separate PR; release-bump PRs must contain only the three coordinated edits |
| `release.yml` fails at the OpenSSF Baseline audit step | A control regressed, or a new HIGH/CRITICAL finding surfaced since the previous release | Resolve the finding in a separate PR; merge to main; then re-cut the release with a new tag |
| `release.yml` fails at the slsa-github-generator step | Usually a transient Sigstore / OIDC issue | Check [Sigstore status](https://status.sigstore.dev/); if it's a transient upstream issue, wait and retry with a new tag (`v0.3.1`); otherwise file an issue |
| `gh release create` fails with an asset-upload error | GitHub API outage or asset larger than limit (unlikely for this plugin) | Check GitHub status; retry by cutting a new patch release |
| Tag push rejected: "protected tag" | You're not in the `release-maintainers` team | Coordinate with a maintainer who is |

---

## When to add a step to the release process

If you find yourself manually performing a recurring step during or around releases (e.g., "I always go update the website" or "I always remember to announce in Slack"), consider codifying it as an extension-point step in `.github/workflows/release.yml`. The canonical extension points are:

- **`pre-release`** — runs before any release-process work. Example use: cache-warming; sending a "release in progress" signal.
- **`post-version-bump`** — runs after invariant validation passes, version is known. Example use: generating per-version documentation.
- **`post-release-marker`** — runs after signature + provenance are issued but before the GitHub Release is created. Example use: cross-registry publishing where the registry should see the artifacts before the public release entry.
- **`post-publish`** — runs after the GitHub Release is live. Example use: announcements, cache invalidation, documentation site rebuilds.

Each extension point is a comment-bracketed region in `release.yml`. Adding a step means editing one region; the existing steps stay untouched (FR-007).
