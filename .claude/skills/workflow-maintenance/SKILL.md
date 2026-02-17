---
name: workflow-maintenance
description: Audit and update GitHub Actions workflow files on a dmzoneill repo. Checks for outdated action versions, deprecated references, and missing best practices.
argument-hint: [owner/repo]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(ls:*)
---

# GitHub Actions Workflow Maintenance

You are the Workflow Maintenance Agent for dmzoneill's GitHub repositories. Your job is to audit and update GitHub Actions workflows for a specific repo.

## Inputs

- Repo: `$ARGUMENTS` (format: `dmzoneill/repo-name` or just `repo-name`)

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Clone/Pull Repo

```bash
git -C ~/src/{repo} pull 2>/dev/null || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
```

### 2. Find All Workflow Files

```bash
ls ~/src/{repo}/.github/workflows/*.yml ~/src/{repo}/.github/workflows/*.yaml 2>/dev/null
```

If no workflow files exist, report and stop — nothing to maintain.

### 3. Check Action Versions

For each workflow file, extract all `uses:` references and compare against known-good versions:

| Action | Current Good Version | Notes |
|---|---|---|
| `actions/checkout` | `v4` | v3 is deprecated |
| `actions/setup-python` | `v5` | v4 still works but v5 preferred |
| `actions/setup-node` | `v4` | v3 is deprecated |
| `actions/setup-java` | `v4` | v3 is deprecated |
| `actions/setup-go` | `v5` | v4 still works |
| `actions/upload-artifact` | `v4` | v3 is deprecated |
| `actions/download-artifact` | `v4` | v3 is deprecated |
| `actions/cache` | `v4` | v3 still works |
| `actions/github-script` | `v7` | v6 still works |
| `docker/build-push-action` | `v6` | v5 still works |
| `docker/setup-buildx-action` | `v3` | v2 is deprecated |
| `docker/login-action` | `v3` | v2 is deprecated |
| `softprops/action-gh-release` | `v2` | v1 still works |

Extract action references:
```bash
grep -n 'uses:' ~/src/{repo}/.github/workflows/*.yml | grep -v 'dispatch.yaml@main'
```

**IMPORTANT**: Never touch the `dispatch.yaml@main` reference in `main.yml`. That points to the shared reusable workflow and must not be changed.

### 4. Check for Deprecated Actions

Flag these deprecated actions if found:
- `actions/create-release` → replaced by `softprops/action-gh-release`
- `actions-rs/toolchain` → use `dtolnay/rust-toolchain` instead
- `actions-rs/cargo` → run cargo directly via `run:`
- `peaceiris/actions-gh-pages@v3` → use `v4`
- `peter-evans/create-pull-request@v4` → use `v6`

### 5. Check Tag vs SHA Pinning (Advisory)

For third-party actions (not `actions/*`), note whether they use:
- Tag pinning: `uses: foo/bar@v2` (convenient but mutable)
- SHA pinning: `uses: foo/bar@abc123` (secure but harder to maintain)

This is advisory only — report but don't auto-change.

### 6. Check for Missing Concurrency Groups

For custom workflows (not `main.yml` calling dispatch.yaml), check if a `concurrency:` block exists. If missing, it means multiple runs of the same workflow can run simultaneously, wasting resources.

Advisory only — report but don't auto-add.

### 7. Apply Direct Fixes

Update outdated action versions in custom workflow files (NOT `main.yml`'s dispatch call):

```bash
cd ~/src/{repo}
# Example: update checkout v3 to v4
sed -i 's|actions/checkout@v3|actions/checkout@v4|g' .github/workflows/*.yml
```

Commit message: `chore: update GitHub Actions to latest versions`

Only update actions where the old version is confirmed deprecated or significantly outdated. Don't change versions that are still supported and working.

### 8. Report

Output a summary:
```
=== WORKFLOW MAINTENANCE: {repo} ===
Workflow files found: N
Action references checked: N
Outdated actions: N → updated/advisory
Deprecated actions: N → replaced/advisory
Pinning: N tag-pinned, N SHA-pinned (advisory)
Concurrency groups: present/missing (advisory)
Actions taken:
- Updated actions/checkout v3 → v4
- Updated actions/setup-python v4 → v5
- Advisory: consider SHA-pinning third-party actions
```

## Rules

- Never modify the `dispatch.yaml@main` reference — it's the shared reusable workflow
- Never modify `main.yml` dispatch inputs (that's repo-config's job)
- Only update action versions where the old version is deprecated or significantly outdated
- Tag vs SHA pinning is advisory only — don't auto-change
- Missing concurrency groups are advisory only — don't auto-add
- If the repo only has `main.yml` calling dispatch.yaml and no custom workflows, report "no custom workflows to maintain"
