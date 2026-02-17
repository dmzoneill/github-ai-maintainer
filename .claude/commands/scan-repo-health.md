---
description: Scan dmzoneill repos for health issues across 6 categories — README/docs, license, workflows, community files, git hygiene, and CI/CD maintenance
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Bash(gh:*), Bash(git:*), Bash(curl:*), Bash(python:*)
---

# Repo Health Scanner

Scan GitHub repos for health issues across 6 maintenance categories. This is the discovery scanner that feeds repo health work into the swarm.

If `$ARGUMENTS` is provided and is not "all", scope to that single repo. Otherwise scan all repos.

## Rate Limit Check

```bash
gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit)"'
```
If remaining < 500, stop and report. Do not proceed.

## 1. Get Repo List

For all repos:
```bash
gh repo list dmzoneill --limit 200 --json name,primaryLanguage,isArchived -q '.[] | select(.isArchived == false) | [.name, (.primaryLanguage.name // "none")] | @tsv'
```

For a single repo: scope to just `$ARGUMENTS`.

## 2. Per-Repo Health Checks

For each repo, run these lightweight API checks. Check rate limit every 20 repos — if < 300 remaining, stop and report what was scanned so far.

### README & Documentation

```bash
gh api repos/dmzoneill/{repo}/readme --jq '.size' 2>&1
```
- If 404: **high** severity — no README
- If size < 500 bytes: **medium** severity — suspiciously short README
- Otherwise: fetch content and check for CI badge:
  ```bash
  gh api repos/dmzoneill/{repo}/readme --jq '.content' | base64 -d | grep -c 'badge'
  ```
  If no badge found: **medium** severity — missing badges

### License Compliance

```bash
gh api repos/dmzoneill/{repo}/license --jq '.license.spdx_id' 2>&1
```
- If 404: **high** severity — no LICENSE file
- If `NOASSERTION`: **medium** severity — unrecognized license

### Community Health

```bash
gh api repos/dmzoneill/{repo}/community/profile --jq '{health: .health_percentage, missing: [.files | to_entries[] | select(.value == null) | .key]}'
```
- If health_percentage < 50: **low** severity — multiple community files missing
- List missing files for the skill to create

### Workflow Maintenance

Fetch the main.yml (if it exists) and check for outdated action versions:
```bash
gh api "repos/dmzoneill/{repo}/contents/.github/workflows/main.yml" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null
```

Also check for any custom workflow files:
```bash
gh api "repos/dmzoneill/{repo}/contents/.github/workflows" --jq '.[].name' 2>/dev/null
```

For custom workflows (not main.yml), fetch and grep for outdated patterns:
- `checkout@v3` or older
- `setup-python@v4` or older
- `ubuntu-18.04`, `ubuntu-20.04`, `macos-11`, `macos-12`

If outdated actions found: **medium** severity

### Git Hygiene

Check for .gitignore:
```bash
gh api "repos/dmzoneill/{repo}/contents/.gitignore" --jq '.size' 2>&1
```
- If 404: **medium** severity — no .gitignore

Check branch count:
```bash
gh api repos/dmzoneill/{repo}/branches --jq 'length'
```
- If > 5 branches: **low** severity — potential stale branches

### CI/CD Maintenance

Check recent failure rate (last 5 runs):
```bash
gh api "repos/dmzoneill/{repo}/actions/runs?per_page=5&branch=main" --jq '[.workflow_runs[].conclusion] | {total: length, failures: [.[] | select(. == "failure")] | length}'
```
- If >50% failure rate: **high** severity — chronic CI failure
- If >0% but <=50%: **low** severity — intermittent failures

Check for old artifacts:
```bash
gh api repos/dmzoneill/{repo}/actions/artifacts --jq '.total_count'
```
- If > 20 artifacts: **low** severity — potential cleanup needed

## 3. Build Results

Compile all findings into a structured JSON array. For each finding:
```json
{
  "repo": "dmzoneill/{repo}",
  "category": "readme-docs|license-compliance|workflow-maintenance|docs-health|git-hygiene|cicd-maintenance",
  "severity": "high|medium|low",
  "detail": "description of the issue",
  "suggested_skill": "/readme-docs|/license-compliance|/workflow-maintenance|/docs-health|/git-hygiene|/cicd-maintenance"
}
```

## 4. Output Summary

Display results grouped by severity:

```
=== REPO HEALTH SCAN ===
Repos scanned: N
Rate limit remaining: N

HIGH SEVERITY (action required):
| Repo | Category | Detail | Skill |
|------|----------|--------|-------|
| repo-a | license | No LICENSE file | /license-compliance |
| repo-b | readme | No README | /readme-docs |
| repo-c | cicd | 80% failure rate | /cicd-maintenance |

MEDIUM SEVERITY (should fix):
| Repo | Category | Detail | Skill |
|------|----------|--------|-------|
| repo-d | readme | Missing CI badge | /readme-docs |
| repo-e | git-hygiene | No .gitignore | /git-hygiene |
| repo-f | workflow | Outdated actions | /workflow-maintenance |

LOW SEVERITY (nice to have):
| Repo | Category | Detail | Skill |
|------|----------|--------|-------|
| repo-g | docs-health | 30% community score | /docs-health |
| repo-h | git-hygiene | 8 branches | /git-hygiene |

Totals: N high, N medium, N low across N repos
```

Also output the raw JSON array for programmatic consumption by the swarm.
