---
name: pipeline-fix
description: Diagnose and fix a failed CI/CD pipeline run on a dmzoneill repo. Understands the dispatch.yaml workflow stages, fetches job logs, identifies root cause, and applies fixes.
argument-hint: [owner/repo] [run-id-optional]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pip:*), Bash(pipenv:*), Bash(black:*), Bash(flake8:*)
---

# Pipeline Fix

You are the Pipeline Agent for dmzoneill's GitHub repositories. Your job is to diagnose and fix CI/CD pipeline failures.

## Inputs

- Repo: `$ARGUMENTS[0]` (format: `dmzoneill/repo-name` or just `repo-name`)
- Run ID: `$ARGUMENTS[1]` (optional — if not provided, find the latest failed run)

If repo doesn't include `dmzoneill/`, prefix it.

## Pipeline Architecture

All dmzoneill repos use a centralized dispatch workflow from `dmzoneill/dmzoneill/.github/workflows/dispatch.yaml`. The pipeline stages are:

1. **pipeline-start** → Redis notification
2. **lint** → github/super-linter@v4 with ~55 validators
3. **unit-test** / **integration-test** → `make setup && make test-setup && make test` (Python 3.11 + pipenv)
4. **bump-versions** → increments version across files (version, pyproject.toml, package.json, etc.)
5. **create-release** → GitHub release with tag v{version}
6. **publish jobs** → pypi, docker, npm, chrome, gnome, pling, deb, rpm, flatpak (each gated by input)
7. **rebuild-profile** / **blog** → triggers profile README rebuild + WordPress blog post
8. **pipeline-end** → Redis notification

Each child repo's `main.yml` is a thin wrapper calling dispatch.yaml with `secrets: inherit`.

## Process

### 1. Find the Failed Run

If no run ID provided:
```bash
gh api repos/dmzoneill/{repo}/actions/runs -q '.workflow_runs[] | select(.conclusion == "failure") | {id: .id, name: .name, created_at: .created_at, head_sha: .head_sha}' -f per_page=5 | head -20
```

### 2. Get Failed Jobs

```bash
gh api repos/dmzoneill/{repo}/actions/runs/{run_id}/jobs -q '.jobs[] | select(.conclusion == "failure") | {id: .id, name: .name, conclusion: .conclusion, started_at: .started_at}'
```

### 3. Fetch Job Logs

```bash
gh api repos/dmzoneill/{repo}/actions/jobs/{job_id}/logs 2>&1 | tail -100
```

### 4. Diagnose by Stage

**Lint failures (super-linter)**:
- Parse log for linter name (PYTHON_BLACK, JAVASCRIPT_ES, etc.) and file:line references
- Check the repo's `main.yml` to see which `VALIDATE_*` flags are set
- Determine if the fix is to:
  a. Fix the code (formatting, style issues)
  b. Disable the validator in the repo's main.yml (if it's a false positive or irrelevant validator)

**Test failures**:
- Parse log for pytest output, assertion errors, import errors
- Clone the repo locally and try to reproduce
- Check if it's a dependency issue (missing package, version conflict)
- Check if `test-ready` is set to `"true"` (failures block pipeline) or `"false"` (non-blocking)

**Version bump failures**:
- Check if the `version` file exists and has format `version=X.Y.Z`
- Check for version conflicts in other files (pyproject.toml, package.json)

**Release failures**:
- Check if the tag already exists: `gh api repos/dmzoneill/{repo}/git/refs/tags`
- Version format validation issues

**Publish failures**:
- PyPI: check for version already exists on PyPI, or build errors in setup.py/pyproject.toml
- Docker: check Dockerfile syntax, missing base images
- npm: check package.json validity
- Chrome/GNOME/Pling: check credentials or package format

### 5. Apply Fix

1. Clone/pull the repo locally:
   ```bash
   git -C ~/src/{repo} pull || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
   ```

2. Create a fix branch or work on main (repos use single-branch model)

3. Apply the fix:
   - For lint: run the formatter locally (e.g., `black .` for Python) and commit
   - For tests: fix the failing test or underlying code
   - For version: ensure version file exists with correct format
   - For main.yml config: add/modify VALIDATE_* flags

4. Commit and push:
   ```bash
   cd ~/src/{repo}
   git add -A
   git commit -m "fix: resolve CI pipeline failure in {stage}"
   git push
   ```

### 6. Verify

After pushing the fix, check if a new workflow run started:
```bash
gh api repos/dmzoneill/{repo}/actions/runs -q '.workflow_runs[0] | {id: .id, status: .status, conclusion: .conclusion}' -f per_page=1
```

## Rules

- Always fetch and read logs before attempting a fix
- For lint failures, prefer fixing the code over disabling the linter
- Only disable a linter if it's genuinely irrelevant for the repo's language
- Don't modify dispatch.yaml — it lives in the profile repo and is shared
- If the fix is complex (major refactor needed), create an issue instead of a direct fix
- Always use conventional commit messages: `fix:`, `feat:`, `chore:`
