# Phase 1 Data Model: Release Process

**Feature**: 006-release-process
**Date**: 2026-04-15

This document models the entities the release process manipulates or produces. These are not runtime database entities — they are manifest structures, file contents, and published metadata whose shape and invariants the release process must preserve. The scripts and workflows in the plan operate over these structures.

---

## Entity: Version

A canonical identifier for a released snapshot.

**Fields**:

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `major` | non-negative integer | yes | `^\d+$` |
| `minor` | non-negative integer | yes | `^\d+$` |
| `patch` | non-negative integer | yes | `^\d+$` |
| `prerelease` | string | no | SemVer 2.0.0 pre-release identifier (e.g., `rc.1`, `beta.2`); empty if this is a stable release |
| `build_metadata` | string | no | SemVer 2.0.0 build metadata; not currently produced by this pipeline (reserved for future extension) |

**Canonical string form**: `v<major>.<minor>.<patch>[-<prerelease>]` — for example, `v0.3.0`, `v0.3.0-rc.1`.

**Invariants**:
- The canonical string form is used as the git tag name and as the `source.ref` value in `marketplace.json`.
- The leading `v` prefix is mandatory for tags (matches FR-019's release-tag pattern `v*.*.*`) but absent from the value of the `version` field in `plugins/kusari/.claude-plugin/plugin.json` (which stores `0.3.0`, per SemVer data-level conventions).
- This two-form convention (`v`-prefixed tag, unprefixed manifest field) is what `validate-release.sh` enforces — they must agree on the numeric components.

**State**: immutable once published. Creating a new Version requires a new tag.

---

## Entity: Release

A named, immutable snapshot of the plugin at a point in time.

**Fields**:

| Field | Type | Required | Provenance |
|-------|------|----------|------------|
| `version` | Version | yes | Matches the tag name and `plugin.json.version` (with the `v` convention above). |
| `release_date` | ISO 8601 date (UTC) | yes | The date the workflow publishes the release — recorded as the release entry's creation timestamp and as the CHANGELOG entry's date heading. |
| `source_commit` | git commit SHA (40 hex) | yes | The commit the release tag points at. |
| `source_tree_hash` | git tree SHA | yes | Tree hash of `plugins/kusari/` at `source_commit`. Included in the SLSA provenance subjects. |
| `release_notes` | string (markdown) | yes | Extracted from the matching CHANGELOG entry by `render-release-notes.sh`. |
| `signature` | Sigstore keyless signature over the tag object | yes | Produced by `cosign sign` via the workflow OIDC identity. Published in the Sigstore transparency log. |
| `provenance` | SLSA v1.0 attestation (in-toto statement) | yes | Produced by `slsa-github-generator`. Attached to the release as `.intoto.jsonl`. Covers the source tree hash, SBOM file, and audit report. |
| `sbom` | SPDX 2.3 JSON document | yes | `sbom.spdx.json`. Attached as a release asset. Covered by the provenance. Scope: file inventory of `plugins/kusari/` + `HAS_PREREQUISITE` Relationships to external packages enumerated in the Prerequisites declaration. External prerequisites are represented as Packages with `filesAnalyzed: false` and `purl`-based identification (FR-025). |
| `baseline_audit` | darnit audit JSON | yes | `openssf-baseline.json`. Attached as a release asset. Covered by the provenance. |
| `status` | enum | yes | `current`, `superseded`, `withdrawn` — see State transitions below |
| `superseded_by` | Version | conditional | Required when `status ∈ {superseded, withdrawn}`; references the version that replaces this one. |
| `advisory` | GHSA identifier (e.g., `GHSA-xxxx-yyyy-zzzz`) | conditional | Required when `status = withdrawn` AND the withdrawal is security-motivated. |
| `prerelease_flag` | boolean | yes | True iff `version.prerelease` is non-empty OR the release has been demoted for withdrawal purposes. Controls whether the release is excluded from default-install resolution. |

**Invariants** (all enforced by `validate-release.sh` or by workflow logic; together they implement FR-020):
1. `version` ↔ tag name ↔ `plugin.json.version` ↔ `marketplace.json.plugins[0].source.ref` ↔ top-most CHANGELOG heading must all agree. Disagreement is a release-time error (FR-005).
2. `source_commit` is the commit that also (re)writes `marketplace.json.plugins[0].source.ref` to `version`'s canonical string form (FR-022 — self-consistent tagged state).
3. Once published: `version`, `source_commit`, `source_tree_hash`, `signature`, `provenance`, `sbom`, `baseline_audit`, and `release_notes` are immutable. The only fields that may change post-publication are `status`, `superseded_by`, `advisory`, and `prerelease_flag`, and only in the ways documented under State transitions (FR-020c).

### State transitions

```text
[ being-cut ] --workflow succeeds--> [ current ]

[ current ] --next release cut with higher version--> [ superseded ]
           \                                         (no metadata change beyond conceptual; consumers see new current)
            \
             --workflow on a later commit identifies this release as broken--> [ withdrawn ]
                                                              ↑
                                                              |
                                                              +-- entered by: edit release body to add WITHDRAWN banner
                                                                            + set superseded_by
                                                                            + if security: create GHSA, set advisory
                                                                            + if no superseding release yet: set prerelease_flag=true
```

Notes:
- The distinction between `superseded` and `current` is implicit — GitHub's "Latest release" badge naturally reflects "highest non-prerelease published release." There is no explicit mutation on the superseded release when a new release lands; its `status` goes from `current` to `superseded` by virtue of a newer one existing.
- `withdrawn` is the only state reachable by an explicit maintainer action against an already-published release.
- A `withdrawn` release cannot transition back to `current` or `superseded`. A fixed replacement is always a *new* release.

---

## Entity: Changelog entry

A per-version record of what changed, human-written.

**Location**: `plugins/kusari/CHANGELOG.md`.

**Structure** (the subset that the release process depends on — satisfies FR-004, FR-011):

```markdown
# Changelog

## Unreleased

### Added
- <description>

### Fixed
- <description>

## 0.3.0 — 2026-04-20

### Added
- <description>

### Security
- <description>

## 0.2.0 — 2026-04-08
...
```

**Fields** (per version section):

| Field | Type | Required | Source |
|-------|------|----------|--------|
| `heading` | `## <version> — <date>` | yes | Matches `plugin.json.version` and the release date (written by `bump-release.sh`) |
| `sections` | map: {Added, Changed, Fixed, Removed, Security, Deprecated} → list of bullets | at least one section non-empty | Human-authored during development; graduated from `Unreleased` on bump |

**Invariants**:
- The `Unreleased` section at the top is the staging area for FR-011's "unreleased changes" concept. It may be empty.
- The version headings below `Unreleased` are strictly decreasing (newest first).
- Version headings use `—` (em-dash, U+2014) as the separator, matching the existing file's convention. `render-release-notes.sh` tolerates both em-dash and double-hyphen for robustness but writes em-dash on bump.
- For a release at version V, `CHANGELOG.md` MUST contain exactly one heading starting with `## <V>` (the `v` prefix is *not* used in the CHANGELOG; the file stores data-form versions like `0.3.0`).

### Bump transition

`bump-release.sh <new-version>` performs:
1. Rename `## Unreleased` to `## <new-version> — <today>` (UTC date).
2. Insert a new empty `## Unreleased` block at the top (with no subsections).
3. Emit nothing to stdout; modify the file in place; leave for the maintainer to review before committing.

This makes graduating Unreleased content to a released version section a mechanical, scriptable step — no semantic interpretation required.

---

## Entity: Extension point

A named stage in the release workflow where contributors may add steps.

**Realization**: comment-bracketed regions in `.github/workflows/release.yml`:

```yaml
# === EXTENSION POINT: pre-release ===
# (add steps here to run before any release-process work begins)
# === END EXTENSION POINT ===
```

**Canonical set of points** (FR-007 minimum):

| Name | Position in workflow | Invariant |
|------|----------------------|-----------|
| `pre-release` | After checkout, before version parsing | Runs for every tag push, including for tags that will later fail validation |
| `post-version-bump` | After `validate-release.sh` succeeds | Version is known and all invariants are validated |
| `post-release-marker` | After `slsa-github-generator` succeeds (signature + provenance exist) | Signature and provenance have been produced but the GitHub Release entry has not been created yet |
| `post-publish` | After `gh release create` succeeds | The release is fully published to the outside world |

**Invariants**:
- Adding a step in an extension point MUST NOT require modifying any line outside that point's comment-bracketed region (otherwise FR-007 is violated).
- A failed step inside an extension point MUST cause the workflow to halt and surface which step failed and what state has already been applied — i.e., if a step in `post-release-marker` fails, the release entry is not created, but the signature and provenance have been published to Sigstore and cannot be rescinded (see the Sigstore transparency-log append-only property). The runbook (`docs/RELEASING.md`) documents this partial-state possibility and the recovery procedure.

---

## Entity: Marketplace manifest (the release-relevant slice)

**Location**: `.claude-plugin/marketplace.json`.

The release process reads and writes exactly one field of this file:

**Path**: `$.plugins[?(@.name == "kusari")].source`

**Before first release** (current state):
```json
"source": "./plugins/kusari"
```

**After release vN** (FR-022 post-state):
```json
"source": {
  "source": "github",
  "repo": "kusaridev/kusari-skills",
  "ref": "v<N>",
  "path": "plugins/kusari"
}
```

Optionally (content-addressed hardening, §6 of research.md):
```json
"source": {
  "source": "github",
  "repo": "kusaridev/kusari-skills",
  "ref": "v<N>",
  "sha": "<40-hex commit SHA>",
  "path": "plugins/kusari"
}
```

**Invariants**:
- All fields other than `plugins[0].source` in `marketplace.json` MUST NOT be touched by the release process; they are the marketplace's own metadata (name, owner, metadata.version) and have an independent change cadence.
- Rewriting is idempotent: running the rewrite twice for the same target version produces the same file.
- `bump-release.sh` performs this rewrite as part of its atomic operation (plugin.json + CHANGELOG + marketplace.json updated in a single staging action).

---

## Entity: Release-bump commit

A single commit containing the three coordinated edits a release requires.

**Location**: lives on `main` (eventually); may first appear on a release-bump PR branch.

**Required changes in exactly one commit**:
1. `plugins/kusari/.claude-plugin/plugin.json` — `version` field advanced to the new version.
2. `plugins/kusari/CHANGELOG.md` — `## Unreleased` renamed to `## <new-version> — <date>` and a new empty `## Unreleased` inserted.
3. `.claude-plugin/marketplace.json` — plugin source rewritten to the pinned-ref form for the new version.

**Invariants**:
- These three edits MUST land together. `validate-release.sh` rejects tag pushes whose tagged commit violates this (e.g., plugin.json advanced but CHANGELOG still says `Unreleased`).
- The commit message SHOULD be `Release v<new-version>` (used for human signal only; not parsed).
- This commit is the one the release tag will point at. The tag name is the `v`-prefixed canonical form of the new version.

---

## Entity: Prerequisites declaration

A canonical, declarative enumeration of the external runtime tools the plugin requires. Single source of truth consumed by the install-time prerequisites check and by the SBOM generator.

**Location**: `plugins/kusari/prerequisites.json`.

**Fields**:

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `tools` | array of Tool | yes | Non-empty; each Tool distinct by `name` |
| `tools[].name` | string | yes | Command/binary name used by `command -v` at install-time check and in human messages |
| `tools[].minVersion` | SemVer string or `null` | yes | Minimum accepted version; `null` means any version is acceptable |
| `tools[].versionCommand` | string or `null` | no | Command (with args) to print the installed version; defaults to `<name> --version` |
| `tools[].purl` | Package URL string | yes | Identifies the tool's canonical external source in purl format (e.g., `pkg:github/kusaridev/kusari-cli`, `pkg:generic/jq`) |
| `tools[].downloadLocation` | URL | yes | Human-accessible page where the tool can be obtained; surfaced in the prereq-check failure message and used as SPDX `downloadLocation` |
| `tools[].purpose` | string | yes | One-sentence human-readable description of why the plugin needs this tool; surfaced in the SBOM and in docs |

**Invariants**:
- Every tool the plugin invokes at runtime MUST have an entry. New shell-script dependencies (e.g., adding a `jq` call where none existed) MUST be accompanied by an entry here. The install-time check is the enforcement mechanism: a plugin that invokes a tool without declaring it will fail for any user who doesn't already have that tool installed.
- Entries are additive and never removed silently — if a prerequisite stops being needed, it is removed from the file as part of the same change that removes its use from the plugin code.
- `name`, `purl`, and `downloadLocation` together identify the prerequisite unambiguously; two entries MUST NOT share a `name`.
- The file is valid JSON, 2-space-indented, with a trailing newline (matching the existing JSON-file style in the repo).

### Consumer: `hooks/check-prerequisites.sh`

Reads `prerequisites.json` and, for each tool:
1. `command -v <name>` — fails with a message pointing at `downloadLocation` if not found.
2. If `minVersion` is non-null: parse the output of `versionCommand` (or `<name> --version`) and compare SemVer-wise; fail with a clear message if too old.
3. If all tools pass, the hook exits 0 and the plugin is installable.

### Consumer: `scripts/release/generate-sbom.sh` (SBOM prerequisite relationships)

Reads `prerequisites.json` and, for each tool, emits one SPDX Package and one Relationship:

```json
{
  "SPDXID": "SPDXRef-Prereq-kusari",
  "name": "kusari",
  "downloadLocation": "https://github.com/kusaridev/kusari-cli/releases",
  "filesAnalyzed": false,
  "externalRefs": [
    {
      "referenceCategory": "PACKAGE-MANAGER",
      "referenceType": "purl",
      "referenceLocator": "pkg:github/kusaridev/kusari-cli"
    }
  ],
  "versionInfo": ">= 0.21.0",
  "comment": "SARIF scanning CLI and MCP server source (from prerequisites.json)"
}
```

Plus:

```json
{
  "spdxElementId": "SPDXRef-Package-kusari-plugin",
  "relationshipType": "HAS_PREREQUISITE",
  "relatedSpdxElement": "SPDXRef-Prereq-kusari"
}
```

The generator also reads `plugins/kusari/.mcp.json` and emits HAS_PREREQUISITE entries for each MCP server `command` not already covered by `prerequisites.json` (this handles the overlap case where an MCP server command IS one of the declared tools).

---

## Entity: Release assets (published artifacts)

**Location**: attached to the GitHub Release entry for the version.

| Asset filename | Content | Produced by |
|----------------|---------|-------------|
| `sbom.spdx.json` | SPDX 2.3 JSON SBOM of `plugins/kusari/` at `source_commit` | `scripts/release/generate-sbom.sh` (wrapper around `syft`) |
| `openssf-baseline.json` | darnit audit report at `source_commit` | `darnit audit` invocation inside the workflow |
| `<version>.intoto.jsonl` | SLSA v1.0 provenance attestation (in-toto bundle), covering the source tree hash, SBOM, and audit report | `slsa-github-generator` reusable workflow |
| `<version>.sig` | Sigstore signature over the release tag object (if produced separately from the attestation bundle) | `cosign sign` |

**Invariants**:
- All assets MUST be uploaded in the same workflow run that creates the release entry (FR-020: no post-hoc replacement).
- The set of `subject` hashes in the provenance MUST include the file hashes of `sbom.spdx.json` and `openssf-baseline.json`, not just the source tree hash, so the provenance covers the audit/SBOM as well as the source.
- If any asset fails to upload, the workflow aborts and the release entry is not created. (FR-005.)

---

## Cross-entity invariant summary

For a release at version `v<N>` to be well-formed, all of the following must hold simultaneously at the tagged commit:

1. `plugin.json.version == "<N>"` (numeric part only; no `v` prefix)
2. `CHANGELOG.md` has exactly one heading `## <N> — <date>` immediately below an (optionally empty) `## Unreleased` section
3. `marketplace.json.plugins[0].source.ref == "v<N>"`
4. The git tag `v<N>` points at this commit
5. The source tree hash of `plugins/kusari/` at this commit is what appears as a SLSA `subject`
6. SBOM, audit report, provenance, and signature are all produced in the release workflow run and attached as release assets

If any of 1–3 fail, `validate-release.sh` rejects the release pre-publication.
If 4 fails, the release workflow doesn't trigger (it's triggered on tag push).
If 5 or 6 fail, the workflow's internal steps abort before `gh release create`.
