# Contract: `marketplace.json` Source Pin Shape

**Purpose**: Define the exact transformation `bump-release.sh` applies to `.claude-plugin/marketplace.json` on every release, and the shape `validate-release.sh` asserts against.

## Per-release transformation

Before each release, the plugin entry in `marketplace.json` is rewritten to the pinned-ref form required by FR-022.

### Source state (before first-ever release, or between releases)

After the first release ships, the plugin entry is always in the pinned form below. The current repository state uses a relative path (pre-release-process era); the first release will migrate it.

Current (pre-feature):

```json
{
  "name": "kusari",
  "source": "./plugins/kusari",
  "strict": true
}
```

### Target state (at tag `v<N>`)

```json
{
  "name": "kusari",
  "source": {
    "source": "github",
    "repo": "kusaridev/kusari-skills",
    "ref": "v<N>",
    "path": "plugins/kusari"
  },
  "strict": true
}
```

### Optional hardening — content-addressed pin

When the workflow can cheaply compute the tagged commit SHA (it can — it has the ref), the pin MAY additionally include the `sha` field:

```json
"source": {
  "source": "github",
  "repo": "kusaridev/kusari-skills",
  "ref": "v<N>",
  "sha": "<40-hex commit SHA>",
  "path": "plugins/kusari"
}
```

This is recommended for long-term robustness against tag-equivocation attacks (even though tag-protection rules per FR-019 already guard against this at the repo level). A consumer-side implementation MUST still accept the `ref`-only form for backward compatibility during the pre-`sha` transition.

## Field semantics

| Field | Required in pinned form | Meaning |
|-------|-------------------------|---------|
| `source` (the outer string) | yes | Literal value `"github"`. Indicates the marketplace should resolve this plugin from a GitHub repository at a specific ref. |
| `repo` | yes | `<owner>/<repo>` form. Literal value `"kusaridev/kusari-skills"` for this project. |
| `ref` | yes | Git ref resolvable in the repo. Baseline: the release tag in canonical form (e.g., `v0.3.0`). |
| `sha` | no (recommended) | 40-hex commit SHA the ref points at. When present, consumers MAY prefer it over `ref` for stronger content-addressing. |
| `path` | yes | Path inside the repo at which the plugin's contents live. Literal value `"plugins/kusari"` for this project. |

All other `marketplace.json` fields (top-level `name`, `owner`, `metadata.*`) are untouched by the release process. Adding a second plugin to the marketplace later is a separate concern (see spec Assumptions) and doesn't require a plugin version bump.

## Rewriter contract (`bump-release.sh` behavior for marketplace.json)

Inputs:
- Target version (unprefixed SemVer form, e.g., `0.3.0`).

Transformation:
1. Parse `.claude-plugin/marketplace.json`.
2. Locate the plugin entry with `name == "kusari"`.
3. Replace its `source` field (whether it was previously a string, an object in a different ref, or an object at the prior release's ref) with the target state shape above, using `ref: "v<target-version>"`.
4. If a `sha` field is computed by the caller, include it; otherwise omit.
5. Write the file back preserving JSON formatting (2-space indentation, trailing newline — matching the existing file's style).

The rewrite is idempotent: applying it twice for the same target version produces byte-identical output.

## Validator contract (`validate-release.sh` check C6)

Asserts, at the release-bump commit:

- The plugin entry's `source` is an object (not a string).
- `source.source == "github"`.
- `source.repo == "kusaridev/kusari-skills"`.
- `source.ref == "v<target-version>"`.
- `source.path == "plugins/kusari"`.
- If `source.sha` is present, it is exactly 40 hex characters.

Any mismatch is an E6 failure in the validator's output.

## Consumer resolution behavior (what users see)

| User action | What they get |
|-------------|---------------|
| `/plugin marketplace add kusaridev/kusari-skills` (no ref) | `marketplace.json` at HEAD of default branch → plugin entry with `source.ref = v<latest-released>` → plugin contents resolved from `plugins/kusari/` at tag `v<latest-released>` |
| `/plugin marketplace add kusaridev/kusari-skills@v0.3.0` | `marketplace.json` at tag `v0.3.0` → plugin entry with `source.ref = v0.3.0` → plugin contents at `plugins/kusari/` at tag `v0.3.0`. Resolves to the same state forever regardless of subsequent releases. |
| `/plugin marketplace add kusaridev/kusari-skills@main` | `marketplace.json` at `main` → plugin entry with `source.ref = v<latest-released>` (because main's marketplace.json is the published release's pointer). Same as the first row. A user who wants "whatever's in plugins/kusari on main right now" would need to install by pointing at a different ref or checkout locally — which is intentional per FR-023. |

This table is what makes Q5's "marketplace-pins-to-latest-release" decision work correctly in practice.
