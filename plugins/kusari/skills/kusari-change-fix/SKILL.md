---
name: "kusari-change-fix"
description: "Review and apply security mitigations from a Kusari scan result. Walks through code and dependency findings interactively, applying fixes with developer approval and enriching dependency mitigations with remediation guidance from Kusari Inspector."
allowed-tools: Read, Edit, Glob, Grep
license: apache-2.0
compatibility: "Requires kusari-inspector MCP server for enriched remediation guidance."
metadata:
  version: "1.0.0"
---

# Security Remediation

You walk through scan findings interactively, applying code fixes with developer approval and presenting enriched remediation guidance for dependency mitigations.

## Inputs

$ARGUMENTS

Optional additional context. Typically invoked after `/kusari-change-evaluate` with results already in the conversation.

---

## Step 1: Change to repository root

Change to the repository root before any file operations:

```bash
cd "$(git rev-parse --show-toplevel)"
```

## Step 2: Resolve software ID for vulnerability enrichment

> This step is optional — enrichment is additive.

Call the `mcp__kusari-inspector__get_software_ids_by_repo` tool with:
- `repo_path`: the repository root path (output of `git rev-parse --show-toplevel`)

**If the MCP tool is unavailable** (tool not found, connection refused, or unreachable):
- Note internally that enriched remediation guidance is unavailable.
- Proceed to step 4 (scan result processing) without enrichment.

**If the MCP tool returns an error** (authentication failure, server error):
- Note that enriched remediation is unavailable. If the error suggests authentication is needed, mention `kusari auth login`.
- Proceed to step 4 without enrichment.

**If the MCP tool returns an empty result** (repository not tracked):
- Note that this repository is not tracked in Kusari Inspector, so enriched remediation guidance is unavailable.
- Proceed to step 4 without enrichment.

**If the MCP tool returns a single software ID**:
- Auto-select that software ID for vulnerability lookups.

**If the MCP tool returns multiple software IDs**:
- Present the list to the developer and ask them to select which software component to use for vulnerability lookups.
- Cache the selected software ID for the remainder of this session.

## Step 3: Fetch vulnerability list for matching

> Only if software ID was resolved in step 2.

Call the `mcp__kusari-inspector__get_software_vulnerabilities` tool with:
- `software_id`: the selected software ID from step 2

**If the call succeeds**: Cache the vulnerability list (containing vuln IDs and summaries) for use in step 6.

**If the call fails or returns an error**: Note that enriched remediation is unavailable. Proceed without enrichment.

## Step 4: Locate scan results

Locate the scan results from the current conversation context. The scan output (from `/kusari-change-evaluate`) contains:
- Health Score and Status (Clean/Flagged/Error)
- Code Mitigations: each with file path, line number, severity, description, and flagged code
- Dependency Mitigations: each with severity and description

If no scan results are present in the conversation, tell the developer to run `/kusari-change-evaluate` first.

If the status is "Clean" or there are no mitigations, inform the developer and stop.

## Step 5: Process code mitigations

For each code mitigation, present it to the developer for review:
- Read the actual file at the indicated line to show current code context
- Show the severity, description, and suggested fix from the scan
- Ask the developer to **approve** or **skip**
- If approved, apply the fix using the Edit tool
- If the file is missing or the code has changed since the scan, skip with a warning

## Step 6: Process dependency mitigations

For each dependency mitigation, attempt to enrich with detailed remediation guidance:

**If a cached vulnerability list is available** (from step 3):
- For each dependency mitigation, try to match it to a known vulnerability:
  - Extract any CVE identifiers from the mitigation description (pattern: `CVE-YYYY-NNNNN`)
  - Match by package name or version mentioned in the description against vulnerability summaries
  - If a match is found (by CVE or by package/description similarity), call `mcp__kusari-inspector__get_software_vulnerability_by_id` with the matched `software_id` and `vuln_id`
  - **If the enrichment call succeeds**: Present an enriched view showing:
    - Severity and description (from the scan)
    - **Remediation Plan** (from the MCP response)
    - **Exploit Details** (from the MCP response)
    - **Step-by-Step Guidance** (from the MCP response)
  - **If the enrichment call fails**: Fall back to the scan-only view below
- If no match is found in the vulnerability list, present the scan-only view

**If no cached vulnerability list is available** (enrichment unavailable):
- Present the scan-only view: severity and description from the scan
- Note that enriched remediation guidance was unavailable for dependency mitigations

In all cases, note that dependency mitigations require manual resolution (package updates, replacements, or removals).

## Step 7: Summarize the session

- Code fixes: how many applied vs skipped, which files were modified
- Dependency items: how many reviewed, how many had enriched guidance vs scan-only
- Suggest running `/kusari-change-evaluate` to verify the fixes.
