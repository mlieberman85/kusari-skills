# Contract: Release Artifact Shape

**Purpose**: Define exactly what a consumer sees when looking at a published release — the files attached, their content expectations, and the verification procedure. This is the surface the spec's FR-014 through FR-025 converge on and the surface downstream verification tooling reads against.

## Per-release artifact manifest

For a release at version `v<N>`, the GitHub Release entry at `https://github.com/kusaridev/kusari-skills/releases/tag/v<N>` MUST contain:

| Element | Required | Content |
|---------|----------|---------|
| Tag `v<N>` | yes | Signed by the release workflow OIDC identity via Sigstore. Points at the release-bump commit. |
| Release title | yes | Exactly `v<N>` (the canonical tag form). |
| Release body | yes | The markdown-formatted CHANGELOG section for `<N>`, as emitted by `render-release-notes.sh`. |
| Prerelease flag | yes | `true` iff `<N>` has a SemVer pre-release qualifier OR the release is in `withdrawn` status (per FR-012 default-install exclusion). |
| Asset: `sbom.spdx.json` | yes | SPDX 2.3 JSON SBOM scoped to `plugins/kusari/` at the release commit. |
| Asset: `openssf-baseline.json` | yes | darnit OpenSSF Baseline audit result at the release commit, in darnit's native JSON form. |
| Asset: `<N>.intoto.jsonl` | yes | In-toto attestation bundle produced by slsa-github-generator (SLSA v1.0 Build L3 provenance). Covers the source tree hash, the SBOM file hash, and the audit report file hash as subjects. |
| Asset: `<N>.sig` | conditional | Separate Sigstore signature over the tag object, if produced out-of-band from the attestation bundle. If the signing is fully bundled inside the `.intoto.jsonl`, this file MAY be omitted. |

### SBOM content expectations

`sbom.spdx.json` — SPDX 2.3 JSON, conforming to https://spdx.github.io/spdx-spec/v2.3/ . The SBOM's scope is the plugin's distribution scope (Mode 3 reference-only — see research.md §12); it enumerates what is *contained* in the release and what is *required* by it as distinct concerns.

Minimum required fields:

- `spdxVersion: "SPDX-2.3"`
- `creationInfo.creators` includes `"Tool: syft-<version>"` and `"Organization: Kusari"`
- `creationInfo.comment` explicitly documents scope: `"SBOM scope = distribution scope. The plugin's contained files are enumerated as the primary Package. External runtime tools required by the plugin are declared via HAS_PREREQUISITE Relationships to separate Packages marked filesAnalyzed=false; these are not contained in the release."`
- `documentNamespace` includes the release tag name for disambiguation across releases
- `packages[]` contains:
  - **One primary Package** for the plugin itself, `SPDXRef-Package-kusari-plugin`, with resolvable `downloadLocation` (`git+https://github.com/kusaridev/kusari-skills@v<N>#plugins/kusari`), checksums, `filesAnalyzed: true`, and a `hasFiles` list referencing every file SPDX ID under `plugins/kusari/`.
  - **One Package per declared prerequisite** (from `plugins/kusari/prerequisites.json` — see `prerequisites-declaration.md`), each with:
    - `SPDXRef-Prereq-<name>` identifier
    - `filesAnalyzed: false`
    - `downloadLocation` from the prerequisite declaration
    - `externalRefs[]` containing a single entry with `referenceCategory: "PACKAGE-MANAGER"`, `referenceType: "purl"`, and `referenceLocator` from the prerequisite's `purl`
    - `versionInfo` containing the declared `minVersion` as `">= <version>"` (or `"any"` if `minVersion` is null)
    - `comment` set to the prerequisite's `purpose` field
- `files[]` enumerates every file under `plugins/kusari/` with SHA-256 and SHA-1 checksums
- `relationships[]` contains:
  - A `DESCRIBES` relationship from the SBOM document to `SPDXRef-Package-kusari-plugin`
  - One `HAS_PREREQUISITE` relationship from `SPDXRef-Package-kusari-plugin` to each `SPDXRef-Prereq-<name>`

The SBOM MUST NOT use `CONTAINS`, `STATIC_LINK`, `DYNAMIC_LINK`, or other bundling/linking relationships between the plugin and any prerequisite Package. The only admissible relationship to a prerequisite is `HAS_PREREQUISITE`.

