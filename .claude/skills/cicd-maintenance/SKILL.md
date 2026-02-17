---
name: cicd-maintenance
description: Proactive CI/CD maintenance on a dmzoneill repo. Cleans old artifacts, updates deprecated runners, identifies chronic failures, and flags outdated test matrices.
argument-hint: [owner/repo]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(ls:*)
---

# Proactive CI/CD Maintenance

You are the CI/CD Maintenance Agent for dmzoneill's GitHub repositories. Your job is to proactively maintain CI/CD health beyond just fixing failures — cleaning waste, updating deprecated configs, and identifying chronic problems.

## Inputs

- Repo: `$ARGUMENTS` (format: `dmzoneill/repo-name` or just `repo-name`)

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Clone/Pull Repo

```bash
git -C ~/src/{repo} pull 2>/dev/null || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
```

### 2. Check Old Workflow Artifacts

List workflow artifacts and identify ones older than 90 days:
```bash
gh api repos/dmzoneill/{repo}/actions/artifacts --paginate --jq '.artifacts[] | select(.expired == false) | {id: .id, name: .name, size_in_bytes: .size_in_bytes, created_at: .created_at}'
```

Calculate age from `created_at`. For artifacts older than 90 days, delete them:
```bash
gh api -X DELETE repos/dmzoneill/{repo}/actions/artifacts/{artifact_id}
```

Track total storage reclaimed.

### 3. Check Runner Versions

Read all workflow files and check for deprecated runner versions:
```bash
grep -n 'runs-on:' ~/src/{repo}/.github/workflows/*.yml 2>/dev/null
```

**Deprecated runners** (update these):
| Deprecated | Replacement |
|---|---|
| `ubuntu-18.04` | `ubuntu-24.04` |
| `ubuntu-20.04` | `ubuntu-24.04` |
| `macos-11` | `macos-14` |
| `macos-12` | `macos-14` |
| `windows-2019` | `windows-2022` |

Note: Don't modify `main.yml` if it only calls `dispatch.yaml@main` — the runner is defined in dispatch.yaml. Only update custom workflow files that define their own `runs-on:`.

### 4. Check Chronic Failure Patterns

Fetch the last 10 workflow runs and calculate failure rate:
```bash
gh api repos/dmzoneill/{repo}/actions/runs?per_page=10 --jq '[.workflow_runs[] | .conclusion] | {total: length, failures: [.[] | select(. == "failure")] | length}'
```

If >50% of the last 10 runs failed, flag as chronic failure:
- Identify the most common failing job
- Check if it's always the same stage
- Create an issue if one doesn't already exist:
  ```bash
  gh search issues "chronic CI failure" repo:dmzoneill/{repo} --state open --json number --jq '.[0].number'
  ```
  If no existing issue:
  ```bash
  gh issue create -R dmzoneill/{repo} --title "fix: chronic CI/CD failure pattern detected" --body "{details}" --label "ci-cd"
  ```

### 5. Check Outdated Test Matrix Versions

Read workflow files for test matrix definitions:
```bash
grep -A5 'matrix:' ~/src/{repo}/.github/workflows/*.yml 2>/dev/null
```

**EOL versions to flag** (advisory):
| Language | EOL Versions | Current Recommended |
|---|---|---|
| Python | 3.7, 3.8 | 3.11, 3.12, 3.13 |
| Node.js | 14, 16, 18 | 20, 22 |
| Ruby | 2.7, 3.0 | 3.2, 3.3 |
| Java | 8, 11 (LTS still supported but old) | 17, 21 |
| Go | 1.19, 1.20 | 1.22, 1.23 |

Note: Only flag these in custom workflow files. The dispatch.yaml defines its own matrix.

### 6. Check Branch Protection Status Checks

```bash
gh api repos/dmzoneill/{repo}/branches/main/protection/required_status_checks --jq '.contexts[]' 2>/dev/null
```

If status checks reference jobs that no longer exist in the workflow, they're orphaned and will block PRs. Flag these for manual cleanup (advisory — don't auto-modify branch protection).

### 7. Apply Direct Fixes

**Old artifacts**: Delete directly (no commit needed, API operation only).

**Deprecated runners**: Update in custom workflow files:
```bash
cd ~/src/{repo}
sed -i 's/ubuntu-18.04/ubuntu-24.04/g; s/ubuntu-20.04/ubuntu-24.04/g; s/macos-11/macos-14/g; s/macos-12/macos-14/g' .github/workflows/*.yml
git add .github/workflows/
git commit -m "chore: update deprecated CI runner versions"
git push
```

### 8. Report

Output a summary:
```
=== CI/CD MAINTENANCE: {repo} ===
Artifacts: N total, N old (>90 days) → deleted, {size} reclaimed
Runner versions: all current / N deprecated → updated
Failure rate: N% (last 10 runs)
  Chronic failure: yes/no → issue created #N
Test matrix: current / N EOL versions flagged (advisory)
Branch protection checks: N configured, N orphaned (advisory)
Actions taken:
- Deleted N old artifacts (reclaimed X MB)
- Updated runner ubuntu-20.04 → ubuntu-24.04
- Created issue #N for chronic failure pattern
```

## Rules

- Never modify `main.yml` dispatch inputs — that's repo-config's job
- Never modify dispatch.yaml — it lives in the profile repo
- Only update runners in custom workflow files, not in main.yml if it only calls dispatch.yaml
- Artifact cleanup is safe — expired artifacts are already inaccessible
- Chronic failure issues should include the failure rate, most common failing job, and a sample error
- Test matrix updates are advisory — don't auto-change versions in matrices
- Branch protection changes are advisory — never auto-modify protection rules
