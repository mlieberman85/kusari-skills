# Implementation Plan: Release Process

**Branch**: `006-release-process` | **Date**: 2026-04-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-release-process/spec.md`

## Summary

Build a CI-executed, maintainer-initiated release process for the `kusari` Claude Code plugin that produces a signed, provenance-attested, SBOM-accompanied release on every tag matching `v*`. The release commit self-consistently pins `marketplace.json`'s plugin `source.ref` to the new tag, so unpinned marketplace subscribers resolve to the released version while pinned subscribers stay on their chosen ref. Baseline gates include invariant validation (plugin.json ↔ CHANGELOG ↔ marketplace.json ↔ tag agreement), OpenSSF Baseline audit, and SBOM generation; extension points are named stages in the workflow where future steps (external registry publish, auto-changelog, etc.) can be inserted without editing existing steps.

Technical approach: a single `.github/workflows/release.yml` tag-triggered workflow orchestrates a small set of focused bash scripts under `scripts/release/` (invariant validation, release-note extraction, local pre-release bump helper), delegates signing/provenance to the `slsa-github-generator` reusable workflow (SLSA Build Level 3, keyless Sigstore identity via OIDC), generates the SBOM with `syft` (file inventory) merged with `HAS_PREREQUISITE` relationships derived from a new canonical `plugins/kusari/prerequisites.json` declaration, runs the OpenSSF Baseline audit via the existing `darnit` tooling bundled with this plugin, publishes the GitHub Release with release notes extracted from `CHANGELOG.md`, and attaches signature + provenance + SBOM + audit report as release assets. A companion `release-validate.yml` PR workflow enforces the same invariants on release-bump PRs before tagging. As a foundational dependency, the existing imperative `hooks/check-prerequisites.sh` is refactored to consume the same `prerequisites.json` declaration — making the plugin's external-dependency story single-source-of-truth across install-time enforcement and SBOM publication (research.md §12; contracts/prerequisites-declaration.md).

## Technical Context

**Language/Version**: Bash (POSIX-compatible, `#!/usr/bin/env bash`, `set -euo pipefail`) for release scripts; YAML for GitHub Actions workflows; JSON for manifest manipulation (via `jq`).
**Primary Dependencies** (all pinned by commit SHA per Constitution §III):
- `slsa-framework/slsa-github-generator` reusable workflow — SLSA v1.0 Build L3 provenance, Sigstore keyless signing tied to workflow OIDC identity
- `sigstore/cosign-installer` — for tag signing (`cosign sign --identity-token`)
- `anchore/syft` — SBOM generation (SPDX JSON)
- `darnit` MCP (already bundled with this plugin) — OpenSSF Baseline audit
- `gh` CLI (pre-installed on GitHub Actions runners) — release creation, GHSA publication
- `jq` (pre-installed on Ubuntu runners) — JSON manipulation
- ShellCheck (existing CI) — lint for new release scripts

**Storage**: Git repo (tags, release-bump commits); GitHub Releases (release entries + assets); Sigstore transparency log (provenance + signatures); GitHub Security Advisories database (for security withdrawals).
**Testing**:
- Unit tests for bash scripts in `tests/release/test-*.sh`, following the existing pattern in `tests/test-run-kusari-scan.sh` and `tests/test-sarif-parser.sh` (fixtures under `tests/fixtures/release/`).
- Workflow integration test via a `workflow_dispatch` `dry-run` input that exercises all steps except the publishing stage (no tag created, no release published).
- End-to-end smoke test: cut a `v0.0.0-test` prerelease on a throwaway branch the first time the workflow is enabled, verify all artifacts are produced and verifiable, then delete.