#### Example relationship block

```json
"relationships": [
  {
    "spdxElementId": "SPDXRef-DOCUMENT",
    "relatedSpdxElement": "SPDXRef-Package-kusari-plugin",
    "relationshipType": "DESCRIBES"
  },
  {
    "spdxElementId": "SPDXRef-Package-kusari-plugin",
    "relatedSpdxElement": "SPDXRef-Prereq-kusari",
    "relationshipType": "HAS_PREREQUISITE"
  },
  {
    "spdxElementId": "SPDXRef-Package-kusari-plugin",
    "relatedSpdxElement": "SPDXRef-Prereq-jq",
    "relationshipType": "HAS_PREREQUISITE"
  }
]
```

### Audit content expectations

`openssf-baseline.json` — structure defined by darnit; the release process does not reshape it. The release workflow asserts two properties on this file before proceeding:

1. No control is in `FAIL` status that was in `PASS` at the immediately prior release (regression gate).
2. No new finding at severity `HIGH` or `CRITICAL` exists compared to the prior release.

If darnit produces a narrative summary field (e.g., `summary` or `status`), the workflow logs that field to the run output for human review.

### Provenance content expectations

`<N>.intoto.jsonl` — one or more in-toto statements in DSSE envelopes. The payload MUST include:

- `_type: "https://in-toto.io/Statement/v1"`
- `subject[]` containing a distinct entry for each of:
  - The plugin subtree (named `pkg:github/kusaridev/kusari-skills@v<N>#plugins/kusari`) with its SHA-256 over the tree hash
  - `sbom.spdx.json` with its SHA-256
  - `openssf-baseline.json` with its SHA-256
- `predicateType: "https://slsa.dev/provenance/v1"`
- `predicate.buildDefinition.buildType` referencing the slsa-github-generator builder
- `predicate.runDetails.builder.id` pointing to the specific reusable-workflow ref that built this release
- `predicate.runDetails.metadata.invocationId` equal to the GitHub Actions run URL

## Consumer verification procedure

A consumer who wants to verify that `v<N>` was produced by the canonical pipeline follows this procedure:

```bash
# 1. Fetch the release assets
gh release download v0.3.0 --repo kusaridev/kusari-skills

# 2. Verify the provenance against the tag
slsa-verifier verify-artifact \
  --provenance-path v0.3.0.intoto.jsonl \
  --source-uri github.com/kusaridev/kusari-skills \
  --source-tag v0.3.0 \
  sbom.spdx.json openssf-baseline.json

# 3. Verify the tag signature (independent of provenance)
cosign verify-blob-attestation \
  --certificate-identity "https://github.com/kusaridev/kusari-skills/.github/workflows/release.yml@refs/tags/v0.3.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --bundle v0.3.0.sig \
  <(git cat-file -p v0.3.0)
```

This procedure uses only publicly known information (repo URL, tag name, OIDC issuer URL) — satisfying FR-016's "no publisher-only credential needed to verify."

## Non-goals of this contract

- The release does NOT produce a pre-built tarball or zip — installation is source-at-tag (FR-021). Adding a tarball asset is an FR-007 extension-point change, not a baseline change.
- The release does NOT produce a container image. Ditto.
- The release does NOT publish to an external registry (npm, PyPI, etc.). Ditto.

## Post-publication mutability

| Field | Mutable after publication? | Reason |
|-------|----------------------------|--------|
| Tag (`v<N>`) and commit it points at | NO (FR-020a) | Tag protection + append-only provenance make this impossible in practice |
| Release title | NO (FR-020c implicitly; no documented reason to change) | — |
| Release body — general | NO (FR-020c) | Would invalidate the historical record of what was released |
| Release body — WITHDRAWN banner append | YES (FR-012, FR-020c exception) | Only permitted mutation; banner prepended, original text preserved |
| Prerelease flag | YES (for withdrawal demote) | Distribution-status signal, not content; changing it does not invalidate signature/provenance because those cover artifact content, not GitHub metadata |
| Attached assets | NO (FR-020b) | Replacing an asset would invalidate the provenance subjects |
| Signature | NO (FR-020b) | Append-only transparency log |
| Provenance | NO (FR-020b) | Append-only transparency log |
