<!--
  Sync Impact Report
  ==================
  Version change: (none) → 1.0.0
  Bump rationale: Initial ratification — MAJOR version for first adoption.

  Modified principles: N/A (initial creation)

  Added sections:
    - Core Principles (5): Security-First, Specification-Driven Development,
      Supply Chain Integrity, Test-First Discipline, Agent-Agnostic Design
    - Supply Chain & Security Standards
    - Development Workflow & Quality Gates
    - Governance

  Removed sections: N/A

  Templates requiring updates:
    - .specify/templates/plan-template.md        ✅ aligned (Constitution Check section present)
    - .specify/templates/spec-template.md         ✅ aligned (technology-agnostic, user-story-driven)
    - .specify/templates/tasks-template.md        ✅ aligned (TDD gates, parallel markers, phased delivery)
    - .specify/templates/checklist-template.md    ✅ aligned (quality validation checklists)
    - .specify/templates/constitution-template.md ✅ source template (no update needed)

  Deferred items: None
-->

# Kusari Skills Constitution

## Core Principles

### I. Security-First (NON-NEGOTIABLE)

Security and safety MUST be the primary consideration in every
design decision, code change, and dependency choice.

- Every feature, integration, and artifact MUST undergo security
  review before merge.
- Sensitive data (secrets, credentials, PII) MUST never appear in
  logs, artifacts, or version control.
- Defense-in-depth MUST be applied: no single security control is
  sufficient on its own.
- All external inputs MUST be validated at system boundaries.
- Security vulnerabilities MUST be triaged within 24 hours of
  discovery; critical vulnerabilities MUST block releases.

**Rationale**: The project name "Kusari" (chain) reflects linked
security — a chain is only as strong as its weakest link. Security
failures cascade; prevention is orders of magnitude cheaper than
remediation.

### II. Specification-Driven Development

Every feature MUST begin with a formal specification before any
implementation work starts.

- Specifications MUST describe user needs (WHAT), never
  implementation details (HOW).
- Specifications MUST be technology-agnostic and written for
  business stakeholders, not developers.
- Each user story within a specification MUST be independently
  testable and deployable.
- Specifications MUST be approved before planning begins.
- Requirements MUST use RFC 2119 keywords (MUST, SHOULD, MAY) to
  eliminate ambiguity.

**Rationale**: Specifications prevent scope creep, align
stakeholders, and provide a testable contract against which
implementation correctness is measured.

### III. Supply Chain Integrity

All software supply chain artifacts MUST be traceable, verifiable,
and compliant with OpenSSF Baseline standards.

- All dependencies MUST be pinned to exact versions with integrity
  hashes where the ecosystem supports them.
- Software Bill of Materials (SBOM) MUST be generated for every
  release.
- Provenance attestation MUST accompany all published artifacts.
- OpenSSF Baseline compliance MUST be maintained and audited on a
  regular cadence (at minimum before each release).
- New dependencies MUST be justified, reviewed for known
  vulnerabilities, and documented before adoption.

**Rationale**: Modern software relies on deep dependency trees.
Supply chain attacks exploit trust in transitive dependencies.
Verifiable provenance and pinned dependencies reduce this attack
surface.

### IV. Test-First Discipline (NON-NEGOTIABLE)

Tests MUST be written before implementation code. The
Red-Green-Refactor cycle is strictly enforced.

- Acceptance scenarios MUST use Given-When-Then format.
- Every user story MUST have at least one automated acceptance test
  that can run independently.
- Quality gates MUST pass before any workflow phase transition
  (specification → plan → tasks → implementation).
- Test coverage MUST NOT decrease with any change; regressions MUST
  block merge.
- Integration tests MUST cover all cross-component boundaries.

**Rationale**: Test-first development catches defects at their
cheapest point of repair, provides living documentation, and
enforces interface-first design thinking.

### V. Agent-Agnostic Design

