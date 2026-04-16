# Contract: `plugins/kusari/prerequisites.json`

**Purpose**: Canonical declaration of the external runtime tools the kusari plugin requires. Single source of truth consumed by both the install-time prerequisite check (`hooks/check-prerequisites.sh`) and the SBOM generator (`scripts/release/generate-sbom.sh`).

**Status**: New file introduced by feature 006-release-process. Replaces the imperative tool-check logic currently embedded in `hooks/check-prerequisites.sh`.

## Schema

```jsonc
{
  "tools": [
    {
      "name": "<command-name>",
      "minVersion": "<semver-string>" | null,
      "versionCommand": "<shell-command>" | null,
      "purl": "<package-url>",
      "downloadLocation": "<url>",
      "purpose": "<one-sentence-description>"
    }
    // ... one entry per required external tool
  ]
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tools` | array | yes | Must be non-empty. Each entry describes one external runtime tool. |
| `tools[].name` | string | yes | The command name used with `command -v`. Must be unique within `tools[]`. Example: `"kusari"`, `"jq"`, `"bash"`. |
| `tools[].minVersion` | SemVer string or `null` | yes | Minimum acceptable version. `null` means any installed version is acceptable. Example: `"0.21.0"`, `null`. |
| `tools[].versionCommand` | string or `null` | no (default `null`) | Shell command (as a single string) that, when run, prints the tool's version. The install-time check parses SemVer from this output. If `null`, the check runs `<name> --version` as the default. Example: `"kusari --version"`, `"jq --version"`. |
| `tools[].purl` | Package URL | yes | Canonical identifier for the tool's external source in [purl](https://github.com/package-url/purl-spec) format. Used verbatim in the SBOM's `externalRefs`. Example: `"pkg:github/kusaridev/kusari-cli"`, `"pkg:generic/jq"`. |
| `tools[].downloadLocation` | absolute URL | yes | Human-facing page for obtaining the tool. Surfaced in the prereq-check failure message and used as SPDX `downloadLocation`. Example: `"https://github.com/kusaridev/kusari-cli/releases"`. |
| `tools[].purpose` | string | yes | One-sentence description of why the plugin requires this tool. Surfaced in SBOM `comment` fields and in user-facing docs. Example: `"SARIF scanning CLI and MCP server source"`. |

### Style

