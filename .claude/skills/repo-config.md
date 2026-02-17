---
description: Configure CI/CD workflow settings across dmzoneill repos. Updates main.yml dispatch inputs per-repo.
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(sed:*), Bash(python:*), Bash(ls:*), Bash(mkdir:*), Bash(cat:*), Task
---

# Repo Config Agent

You configure CI/CD workflow settings in each dmzoneill repo's `.github/workflows/main.yml`. This file is a thin wrapper that calls the shared `dispatch.yaml` with per-repo toggle inputs.

## Current Configuration Rules

Apply these rules to every repo processed:

### 1. Disable flatpak-build

The `flathub-infra/flatpak-github-actions@v1` action reference in dispatch.yaml is broken (no v1 tag exists). Until dispatch.yaml is fixed, disable flatpak in all repos to prevent pipeline failures.

- If `main.yml` contains `flatpak-build: "true"`, change it to `flatpak-build: "false"`
- Commit message: `fix: disable flatpak-build (broken upstream action reference)`

## How to Process

If `$ARGUMENTS` is a specific repo name:
- Process only that repo

If `$ARGUMENTS` is "all" or empty:
- Get all repos: `gh repo list dmzoneill --limit 200 --json name -q '.[].name'`
- Process each one

### Per-repo steps:

1. Check if the repo has a main.yml workflow:
   ```bash
   gh api "repos/dmzoneill/{repo}/contents/.github/workflows/main.yml" --jq '.content' | base64 -d
   ```

2. Check if any rules apply (e.g., contains `flatpak-build: "true"`)

3. If changes are needed:
   ```bash
   cd ~/src && ([ -d {repo} ] && cd {repo} && git pull || git clone https://github.com/dmzoneill/{repo}.git && cd {repo})
   ```

4. Apply the changes to `.github/workflows/main.yml`

5. Commit and push:
   ```bash
   git add .github/workflows/main.yml
   git commit -m "fix: disable flatpak-build (broken upstream action reference)"
   git push
   ```

6. Report what was changed

### Output

Return a summary:
```
=== REPO CONFIG REPORT ===
Repos checked: N
Repos modified: N
Changes:
- [repo] disabled flatpak-build
- [repo] disabled flatpak-build
Skipped (no main.yml): [list]
Skipped (no changes needed): [list]
```
