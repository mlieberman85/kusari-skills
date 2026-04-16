# Phase 0 Research: Release Process

**Feature**: 006-release-process
**Date**: 2026-04-15
**Purpose**: Resolve the technology and pattern choices implied by the spec's FRs and the plan's Technical Context. Each decision captures *what*, *why*, and *what else was considered* so future maintainers (and Constitution §V agent-portability) can understand the tradeoffs without re-deriving them.

There were no `NEEDS CLARIFICATION` markers in the Technical Context; this document instead locks in the open technology choices and best-practice conventions the plan assumed.

---

## 1. Signing and provenance: Sigstore via slsa-github-generator

**Decision**: Use the official `slsa-framework/slsa-github-generator` reusable workflow (specifically `generator_generic_slsa3.yml`) to produce SLSA v1.0 Build Level 3 provenance for the release, with keyless signing bound to the workflow's OIDC identity via Sigstore's public-good instance.

**Rationale**:
- Satisfies FR-014 (signature), FR-015 (provenance issued by a scoped identity, not a workstation), and FR-016 (publicly verifiable without publisher-only credentials) in a single reusable workflow, with no long-lived secrets.
- SLSA L3 specifically requires a hardened builder — the reusable workflow is audited, runs in an isolated context, and cannot be modified by the calling workflow. That's exactly the trust property Q1 was reaching for.
- Sigstore's keyless flow binds the signature to `repo/owner/kusari-skills/.github/workflows/release.yml@refs/tags/v*` — verifiers check the identity in the transparency log entry, not a key we have to rotate.
- The workflow outputs a `.intoto.jsonl` attestation the plan can attach as a release asset; `cosign verify-attestation` or `slsa-verifier` on the consumer side is standard tooling.
- This is the path used by the PyPI, npm, and homebrew release ecosystems for SLSA adoption, so downstream tools (dependabot, scorecard) will continue to interoperate.