- 2-space indent, trailing newline (matches existing JSON-file style in this repo).
- Keys ordered as documented above for readability.
- No comments in the committed file (JSON doesn't support them); design commentary lives in the adjacent README or documentation.

## Example (initial contents at feature landing)

```json
{
  "tools": [
    {
      "name": "kusari",
      "minVersion": "0.21.0",
      "versionCommand": "kusari --version",
      "purl": "pkg:github/kusaridev/kusari-cli",
      "downloadLocation": "https://github.com/kusaridev/kusari-cli/releases",
      "purpose": "SARIF scanning CLI and source of the kusari-inspector MCP server"
    },
    {
      "name": "jq",
      "minVersion": null,
      "versionCommand": null,
      "purl": "pkg:generic/jq",
      "downloadLocation": "https://jqlang.org/",
      "purpose": "JSON parsing in the scan-pipeline shell scripts"
    },
    {
      "name": "bash",
      "minVersion": "4.0",
      "versionCommand": null,
      "purl": "pkg:generic/bash",
      "downloadLocation": "https://www.gnu.org/software/bash/",
      "purpose": "Shell runtime for hook and skill scripts"
    }
  ]
}
```

Note: whether `bash` rises to the level of a declared prerequisite is a judgment call — it's universal on the target platforms. We include it here as the most-conservative stance (explicit is better than implicit); in practice the install-time check's "is bash installed?" test is trivially satisfied. If a future clean-up removes `bash` from the declaration, the shell scripts' shebangs (`#!/usr/bin/env bash`) remain the implicit requirement and the removal is a stylistic choice, not a semantic one.

## Consumer: `hooks/check-prerequisites.sh`

Contract (what the refactored hook must do):

1. Read `plugins/kusari/prerequisites.json` relative to the plugin root.
2. For each entry in `tools[]`:
   a. Run `command -v <name>`. If non-zero exit, emit a failure message of the form `"Prerequisite '<name>' not found. <purpose>. Install from <downloadLocation>."` and mark the check failed.
   b. If `minVersion` is non-null:
      - Determine the version command: use `tools[].versionCommand` if set, else `"<name> --version"`.
      - Run it; parse the first SemVer-shaped token from the first output line.
      - If parsing fails, emit a warning noting the version check was skipped (but do not fail the check on parse failure — tolerate tools that format their version output unusually).
      - If parsed successfully and the installed version is less than `minVersion`, emit a failure message of the form `"Prerequisite '<name>' version <found> is older than required <minVersion>. <purpose>. Update from <downloadLocation>."` and mark the check failed.
3. Exit 0 if all tools passed; exit 1 if any tool failed. Print a summary line indicating the counts.

The hook MUST NOT hardcode tool names, minimum versions, or download URLs — all of those come from `prerequisites.json`.

## Consumer: `scripts/release/generate-sbom.sh`

Contract (SBOM emission):

1. Read `plugins/kusari/prerequisites.json`.
2. Run `syft plugins/kusari/ -o spdx-json` to produce the file-inventory half of the SBOM.
3. For each entry in `tools[]`, construct an SPDX Package:
   - `SPDXID`: `SPDXRef-Prereq-<name>` (where `<name>` has non-identifier characters replaced with `-`).
   - `name`: the tool's `name`.
   - `filesAnalyzed`: `false`.
   - `downloadLocation`: the tool's `downloadLocation`.
   - `externalRefs`: `[{ "referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": "<purl>" }]`.
   - `versionInfo`: `">= <minVersion>"` if `minVersion` is non-null, else `"any"`.
   - `comment`: the tool's `purpose`.
4. For each constructed prerequisite Package, add a Relationship: `{ "spdxElementId": "SPDXRef-Package-kusari-plugin", "relatedSpdxElement": "SPDXRef-Prereq-<name>", "relationshipType": "HAS_PREREQUISITE" }`.
5. Also read `plugins/kusari/.mcp.json` and emit a HAS_PREREQUISITE for any MCP server `command` that is NOT already covered by `prerequisites.json` (this captures MCP-server commands that happen not to be invoked by plugin shell scripts directly).
6. Merge the prerequisite Packages and Relationships into the syft-produced SBOM, update `creationInfo.comment` per the release-artifact-shape contract, and write the final `sbom.spdx.json`.

The generator MUST NOT hand-author any Package or Relationship data not derivable from `prerequisites.json`, `.mcp.json`, or syft's output.

## Invariants (cross-consumer)

- **Source-of-truth invariant**: the set of external runtime tools the plugin requires equals the set of entries in `prerequisites.json`. Adding a new tool invocation to plugin code without adding an entry here causes the install-time check to not enforce the requirement, which surfaces as a missing-tool failure on a user's machine — a *discoverable* drift. Removing an entry without removing the corresponding invocation from plugin code causes the install check to pass while the plugin is incomplete at runtime — this is caught by plugin-level integration tests.
- **SBOM-alignment invariant**: the SBOM's `HAS_PREREQUISITE` relationships exactly mirror `prerequisites.json` (plus any `.mcp.json`-derived additions). The release workflow's validation step `validate-release.sh` does not itself re-check this — the generator is the single producer, so by construction the SBOM reflects the file.
- **Schema-stability invariant**: adding new optional fields to tool entries is backward compatible. Adding new required fields is a breaking change to this contract and requires a spec revision.

## Test coverage contract

`tests/release/test-prerequisites-declaration.sh` MUST cover:

- A valid `prerequisites.json` with multiple tools — schema parses, check passes for installed tools, check fails cleanly for missing tools.
- Version comparison: `minVersion` satisfied vs. not satisfied.
- `versionCommand` default behavior vs. override behavior.
- Unparseable version output — the check emits a warning and continues without failing on parse issue alone.
- Missing required field in a tool entry — the consumer scripts fail with a clear schema-error message.
- Duplicate `name` within `tools[]` — rejected at parse time.
