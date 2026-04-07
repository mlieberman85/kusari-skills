---
name: "kusari-change-evaluate"
description: "Run a Kusari security scan on the current repository. Scans code and dependencies against a git revision, presenting health score, code mitigations, and dependency mitigations. Use when the user asks for a security scan, vulnerability check, or wants to evaluate code changes for security issues."
allowed-tools: Read, Bash, Glob
license: apache-2.0
compatibility: "Requires Kusari CLI v0.25.0+ or kusari-inspector MCP server. jq required for CLI fallback."
metadata:
  version: "1.0.0"
---

# Security Scan

You run a Kusari security scan on the current repository and present findings to the developer.

## Inputs

$ARGUMENTS

Optional git revision to compare against (e.g., `main`, `HEAD~5`, `abc1234`).
If empty, defaults to the repository's default branch.

## Supporting files

- Common utilities: [scripts/common.sh](scripts/common.sh)
- Scan orchestrator: [scripts/scan.sh](scripts/scan.sh)
- SARIF parser: [scripts/parse-sarif.sh](scripts/parse-sarif.sh)

---

## Step 1: Change to repository root

Change to the repository root before running any scripts:

```bash
cd "$(git rev-parse --show-toplevel)"
```

## Step 2: Determine the revision

- If `$ARGUMENTS` is provided and non-empty, use it as the revision.
- Otherwise, detect the default branch:

  ```bash
  source <skill_dir>/scripts/common.sh
  REVISION=$(detect_default_branch)
  ```

## Step 3: Attempt MCP scan first

Call the `mcp__kusari-inspector__scan_local_changes` tool with:
- `repo_path`: the repository root path (output of `git rev-parse --show-toplevel`)
- `base_ref`: the revision from step 2
- `output_format`: `"sarif"`

**If the MCP tool is unavailable** (tool not found, connection refused, or unreachable):
- Note the failure internally and proceed to step 4 (CLI fallback).

**If the MCP tool returns a scan-level error** (authentication failure, invalid repository, server-side error):
- Report the error directly to the developer. Include the error message from the MCP response.
- Do NOT fall back to CLI — the same underlying issue would likely affect the CLI path too.
- **Stop execution.**

**If the MCP tool succeeds and returns SARIF output**:
- Write the SARIF JSON response to a temporary file.
- Parse the results using the existing pipeline:

  ```bash
  export KUSARI_GIT_REVISION="<revision>"

  source <skill_dir>/scripts/parse-sarif.sh

  SARIF_TMP=$(mktemp "${TMPDIR:-/tmp}/kusari-mcp-sarif-XXXXXX.json")
  cat > "$SARIF_TMP" <<'SARIF_EOF'
  <paste the SARIF JSON response here>
  SARIF_EOF

  scan_json=$(parse_scan_result "$SARIF_TMP")
  code_mits_json=$(extract_code_mitigations "$SARIF_TMP")
  dep_mits_json=$(extract_dependency_mitigations "$SARIF_TMP")

  rm -f "$SARIF_TMP"

  echo "$scan_json"
  echo "$code_mits_json"
  echo "$dep_mits_json"
  ```

- Set `scan_method` to `"mcp"`.
- Skip step 4 and proceed to step 5.

## Step 4: CLI fallback

Only reached if the MCP tool was unavailable:

```bash
bash <skill_dir>/scripts/scan.sh $ARGUMENTS
```

Handle exit codes:
- **1** — prerequisite failure (missing git, kusari, or jq). The script already prints guidance.
- **2** — scan failure (auth, network, monorepo). The script already prints guidance.
- **3** — parse failure. Report the error and suggest retrying.

**If the CLI also fails with exit code 1** (kusari CLI not installed) AND the MCP tool was also unavailable:
- Report that no scanning method is available.
- Provide setup guidance for both options:
  - **MCP server**: "Configure the `kusari-inspector` MCP server in your Claude Code settings."
  - **CLI**: "Install the Kusari CLI and authenticate with `kusari auth login`. See https://github.com/kusaridev/kusari-cli."
- **Stop execution.**

On success, the script outputs a JSON object to stdout with: `scan`, `code_mitigations`, `dependency_mitigations`, `revision`.

- Set `scan_method` to `"cli"`.

## Step 5: Check for failed analysis

Check for `failed_analysis` in the `scan` object. If `true`, report that the Kusari Inspector encountered an error analyzing the code and suggest retrying.

## Step 6: Present findings

- Show which scan method was used: **"Scanned via MCP server"** or **"Scanned via CLI"**
- Show health score, status (Clean/Flagged/Error), and justification
- For each code mitigation: file path, line number, severity, description, and flagged code
- For each dependency mitigation: severity and description
- Include console URL if available
- Every finding must have an actionable next step
- Suggest `/kusari-change-fix` if there are code mitigations to apply
