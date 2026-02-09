---
description: Scan all dmzoneill repos for failed CI/CD pipeline runs
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Bash(gh:*), Bash(git:*), Bash(python:*)
---

Scan GitHub Actions workflow runs across dmzoneill repos for failures.

If $ARGUMENTS is provided and is not "all", scope to that single repo. Otherwise scan all repos.

## IMPORTANT: Check ALL repos, not just recently pushed ones

The CI badge reflects the most recent workflow run on the default branch. A repo pushed 3 months ago can still show a failing badge if its last run failed. You MUST check every repo, not just recently active ones.

1. Get ALL owned repos (not just recently pushed):
   - `gh repo list dmzoneill --limit 200 --json name,defaultBranchRef -q '.[].name'`
   - Single repo: scope to just `$ARGUMENTS`

2. For EACH repo, check the most recent workflow run on the default branch:
   - `gh api repos/dmzoneill/{repo}/actions/runs?per_page=1&branch=main --jq '.workflow_runs[0] | {id, name, conclusion, created_at}'`
   - If `conclusion` is "failure", this repo has a failing CI badge regardless of when it last ran
   - If no workflow runs exist, skip the repo

3. For each repo with a failing latest run, extract:
   - Repo name, run ID, workflow name, branch, failure date, commit SHA
   - The specific job that failed: `gh api repos/dmzoneill/{repo}/actions/runs/{run_id}/jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, id}'`

4. Map the failed job name to the dispatch.yaml pipeline stage:
   - "Lint" -> super-linter failure (check VALIDATE_* inputs)
   - "Run unit tests" / "Run integration tests" -> test failure
   - "Bump all versions" -> version file issue
   - "Create github release" -> tag/release conflict
   - "Pypi publish" / "Docker publish" / "Flatpak publish" / etc. -> publish failure
   - "Pipeline start/end" -> Redis notification issue

5. For each failure, fetch the job log:
   `gh api repos/dmzoneill/{repo}/actions/jobs/{job_id}/logs`
   Extract the relevant error lines (last 50 lines or grep for `##[error]`, `ERROR`, `FATAL`).

6. Categorize failures by fixability:
   - **Auto-fixable**: lint formatting, trailing whitespace, missing version file, type annotations
   - **Config fix**: broken action references (e.g. flatpak-github-actions@v1 not found), missing VALIDATE_* flags
   - **Needs investigation**: test failures, publish credential issues, complex build errors
   - **Upstream issue**: third-party action removed/renamed, external service down

7. Output a summary:
   | Repo | Run ID | Stage | Error Summary | Category | Suggested Fix |

8. For lint failures, suggest specific VALIDATE_* flags to disable or files to fix.
   For test failures, suggest running `make test` locally.
   For publish failures, check if credentials/version are the issue.
   For broken action references, identify the correct action version or replacement.
