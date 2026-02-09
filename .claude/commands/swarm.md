---
description: Launch the full agent swarm — all agents work in parallel across all repos until everything is clean
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pytest:*), Bash(pip:*), Bash(pipenv:*), Bash(black:*), Bash(curl:*), Bash(ls:*), Bash(mkdir:*), Task
---

# GitHub AI Maintainer — Full Swarm

You are the Orchestrator. You manage a swarm of parallel agents that maintain all dmzoneill GitHub repos simultaneously.

## Startup

1. Check API rate limit first:
```bash
gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit)"'
```
If remaining < 500, stop and report. Do not proceed.

2. Read the swarm state file if it exists:
```bash
cat ~/src/github-ai-maintainer/.claude/.swarm-state.json 2>/dev/null || echo "{}"
```
This tracks what has already been processed to avoid duplicate work across ralph-loop iterations.

## Phase 0: Repo Config (pre-flight)

Launch a Task agent to enforce CI/CD configuration rules across all repos before scanning for failures. This prevents known-broken configurations from generating noise.

**Agent 0 — Repo Config**: For ALL repos that have `.github/workflows/main.yml`, check and fix dispatch input toggles:
1. Get all repos: `gh repo list dmzoneill --limit 200 --json name -q '.[].name'`
2. For each repo, fetch main.yml: `gh api "repos/dmzoneill/{repo}/contents/.github/workflows/main.yml" --jq '.content' | base64 -d`
3. Apply current rules:
   - If `flatpak-build: "true"` → change to `flatpak-build: "false"` (broken upstream action reference until dispatch.yaml is fixed)
4. Clone, commit, push any changes with message: `fix: disable flatpak-build (broken upstream action reference)`
5. Return a list of repos modified

Wait for this to complete before Phase 1, as it may fix some pipeline failures.

## Phase 1: Discovery (parallel scans)

Launch THREE Task agents in parallel to scan for all work across all repos:

**Agent 1 — Pipeline Scanner**: Find ALL repos where the most recent CI/CD run on the default branch is failing. This is critical — the CI badge reflects the latest run, so a repo pushed months ago still shows a red badge if its last run failed. Steps:
1. Get ALL repos: `gh repo list dmzoneill --limit 200 --json name -q '.[].name'`
2. For EACH repo, check the latest run: `gh api repos/dmzoneill/{repo}/actions/runs?per_page=1&branch=main --jq '.workflow_runs[0] | {id, conclusion, created_at}'`
3. If `conclusion == "failure"`, get the failed job and extract error lines from logs
4. Categorize: auto-fixable (lint, version file), config fix (broken action refs), needs investigation (tests, publish), upstream issue (third-party action removed)
5. Return a JSON array of `{repo, run_id, job_name, error_summary, category}`

**Agent 2 — Issue Scanner**: Find all open issues across dmzoneill repos that haven't been responded to by the dmzoneill user. Use `gh api search/issues`. Skip dependabot/renovate/bot issues. Return a JSON array of `{repo, issue_number, title, category, has_response}`.

**Agent 3 — PR Scanner**: Find all open PRs across dmzoneill repos. Use `gh api search/issues` with `is:pr`. Identify dependabot PRs with passing CI. Return a JSON array of `{repo, pr_number, title, author, is_bot, ci_status}`.

Wait for all three to complete.

## Phase 2: Triage

From the discovery results, build a prioritized work queue:

**Priority 1 — Pipeline fixes** (broken CI blocks everything):
- Group failures by stage (lint, test, bump, publish)
- Sort by: lint fixes first (usually quick), then test, then publish

**Priority 2 — Dependabot auto-merges** (low risk, high value):
- PRs from dependabot/renovate with passing CI → auto-merge

**Priority 3 — Issue triage** (respond to humans):
- Untriaged issues without responses → categorize and respond

**Priority 4 — PR review** (human PRs needing review):
- Non-bot PRs awaiting review → code review

## Phase 3: Execution (parallel agents)

Launch Task agents in parallel, up to 5 at a time, for the prioritized work:

For **pipeline fixes**: Each agent gets one repo+run_id. It should:
1. Fetch job logs via `gh api`
2. Identify the dispatch.yaml stage that failed
3. Clone/pull the repo to `~/src/{repo}`
4. For lint failures: run the appropriate formatter and push a fix commit
5. For test failures: analyze the error, attempt a fix if straightforward, otherwise create an issue
6. For publish failures: check version/credentials and create an issue if not fixable
7. Return `{repo, stage, action_taken, success}`

For **dependabot auto-merges**: Each agent gets one repo+PR. It should:
1. Verify CI is passing: `gh pr checks {number} -R dmzoneill/{repo}`
2. Check for merge conflicts: `gh pr view {number} -R dmzoneill/{repo} --json mergeable --jq '.mergeable'`
3. If mergeable == "CONFLICTING": close the PR with a comment explaining the merge conflict. Dependabot will recreate if needed.
4. If all checks pass and mergeable: `gh pr merge {number} -R dmzoneill/{repo} --squash` (try --auto --squash first, fall back to --squash)
5. Return `{repo, pr_number, merged, closed_conflict}`

For **issue triage**: Each agent gets one repo+issue. It should:
1. Fetch the issue content
2. Read the repo's README.md or CLAUDE.md for context
3. Categorize (bug/feature/question/ci)
4. Generate a concise, helpful response
5. Post the response: `gh issue comment {number} -R dmzoneill/{repo} --body "response"`
6. Apply label: `gh issue edit {number} -R dmzoneill/{repo} --add-label "{category}"`
7. Return `{repo, issue_number, category, action_taken}`

For **PR reviews**: Each agent gets one repo+PR. It should:
1. Fetch the diff: `gh pr diff {number} -R dmzoneill/{repo}`
2. Review for correctness, security, style
3. Post review: `gh pr review {number} -R dmzoneill/{repo} --comment --body "review"`
4. Return `{repo, pr_number, decision}`

## Phase 4: Update State

After all agents complete, update the swarm state file:
```bash
cat > ~/src/github-ai-maintainer/.claude/.swarm-state.json << 'STATEEOF'
{
  "last_run": "$(date -Iseconds)",
  "pipelines_fixed": [...],
  "issues_triaged": [...],
  "prs_merged": [...],
  "prs_reviewed": [...],
  "remaining_work": [...]
}
STATEEOF
```

## Phase 5: Report

Output a summary:

```
=== SWARM MAINTENANCE REPORT ===

Pipelines:  X fixed / Y remaining
Issues:     X triaged / Y remaining
PRs merged: X (dependabot)
PRs reviewed: X

Actions taken:
- [repo] fixed lint failure (black formatting)
- [repo] triaged issue #N as bug, posted response
- [repo] auto-merged dependabot PR #N
...

Remaining work (needs manual attention):
- [repo] test failure requires refactor (issue #N created)
...
```

## Completion Check

If there is NO remaining work (no failed pipelines, no untriaged issues, no unreviewed PRs):

<promise>I DONE DID IT - ALL REPOS ARE MAINTAINED AND I'M HELPING</promise>

If there IS remaining work, do NOT output the promise tag. The ralph loop will re-run this command and pick up where we left off using the state file.

## Safety Rails

- Never push more than 10 fix commits per iteration
- Never auto-merge non-bot PRs
- If rate limit drops below 200 during execution, stop and save state
- Never modify dispatch.yaml (lives in profile repo)
- Use conventional commit messages: `fix:`, `feat:`, `chore:`
- Track everything in the state file so the next iteration doesn't redo work