**Target Platform**: GitHub Actions `ubuntu-latest` runners for the release workflow; any POSIX system (macOS, Linux) for local dry-run / validation via the scripts.
**Project Type**: CI automation + shell tooling + documentation. No application runtime; no packaged artifact. The "deliverable" is a set of workflows + scripts + a runbook that together implement the release ceremony specified in spec.md.
**Performance Goals**: Full release workflow (tag push → release published with all artifacts) completes under 15 minutes per SC-001. Invariant validation under 10 seconds locally (SC-001 supports maintainer's quick pre-push check).
**Constraints**:
- All GitHub Actions pinned by commit SHA, not tag (Constitution §III; existing repo practice per commit `1b73f5f`).
- Signing identity is the workflow OIDC token, not a maintainer's personal key (FR-015, Assumption re: OIDC).
- No secrets beyond the workflow's implicit `GITHUB_TOKEN` and the Sigstore public-good instance.
- Baseline signing/provenance/SBOM/audit MUST all succeed before the GitHub Release is created (any failure aborts the workflow with no release artifact produced).
- Every step MUST be expressed as code or config in the repo (FR-006); no manual click-ops on the GitHub UI during the release execution.

**Scale/Scope**: One plugin, one active release line (latest-only; LTS is an extension-point), expected cadence ≤1 release/month early on. Withdrawal events rare (expected <1/year); security withdrawals rarer still.

## Constitution Check

*Gate: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

Evaluated against `.specify/memory/constitution.md` v1.0.0.

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. Security-First (NON-NEGOTIABLE)** | ✅ PASS | The feature *is* a security feature. Signing (FR-014), provenance (FR-015), public verifiability (FR-016), tag-protection authorization (FR-019), post-publication immutability (FR-020), withdrawal with GHSA (FR-017), SBOM (FR-025), and a pre-release OpenSSF Baseline audit gate (FR-026) compose defense in depth. Secrets: release workflow uses only the workflow OIDC token and `GITHUB_TOKEN`; no long-lived secrets introduced. External inputs (the `v*` tag, the release-bump commit) are validated before any artifact is produced (FR-005). |
| **II. Specification-Driven Development** | ✅ PASS | Spec is complete, 5-question clarification round resolved, 3 user stories (P1/P2/P3) each independently testable. All MUST/SHOULD language is RFC 2119. No implementation detail leakage into spec (confirmed in requirements checklist). |
| **III. Supply Chain Integrity** | ✅ PASS (with baseline additions) | Constitution mandates: dependency pinning ✅ (all actions by SHA), SBOM per release ✅ (FR-025, added to baseline), provenance per artifact ✅ (FR-015), OpenSSF Baseline audit per release ✅ (FR-026, added to baseline), dependency review ✅ (each new action in §Technical Context documented with justification). The two FRs (FR-025, FR-026) were added during this Constitution Check round and recorded in the spec's Clarifications section as constitution-derived. |
| **IV. Test-First Discipline (NON-NEGOTIABLE)** | ✅ PASS | Phase 1 generates `contracts/` (the invariant validator's contract, release-workflow inputs/outputs, release-artifact shape) and acceptance test fixtures before any workflow code is written. Each user story has a Given-When-Then scenario in the spec; tests will be authored from those scenarios. Bash scripts follow the existing `tests/test-*.sh` + `tests/fixtures/` pattern. Dry-run mode is a first-class workflow input so the pipeline can be exercised in CI before any actual release. |
| **V. Agent-Agnostic Design** | ✅ PASS | All artifacts are plain Markdown, YAML, JSON, Bash. No agent-specific tooling in the release path. CLAUDE.md is already auto-generated; the new scripts and workflow are readable by any maintainer or agent. |

**Constitution Check result**: PASS with the two additions (FR-025 SBOM, FR-026 Baseline audit) promoted from extension-point examples to baseline requirements in the spec. No Complexity Tracking entries needed — no deviation from Constitution.

## Project Structure

### Documentation (this feature)

```text
specs/006-release-process/
├── spec.md                 # Feature spec (already produced by /speckit.specify + /speckit.clarify)
├── plan.md                 # This file (/speckit.plan output)
├── research.md             # Phase 0 output — tech decisions + rationale
├── data-model.md           # Phase 1 output — Release / Version / Changelog entry / Extension point entities
├── quickstart.md           # Phase 1 output — maintainer's release runbook
├── contracts/              # Phase 1 output — interface contracts
│   ├── release-workflow.md         # Workflow inputs/outputs; triggers; emitted artifacts
│   ├── validate-release.md         # CLI contract: args, exit codes, stdout/stderr format
│   ├── release-artifact-shape.md   # The shape of a published release (tag + notes + sig + provenance + SBOM + audit report)
│   ├── changelog-format.md         # CHANGELOG.md format the release process relies on
│   └── marketplace-source-pin.md   # How marketplace.json's source.ref is shaped per release
├── checklists/
│   └── requirements.md     # Quality checklist (from /speckit.specify)
└── tasks.md                # Phase 2 output — NOT created by /speckit.plan (created by /speckit.tasks)
```

### Source code (repository root)

```text
.github/
├── workflows/
│   ├── release.yml                 # Tag-triggered release pipeline (on push of tags matching v*)
│   ├── release-validate.yml        # PR gate: runs invariant validator on PRs that touch release-sensitive files
│   └── shellcheck.yml              # [EXISTING] extended implicitly — new scripts under scripts/release/ are picked up
└── actions/
    └── release-validate/
        └── action.yml              # Composite action reused by both workflows; thin shim calling scripts/release/validate-release.sh

scripts/
├── lint.sh                         # [EXISTING] covers new scripts/release/*.sh automatically via find
└── release/
    ├── validate-release.sh         # Invariant check: plugin.json.version, CHANGELOG heading, marketplace.json source.ref, tag name must all agree
    ├── render-release-notes.sh     # Extract the CHANGELOG section for a given version → stdout (for use as release notes body)
    ├── generate-sbom.sh            # Thin wrapper around syft producing SPDX JSON for plugins/kusari/ at HEAD
    ├── bump-release.sh             # Local-dev helper: bump plugin.json version, insert CHANGELOG "Unreleased" → "vN — date" entry, update marketplace.json source.ref to vN, stage changes. Does NOT tag or push.
    └── common.sh                   # Shared helpers: parse-semver, read-plugin-version, fail-with-message (mirrors existing plugins/kusari/skills/kusari-change-evaluate/scripts/common.sh pattern)

docs/
└── RELEASING.md                    # Maintainer runbook — links back to quickstart.md content, adapted for a persistent, in-repo location

plugins/kusari/
├── .claude-plugin/
│   └── plugin.json                 # [EXISTING] version bumped per release by scripts/release/bump-release.sh
├── CHANGELOG.md                    # [EXISTING] gains entry per release; release-notes renderer reads from here
├── README.md                       # [EXISTING — extended] gains a "Verifying a release" section with slsa-verifier + cosign commands (FR-028); validated at release time by validate-release.sh check C9
├── prerequisites.json              # [NEW] canonical declaration of external runtime tools; single source of truth for check-prerequisites.sh and generate-sbom.sh (see contracts/prerequisites-declaration.md)
└── hooks/
    └── check-prerequisites.sh      # [EXISTING — refactored] consumes prerequisites.json instead of hardcoding tool names

.claude-plugin/
└── marketplace.json                # [EXISTING] plugin entry's source field rewritten per release to pinned-ref form

tests/
├── test-run-kusari-scan.sh         # [EXISTING]
├── test-sarif-parser.sh            # [EXISTING]
├── fixtures/                       # [EXISTING]
└── release/
    ├── test-validate-release.sh          # Exercises validate-release.sh against all expected failure modes (spec Edge Cases) + happy path
    ├── test-render-release-notes.sh      # Exercises note extraction against single-version, multi-version, missing-version fixtures
    ├── test-bump-release.sh              # Exercises bump-release.sh against a clean fixture repo; asserts plugin.json/CHANGELOG/marketplace.json agreement post-bump
    └── fixtures/
        ├── repo-clean-at-v0.2.0/         # Baseline fixture representing a clean post-release state
        ├── repo-release-bumped-v0.3.0/   # Fixture representing the expected post-bump-pre-tag state (the validator should PASS)
        ├── repo-version-mismatch/        # plugin.json says v0.3.0; tag attempt v0.3.1 → validator must FAIL
        ├── repo-missing-changelog/       # plugin.json advanced; CHANGELOG not updated → FAIL
        ├── repo-marketplace-ref-drift/   # marketplace.json.source.ref != tag → FAIL
        └── repo-uncommitted-changes/     # working tree dirty → FAIL
```

**Structure Decision**: The feature adds three kinds of artifacts — GitHub Actions workflows under `.github/`, bash tooling under `scripts/release/` + `tests/release/`, and maintainer documentation under `docs/RELEASING.md`. This co-locates the release code with the existing CI tooling (same directory as `shellcheck.yml`, same script layout as the existing `common.sh` pattern used by skills, same test layout as existing `tests/test-*.sh`). No new top-level directories are introduced; no existing structure is reorganized. The plugin's own distributable contents (`plugins/kusari/`) are touched only by the bump helper and by the marketplace pin — they are not restructured.

Justification: `scripts/release/` as a sibling of `scripts/lint.sh` mirrors how skills organize their scripts (`plugins/kusari/skills/*/scripts/common.sh`) and keeps the project rooted in POSIX bash conventions. A single `common.sh` de-duplicates helpers across the four release scripts. The composite action at `.github/actions/release-validate/` exists so the validator is callable both from `release.yml` (tag push) and `release-validate.yml` (PR check) without workflow duplication.

## Complexity Tracking

No Constitution deviations require justification. The two constitution-derived additions (SBOM baseline, OpenSSF Baseline audit gate) were folded into the spec as baseline FRs rather than filed here.

## Phase 2 preview (what /speckit.tasks will produce)

Phase 2 will decompose the plan into dependency-ordered tasks by user story priority. Expected task clusters (not an exhaustive tasks.md, produced later):

- **US1 foundation**: author `validate-release.sh` (including check C9 for README verification section), `render-release-notes.sh`, `generate-sbom.sh`, `bump-release.sh`, `common.sh` with tests; create `plugins/kusari/prerequisites.json` and refactor `hooks/check-prerequisites.sh` to consume it (per `contracts/prerequisites-declaration.md`); add "Verifying a release" section to `plugins/kusari/README.md` with parameterized `slsa-verifier` + `cosign verify` commands (FR-028); draft `docs/RELEASING.md`; author `release.yml` + `release-validate.yml` with SHA-pinned actions; add tag-protection rule configuration documentation.
- **US2 (P2)**: release notes template + validation that notes include upgrade-action call-outs; CHANGELOG format contract; pre-push PR template.
- **US3 (P3)**: explicitly name the four extension points in `release.yml` (as comment-bracketed hook sections with documented semantics); author the runbook section describing how to add a new step.
- **Gates + operational readiness**: withdrawal runbook section (FR-012, FR-017, FR-018); pre-release designation section (FR-013); cut a test release `v0.0.0-test-00` on a throwaway branch to validate end-to-end; tear down.

Gates each phase must pass: ShellCheck on all new bash, integration tests on all new scripts, dry-run mode of the release workflow, and a final Constitution Re-Check before `/speckit.implement`.