**Alternatives considered**:
- **Self-managed cosign with a private key stored in GitHub Secrets**: simpler to read at first but introduces key-rotation burden and reduces us from "workflow identity" to "whoever has the secret." Rejected — weaker trust claim than OIDC-bound keyless signing, and conflicts with the spirit of FR-015.
- **GitHub's native "artifact attestations"** (`actions/attest-build-provenance`): a reasonable alternative, produces in-toto attestations verifiable by `gh attestation verify`. It's simpler but attestations live inside GitHub rather than in Sigstore's public transparency log. We prefer the Sigstore path because the transparency-log-backed record is an independent, append-only audit trail that survives even if the repo or GitHub availability changes — matching the "persists independently of branch lifecycle" spirit of FR-010. Worth revisiting if GitHub's attestation layer gains transparency-log integration (it's on their roadmap).
- **In-house provenance generation** (bash + `jq` assembling an in-toto statement): high code-ownership burden, and we'd have to re-derive the SLSA requirements ourselves. Rejected — reinventing audited trust infrastructure is exactly what Constitution §III warns against.

**References**:
- [slsa-github-generator generic generator](https://github.com/slsa-framework/slsa-github-generator/blob/main/internal/builders/generic/README.md)
- [SLSA v1.0 Build Level 3 requirements](https://slsa.dev/spec/v1.0/levels#build-l3)

---

## 2. SBOM generation: syft file inventory + prerequisites-file-derived `HAS_PREREQUISITE` relationships; SPDX JSON

**Decision**: Generate the SBOM in two complementary phases merged into one SPDX 2.3 JSON document (`sbom.spdx.json`):

1. **File inventory** — `anchore/syft` scans `plugins/kusari/` and produces the Package entry for the plugin with full file-level hashes (SHA-256 + SHA-1, plus syft's detected file types).
2. **Prerequisite relationships** — `scripts/release/generate-sbom.sh` reads the canonical prerequisites declaration (see §12) and `plugins/kusari/.mcp.json`, and emits:
   - One SPDX Package per external prerequisite, marked `filesAnalyzed: false` and with `downloadLocation` set to the external source URL and an `externalRefs` entry of category `PACKAGE-MANAGER` holding a `purl` that identifies the prerequisite's canonical external identity.
   - One Relationship of type `HAS_PREREQUISITE` from the plugin Package to each prerequisite Package.

The merged SBOM's scope is the distributed artifact (the 11 files in the plugin subtree) plus a machine-readable declaration of what the artifact requires to function. No external tool is represented as contained.

**Rationale**:
- Matches the distribution-scope-equals-SBOM-scope principle established during clarification (see §12 for the Mode 3 framing): we ship files, we require external runtimes, the SBOM states both honestly.
- The file-inventory portion is syft-auto — zero ongoing maintenance for that half.
- The prerequisites portion derives from the same file `check-prerequisites.sh` reads. Drift is self-policing: a dev who adds a tool without declaring it in the prereqs file ships a plugin whose runtime check doesn't enforce the new requirement → users see a *discoverable* missing-tool failure (not a silent mismatch between SBOM and reality). The fix in both cases is one-file: update the prereqs declaration.
- `HAS_PREREQUISITE` chosen over `RUNTIME_DEPENDENCY_OF`: the plugin invokes the Kusari CLI via subprocess execution, not in-process linking. Traditional SPDX convention uses `RUNTIME_DEPENDENCY_OF` for same-process runtime deps (libs, plugins-of-plugins) and `HAS_PREREQUISITE` for environmental prerequisites that must exist independently (interpreters, OS packages, external CLIs). For a shells-out relationship, `HAS_PREREQUISITE` is the more precise relationship. Consumers reading the relationship graph correctly will distinguish these; consumers that conflate them will produce the same (slightly worse) result either way.
- Package-level hygiene on external prerequisites (`filesAnalyzed: false`, explicit `downloadLocation`, `purl` in `externalRefs`) signals clearly to scanners that these Packages are *references*, not *contents*. Scanners that read SPDX correctly (Grype, Trivy, most modern tools) will not try to scan them as if present in the artifact. Scanners that ignore relationships and treat every Package as present will mishandle any SBOM that declares external deps — that's a tooling-quality issue on their side we cannot fix from the publishing side, and the alternative (omitting external deps) is worse because it loses real supply-chain information.
- SPDX 2.3 JSON (ISO/IEC 5962 lineage): broadest consumer support; mature tooling.

**Alternatives considered**:
- **File inventory only** (the originally-sketched "option A"): satisfies the constitution literally but conveys no information not already in the SLSA provenance. Rejected as cargo-cult given the on-brand alternative below.
- **External prerequisites as Packages *without* explicit relationships**: misleading — by convention, an unrelated Package in an SBOM is interpreted as bundled. Rejected.
- **`RUNTIME_DEPENDENCY_OF` instead of `HAS_PREREQUISITE`**: defensible; some publishers use it for any runtime dep regardless of in-process vs. shells-out. Rejected for precision; the SBOM's `creationInfo.comment` field documents the choice.
- **Hand-authored SBOM template merged with syft output**: creates the drift problem. Rejected in favor of the prerequisites-file-as-source-of-truth approach (§12).
- **CycloneDX instead of SPDX**: close to a toss-up. Chose SPDX because ISO-standard adoption is broad and SPDX 3.0 formalizes the security profile. Adding CycloneDX emission later is a clean FR-007 extension.
- **GitHub's dependency-graph-derived SBOM**: only covers known package manifests; this plugin has none. Would produce an empty or near-empty SBOM. Rejected.

**References**:
- [SPDX 2.3 Relationship vocabulary](https://spdx.github.io/spdx-spec/v2.3/relationships-between-SPDX-elements/)
- [syft SPDX output format](https://github.com/anchore/syft?tab=readme-ov-file#output-formats)
- [purl specification](https://github.com/package-url/purl-spec)

---

## 3. OpenSSF Baseline audit: darnit (already plugin-bundled)

**Decision**: Use the `darnit` OpenSSF Baseline compliance tool already bundled with this plugin's MCP server configuration to run an audit in the release pipeline before the release is finalized. Store the audit JSON as a release asset (`openssf-baseline.json`). The workflow aborts if the audit regresses from its last-passing state or surfaces any new HIGH/CRITICAL finding.

**Rationale**:
- This is the tool the project already uses and trusts — introducing a different OpenSSF tool (e.g., allstar, scorecard) purely for release-gate purposes would create drift between "what we audit on CI" and "what we audit at release." Constitution §III wants the audit to run on a regular cadence with the release as a checkpoint; reusing the same tool in the same invocation surface is exactly that.
- Output is structured JSON (machine-consumable for the gate logic) and human-readable.
- The `darnit-audit` skill already exists in the plugin's own skill set — releases shipped by the plugin running the audit it publishes is a coherent, self-validating story.
- Recording the audit in the release assets means any future question "was the project Baseline-compliant at release time?" is auditable without rerunning anything — per FR-010 (metadata persistence).

**Alternatives considered**:
- **OpenSSF Scorecard**: broader signal, runs as a GitHub Action. Useful, but overlapping with Baseline — and Scorecard's defaults assume a library/application, not a plugin, so several of its checks are irrelevant. We may add a Scorecard step as an FR-007 extension later. Rejected as baseline-gate tool because it would fight with darnit on overlapping concerns.
- **No automated audit; manual review**: explicitly forbidden by Constitution §III ("audited on a regular cadence").

**References**:
- Existing `darnit-audit` skill in this plugin's MCP server configuration.

---

## 4. Tag and commit signing: rely on workflow OIDC; do not require maintainer-signed commits in baseline

**Decision**: The release marker (the `v*` tag) is signed by the release workflow's OIDC identity via Sigstore; individual maintainer commits and the release-bump commit itself are **not** required to be GPG/SSH-signed in the baseline. Commit signing is an FR-007 extension-point addition for a later hardening pass.

**Rationale**:
- Q3's answer explicitly deferred the signed-commit path to extension work: "Two-person approval gates and signed-commit-before-release workflows are extension-point additions for when the maintainer set grows or a threat model justifies the friction."
- The SLSA provenance identifies the exact commit the release came from and the exact workflow that produced it, which is the load-bearing trust claim. Commit signing adds a second, weaker layer (a signature over the commit text) that mostly duplicates the Git object-hash chain.
- Tag-protection rules (FR-019) prevent unauthorized pushers from creating release-pattern tags; combined with the provenance, we cover the "who triggered this release" question without per-commit signing ceremony.

**Alternatives considered**:
- **Require every release-bump commit to be GPG/SSH-signed**: real security benefit, real friction (every maintainer sets up signing). Given the current maintainer set (small), rejected for baseline; explicitly flagged as extension work.

---

## 5. Changelog format: Keep a Changelog, explicit version headings

**Decision**: Adopt the Keep a Changelog 1.1.0 convention already in use in `plugins/kusari/CHANGELOG.md`: top-level `# Changelog`, per-version `## vX.Y.Z — YYYY-MM-DD` headings (with the existing em-dash separator the current file uses), and sub-sections `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Security`. Reserve an `## Unreleased` section at the top for in-flight changes.

**Rationale**:
- Already the pattern this project uses; introducing a different convention would violate FR-011 (distinguish released vs unreleased) by creating two formats that each partially do that job.
- `render-release-notes.sh` can deterministically extract the per-version section by parsing headings — simple, regex-friendly, no parser needed.
- The Keep a Changelog `Unreleased` convention is the native way to express FR-011's "changes that have merged but not yet shipped" concept, and migrating an `Unreleased` block to a versioned heading is exactly what `bump-release.sh` does.
- "Security" as a top-level change category is directly relevant to a security plugin and maps to FR-004's required categories.

**Alternatives considered**:
- **Conventional Commits auto-derived changelog**: deferred to an FR-007 extension point. The existing manual CHANGELOG has higher signal-to-noise than a commit-derived one would, and the project's commit history doesn't currently follow a strict Conventional Commits discipline.
- **Release Drafter**: GitHub-specific, couples the changelog format to GitHub-specific PR label conventions. Rejected as baseline — it would make the CHANGELOG dependent on where development happened, conflicting with Constitution §V (agent-portability).

**References**:
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
- Existing file: `plugins/kusari/CHANGELOG.md`

---

## 6. Marketplace source-pin shape: `github` source with ref + sha

**Decision**: On release, rewrite the plugin entry in `.claude-plugin/marketplace.json` to the pinned `github` source form supported by Claude Code:

```json
{
  "name": "kusari",
  "source": {
    "source": "github",
    "repo": "kusaridev/kusari-skills",
    "ref": "v0.3.0",
    "path": "plugins/kusari"
  },
  "strict": true
}
```

`ref` is the release tag (what marketplace resolution reads). Consider adding `sha` (the commit the tag points at) once the release workflow has computed it — it makes the pin content-addressed, not just ref-addressed, which matches the spirit of FR-008 (reproducibility) and FR-020 (immutability).

**Rationale**:
- This is the exact form the Claude Code marketplace format documents (per the marketplace research agent's findings) and is the one that produces FR-022's self-consistent tagged state: at tag `vN`, `marketplace.json` references `vN`.
- Including `sha` additionally guards against tag-equivocation — if an attacker somehow moved a tag despite tag-protection (belt-and-suspenders), a sha-pinned marketplace would still resolve to the original commit.
- `path: "plugins/kusari"` keeps the plugin layout inside a monorepo-style marketplace, which is what the existing `.claude-plugin/marketplace.json` structure already assumes.

**Alternatives considered**:
- **Source-only relative path** (current): unsupported by FR-022 because it doesn't pin to a ref. Rejected.
- **External URL pinning** (`{ "source": "url", "url": "https://github.com/.../archive/v0.3.0.tar.gz" }`): works, but introduces a tarball-shaped artifact that conflicts with FR-021's "source-at-tag, no separately-packaged artifact" decision.

---

## 7. Release workflow trigger and shape

**Decision**: The release workflow triggers on `push` of tags matching `v*.*.*` (standard SemVer form, inclusive of prerelease qualifiers like `v0.3.0-rc.1`). It also supports `workflow_dispatch` with a `dry_run: true` input that exercises all steps except publishing (no release created, no SBOM attached to any release — SBOM is produced and uploaded as a workflow artifact for inspection).

The workflow structure is a single-job DAG (not multi-job), with the named extension points realized as `# === EXTENSION POINT: <name> ===` comment-bracketed regions in the YAML. This makes them trivially greppable and lets contributors add steps by editing one place.

Steps (ordered):
1. **`pre-release`** extension point (empty by default) [FR-007]
2. Checkout with full history (needed for provenance)
3. Parse the tag name → version identifier
4. Run `scripts/release/validate-release.sh` (invariants — FR-005)
5. **`post-version-bump`** extension point (empty by default) [FR-007]
6. Run `scripts/release/render-release-notes.sh` → note body
7. Run `scripts/release/generate-sbom.sh` → `sbom.spdx.json` [FR-025]
8. Run OpenSSF Baseline audit (invoke `darnit`) → `openssf-baseline.json`; abort on regression [FR-026]
9. Call `slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml` with the set of release subjects (the source tree hash + the SBOM file + the audit report) [FR-014, FR-015]
10. **`post-release-marker`** extension point (empty by default) [FR-007]
11. `gh release create` with the notes body, pre-release flag set if the SemVer qualifier indicates one [FR-013], and all assets attached (sbom, audit, provenance, signature)
12. **`post-publish`** extension point (empty by default) [FR-007]

**Rationale**:
- Tag-triggered release is the standard, simplest maintainer UX and matches Q3 (tag-push is the initiation signal; tag-protection controls the authorization).
- Single-job DAG keeps the provenance attestation simple: one workflow run, one set of subjects, one attestation.
- Extension points as comment-bracketed regions beats a plugin system — FR-007 only requires the points exist and be documented, and this form is the simplest thing that satisfies that without new infrastructure.

**Alternatives considered**:
- **Multi-job workflow with separate validate / attest / publish jobs**: more modular but complicates the SLSA subject set (each job runs in its own runner; sharing file artifacts requires `upload-artifact` chains). For one plugin with a short pipeline, overhead > benefit.
- **Tag-protection via tag name prefix `release-v*` rather than `v*`**: some projects do this to disambiguate release tags from arbitrary version tags. Rejected — adds cognitive overhead for maintainers; the `v*` pattern is universally understood.

---

## 8. Withdrawal implementation: annotate + prerelease demote + GHSA

**Decision**: Document the withdrawal process as three discrete actions performed by a maintainer after a release has been identified as broken, with no automated trigger:

1. Edit the release entry's body to prepend a `> ⚠️ WITHDRAWN — see [vX.Y.Z+1](...)` banner. This is the only edit the immutability FR (FR-020c) permits post-publication.
2. If no superseding release is available yet *and* the withdrawal is urgent enough to warrant default-install exclusion immediately: flip the release's `prerelease` flag to `true` via `gh release edit --prerelease`. The GitHub marketplace logic that picks "latest" excludes prereleases, so this immediately removes the withdrawn release from default resolution.
3. If the withdrawal is security-motivated: draft and publish a GitHub Security Advisory (`gh api repos/.../security-advisories`) referencing the withdrawn version identifier. The advisory's affected-versions range is the canonical machine-readable revocation signal consumed by Dependabot, Renovate, and other downstream tooling (FR-017).

**Rationale**:
- Flipping the prerelease flag is an allowed-by-FR-020 edit in the narrow sense that it doesn't alter the artifact, the signature, the provenance, or the release notes body — it's metadata describing the release's *distribution status*, not its content. We'll codify this distinction explicitly in the `contracts/release-artifact-shape.md` document so it's unambiguous.
- Publishing the superseding fix release is usually the right answer and avoids needing the prerelease-demotion path; step 2 exists for the emergency case.
- The GHSA path for security issues aligns with FR-017's "machine-readable revocation feed" — GHSA *is* the canonical format GitHub's ecosystem consumes.

**Alternatives considered**:
- **Delete the release**: violates FR-020 outright. Rejected.
- **Move the tag to a dummy commit**: violates FR-020a outright. Rejected.
- **Sigstore revocation via transparency-log annotation**: strongest machine signal but requires revocation-aware verifier tooling that not all consumers have. Left as an extension-point addition (Q2's option D) for later hardening when verifier ecosystem matures.

---

## 9. Prerelease designation: SemVer pre-release qualifier + GitHub prerelease flag

**Decision**: A prerelease is any tag whose SemVer version has a pre-release qualifier (e.g., `v0.3.0-rc.1`, `v0.3.0-beta.2`). The release workflow detects this by parsing the tag name and sets GitHub Releases' `prerelease: true` flag automatically. Prereleases get the full signing + provenance + SBOM + audit treatment — they are real releases, just marked as not-for-general-use (FR-013).

**Rationale**:
- Uses SemVer's own mechanism; no new vocabulary to invent.
- `prerelease: true` is the native GitHub signal the marketplace uses to exclude a release from "latest stable" resolution — same mechanism as withdrawal-demotion, but with a legitimate pre-stable meaning rather than a reactive one.
- Means prereleases never accidentally become the default-install target, satisfying FR-013 without an extra manual step.

**Alternatives considered**:
- **Separate channel with its own tag prefix** (e.g., `rc-v0.3.0`): breaks SemVer parsing everywhere else, requires custom prerelease detection. Rejected.

---

## 10. Testing strategy for shell release scripts

**Decision**: Per-script test harnesses at `tests/release/test-<script>.sh` using the existing pattern established by `tests/test-run-kusari-scan.sh` and `tests/test-sarif-parser.sh`. Fixtures are under `tests/release/fixtures/repo-<state>/` — small, curated copies of the minimum file structure each script reads (`plugin.json` + `CHANGELOG.md` + `marketplace.json`), not full repo clones. Each fixture represents one named spec Edge Case; each test asserts the documented exit code and a regex on stderr for the error message.

**Rationale**:
- Matches existing test discipline in the repo — no new testing philosophy introduced.
- Fixtures-as-directory-trees are reviewable in Git diffs; a reviewer can see precisely what state triggered which failure mode.
- Exit codes + stderr regex is the stable contract (FR-005 requires fails be "visible") and tolerant of implementation churn.
- Shell-scripted tests avoid introducing a test framework dependency (e.g., Bats) — Constitution §III's "prefer standard library solutions" applied.

**Alternatives considered**:
- **Bats (Bash Automated Testing System)**: nicer reporting, adds a build-time dependency. The existing scripts don't use it; doing so just for release tests would create split test styles in the repo. Rejected.
- **Workflow-level integration tests only**: slow feedback (CI roundtrip per change), doesn't exercise script contracts directly. Rejected as the *primary* layer, though the workflow dry-run mode serves as end-to-end smoke.

---

## 11. Baseline action pinning: all SHAs, no floating tags

**Decision**: Every GitHub Action referenced in the release workflow is pinned by commit SHA (40-hex), with the human-readable version appended as a comment (as the repo already does in `shellcheck.yml` and per the recent commit `1b73f5f fix: pin checkout action by hash and bump CLI version`).

Example:
```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
- uses: sigstore/cosign-installer@<SHA> # v3.7.0
- uses: anchore/syft@<SHA> # v1.10.0
```

Dependabot (or an equivalent automation) MAY periodically propose SHA-bump PRs; those PRs go through the same review process as any other change.

**Rationale**: Constitution §III ("dependencies MUST be pinned to exact versions with integrity hashes where the ecosystem supports them") is explicit. Tag-pinning (`@v6`) is vulnerable to tag-remounting attacks; SHA-pinning is not.

**Alternatives considered**: None — this is non-negotiable per Constitution §III.

---

## 12. Distribution model: Mode 3 (reference-only), with declarative prerequisites as single source of truth

**Decision**: The plugin is a **Mode 3 reference-only distribution** — it ships the 11 files in `plugins/kusari/`, references external tools (Kusari CLI, jq, bash, MCP servers) as runtime prerequisites, and neither bundles nor installs any external tool. The plugin's prerequisites are encoded in a single declarative file at `plugins/kusari/prerequisites.json` that is consumed by two readers: `hooks/check-prerequisites.sh` (install-time enforcement) and `scripts/release/generate-sbom.sh` (SBOM generation per §2).

**Mode taxonomy (for future-proofing)**:
| Mode | What we distribute | SBOM scope |
|------|--------------------|-----------|
| 1 | Tarball bundles plugin + external tool(s) | Everything bundled is a Package; `CONTAINS`/`DEPENDS_ON` relationships |
| 2 | Installer script fetches and installs both | Both; the installer's supply-chain story becomes ours |
| **3** | **Plugin only; prerequisites documented** | **Plugin files + `HAS_PREREQUISITE` to external packages** |
| 4 | Skill auto-installs the CLI at runtime | Both + version-pinning coupling problems |

**Rationale for Mode 3**:
- Reflects what the plugin actually does today.
- The Kusari CLI is independently useful and is distributed through Kusari's own channels with its own release cadence, signatures, and SBOM. Taking responsibility for its distribution (Mode 1/2/4) would couple plugin releases to CLI releases and bloat our release-maintenance surface with no user benefit.
- Mode 4's specific cost — needing to pin a specific CLI version per plugin release — is the antipattern this decision avoids.
- Distribution scope = SBOM scope (§2 alignment).

**Prerequisites declaration format**:

Location: `plugins/kusari/prerequisites.json`. See `contracts/prerequisites-declaration.md` for the authoritative schema.

Shape (illustrative, not authoritative):
```json
{
  "tools": [
    {
      "name": "kusari",
      "minVersion": "0.21.0",
      "purl": "pkg:github/kusaridev/kusari-cli",
      "downloadLocation": "https://github.com/kusaridev/kusari-cli/releases",
      "purpose": "SARIF scanning CLI and MCP server source"
    },
    {
      "name": "jq",
      "purl": "pkg:generic/jq",
      "downloadLocation": "https://jqlang.org/",
      "purpose": "JSON manipulation in scan-pipeline scripts"
    }
  ]
}
```

**Consumer contracts**:
- `check-prerequisites.sh` iterates `tools[]` and for each entry runs `command -v <name>` (and, when `minVersion` is specified, parses `<name> --version`). Missing or too-old tools fail the hook with a human-readable message pointing at `downloadLocation`.
- `generate-sbom.sh` iterates the same array and emits one SPDX Package + one `HAS_PREREQUISITE` Relationship per entry, with Package fields populated from `purl`, `downloadLocation`, and `name`.

**Implications for the release process**:
- A change to what the plugin requires at runtime is a one-file edit to `prerequisites.json`, plus whatever code change necessitated it. The install-time check and the SBOM stay automatically in sync.
- Because the install-time check fails closed if a declared prerequisite is absent, the cost of forgetting to declare a dependency is *visible* at a user's first invocation — it's a loud, fixable failure, not a silent drift.

**Mode transitions (future scope)**:
- Adopting Mode 1 (bundle a CLI) or Mode 2 (auto-install) would expand the SBOM to include the CLI as a contained Package and would require adopting the CLI's release cadence as a coupled dependency. Not a lift to be undertaken without clear demand.
- Mode 4 (auto-install at first use) has the worst version-coupling properties and should be considered only if the CLI's release cadence slows dramatically relative to the plugin's.

**Alternatives considered**:
- **Keep prerequisites embedded in bash**: the current `check-prerequisites.sh` state. Not parseable as structured data; forces the SBOM generator to either duplicate the declaration or parse bash. Rejected.
- **Prerequisites as a field in `plugin.json`**: `plugin.json` is the Claude Code marketplace manifest; its schema is owned by the marketplace spec, not us. Adding ad-hoc fields risks future schema conflicts. A standalone file sidesteps this.
- **Prerequisites documented only in README**: not machine-readable. Forces the SBOM generator to parse Markdown. Rejected.

**References**: §2 (how the SBOM consumes this); `contracts/prerequisites-declaration.md` (authoritative schema).

---

## Summary of resolved technology choices

| Concern | Choice | Authority |
|---------|--------|-----------|
| Provenance + signing | slsa-github-generator (SLSA L3, Sigstore keyless) | §1 |
| SBOM tool + format | syft file inventory + prereqs-file-derived `HAS_PREREQUISITE` relationships; SPDX 2.3 JSON | §2 |
| Compliance audit | darnit (existing plugin tooling) | §3 |
| Commit signing | not required in baseline; extension-point | §4 |
| Changelog format | Keep a Changelog 1.1.0 (project's existing form) | §5 |
| Marketplace pin shape | `github` source with `ref` (+ `sha` when available) | §6 |
| Workflow trigger | tag push `v*.*.*` + workflow_dispatch dry-run | §7 |
| Withdrawal | annotate + optional prerelease-flag + GHSA for security | §8 |
| Prerelease designation | SemVer qualifier → GitHub prerelease flag | §9 |
| Test harness | per-script bash + fixture dirs, existing repo pattern | §10 |
| Action pinning | all by SHA (Constitution §III) | §11 |
| Distribution model | Mode 3 (reference-only); `prerequisites.json` as SOT for check + SBOM | §12 |

No `NEEDS CLARIFICATION` items remain.