All workflows MUST function with any AI agent — or without AI
assistance entirely.

- Structured Markdown artifacts MUST be the canonical source of
  truth, not agent-specific formats or proprietary data.
- Outputs MUST be reproducible: given the same inputs and templates,
  any agent (or a human) MUST produce equivalent results.
- No vendor lock-in is permitted in tooling, templates, or
  orchestration scripts.
- Agent-specific integration files (e.g., CLAUDE.md) MUST be
  auto-generated from canonical templates, never hand-edited as
  primary sources.

**Rationale**: AI tooling evolves rapidly. Coupling workflows to a
single agent creates fragile processes. Portable, structured
artifacts ensure longevity regardless of which agent executes them.

## Supply Chain & Security Standards

- **Dependency policy**: Prefer standard library solutions over
  external dependencies. Every new dependency MUST be reviewed for
  license compatibility, maintenance status, and known
  vulnerabilities.
- **Artifact signing**: All release artifacts MUST be signed.
  Signatures MUST be verifiable by downstream consumers.
- **Vulnerability management**: Automated vulnerability scanning
  MUST run in CI. Findings rated HIGH or CRITICAL MUST be resolved
  before release. Findings rated MEDIUM MUST have a documented
  remediation plan within 30 days.
- **Access control**: Repository write access MUST require
  multi-factor authentication. Branch protection MUST enforce
  required reviews and status checks on the default branch.
- **Audit trail**: All security-relevant events (access changes,
  dependency updates, vulnerability findings) MUST be logged and
  retained for a minimum of 90 days.

## Development Workflow & Quality Gates

- **Phase transitions**: Each workflow phase (specify → clarify →
  plan → tasks → implement) MUST produce its required artifacts
  before the next phase can begin.
- **Constitution check**: Every implementation plan MUST include a
  Constitution Check section verifying alignment with these
  principles before design work proceeds.
- **Code review**: All changes MUST be reviewed by at least one
  person (or agent) other than the author before merge.
- **Quality gate checklist** (applied at every phase boundary):
  1. Syntax and format validation
  2. Security review (Principle I compliance)
  3. Specification alignment (Principle II compliance)
  4. Supply chain verification (Principle III compliance)
  5. Test coverage verification (Principle IV compliance)
  6. Agent-portability check (Principle V compliance)
- **Incremental delivery**: User stories MUST be deliverable
  independently in priority order (P1 first). Each delivered
  increment MUST be a functional, testable unit.
- **Rollback readiness**: Every deployment MUST have a documented
  rollback procedure. Deployments without rollback capability MUST
  NOT proceed to production.

## Governance

This constitution is the supreme governing document for the Kusari
Skills project. It supersedes all other practices, conventions, and
ad-hoc decisions.

- **Amendment procedure**: Any amendment MUST be proposed as a pull
  request modifying this file. The proposal MUST include a rationale,
  an impact assessment on existing artifacts, and a migration plan
  for any breaking changes. Amendments MUST be reviewed and approved
  before merge.
- **Versioning policy**: This constitution follows Semantic
  Versioning:
  - **MAJOR**: Removal or incompatible redefinition of a principle.
  - **MINOR**: Addition of a new principle or material expansion of
    existing guidance.
  - **PATCH**: Clarifications, wording corrections, non-semantic
    refinements.
- **Compliance review**: All pull requests and code reviews MUST
  verify compliance with these principles. Non-compliance MUST be
  flagged and resolved before merge.
- **Complexity justification**: Any deviation from these principles
  MUST be documented with a justification and an explanation of why
  simpler, compliant alternatives were insufficient.
- **Runtime guidance**: Use agent-specific guidance files
  (auto-generated from templates) for day-to-day development
  context. This constitution defines the rules; guidance files
  translate them into actionable steps.

**Version**: 1.0.0 | **Ratified**: 2026-03-03 | **Last Amended**: 2026-03-03
