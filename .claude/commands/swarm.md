---
description: Launch the full agent swarm — all agents work in parallel across all repos until everything is clean
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pytest:*), Bash(pip:*), Bash(pipenv:*), Bash(black:*), Bash(curl:*), Bash(ls:*), Bash(mkdir:*), Task
---

# GitHub Maintainer — Full Swarm

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

Launch FOUR Task agents in parallel to scan for all work across all repos:

**Agent 1 — Pipeline Scanner**: Find ALL repos where the most recent CI/CD run on the default branch is failing. This is critical — the CI badge reflects the latest run, so a repo pushed months ago still shows a red badge if its last run failed. Steps:
1. Get ALL repos: `gh repo list dmzoneill --limit 200 --json name -q '.[].name'`
2. For EACH repo, check the latest run: `gh api repos/dmzoneill/{repo}/actions/runs?per_page=1&branch=main --jq '.workflow_runs[0] | {id, conclusion, created_at}'`
3. If `conclusion == "failure"`, get the failed job and extract error lines from logs
4. Categorize: auto-fixable (lint, version file), config fix (broken action refs), needs investigation (tests, publish), upstream issue (third-party action removed)
5. Return a JSON array of `{repo, run_id, job_name, error_summary, category}`

**Agent 2 — Issue Scanner**: Find all open issues across dmzoneill repos that haven't been responded to by the dmzoneill user. Use `gh api search/issues`. Skip dependabot/renovate/bot issues. Return a JSON array of `{repo, issue_number, title, category, has_response}`.

**Agent 3 — PR Scanner**: Find all open PRs across dmzoneill repos. Use `gh api search/issues` with `is:pr`. Identify dependabot PRs with passing CI. Return a JSON array of `{repo, pr_number, title, author, is_bot, ci_status}`.

**Agent 4 — Repo Health Scanner**: Scan all repos for health issues across 6 categories: README/docs, license compliance, workflow maintenance, community health files, git hygiene, and CI/CD maintenance. For each repo, run lightweight API checks:
1. Get ALL repos: `gh repo list dmzoneill --limit 200 --json name,primaryLanguage,isArchived -q '.[] | select(.isArchived == false) | .name'`
2. For EACH repo, check:
   - README exists and has badges: `gh api repos/dmzoneill/{repo}/readme --jq '.size'`
   - LICENSE exists: `gh api repos/dmzoneill/{repo}/license --jq '.license.spdx_id'`
   - Community health score: `gh api repos/dmzoneill/{repo}/community/profile --jq '{health: .health_percentage, missing: [.files | to_entries[] | select(.value == null) | .key]}'`
   - Workflow action versions: fetch custom workflow files, grep for outdated `checkout@v3`, `setup-python@v4`, deprecated runners
   - .gitignore exists: `gh api repos/dmzoneill/{repo}/contents/.gitignore --jq '.size'`
   - CI failure rate (last 5 runs): `gh api repos/dmzoneill/{repo}/actions/runs?per_page=5&branch=main --jq '[.workflow_runs[].conclusion]'`
3. Check rate limit every 20 repos — stop if < 300 remaining
4. Classify each finding by severity: **high** (missing README/LICENSE, chronic CI failure >50%), **medium** (missing badges, outdated actions, no .gitignore), **low** (missing community files, stale branches, old artifacts)
5. Return a JSON array of `{repo, category, severity, detail, suggested_skill}`

Wait for all four to complete.

## Phase 2: Triage

From the discovery results, build a prioritized work queue:

**Priority 1 — Pipeline fixes** (broken CI blocks everything):
- Group failures by stage (lint, test, bump, publish)
- Sort by: lint fixes first (usually quick), then test, then publish

**Priority 2 — Dependabot auto-merges** (low risk, high value):
- PRs from dependabot/renovate with passing CI → auto-merge

**Priority 3 — High-severity repo health** (critical gaps):
- Missing README → `/readme-docs` skill
- Missing LICENSE → `/license-compliance` skill
- Chronic CI failure (>50% of last runs) → `/cicd-maintenance` skill

**Priority 4 — Issue triage** (respond to humans):
- Untriaged issues without responses → categorize and respond

**Priority 5 — PR review** (human PRs needing review):
- Non-bot PRs awaiting review → code review

**Priority 6 — Medium/low-severity repo health** (improvement work):
- Missing CI badges → `/readme-docs` skill
- Outdated action versions → `/workflow-maintenance` skill
- Missing .gitignore → `/git-hygiene` skill
- Stale branches → `/git-hygiene` skill
- Missing community health files → `/docs-health` skill
- Old artifacts → `/cicd-maintenance` skill
- License metadata mismatches → `/license-compliance` skill

Limit repo health work to 15 repos per iteration to avoid overwhelming the system.

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

For **repo health fixes (high severity)**: Each agent gets one repo+category. It should:
1. Clone/pull the repo to `~/src/{repo}`
2. For missing README: create a basic README with repo description, CI badge, license badge, and standard sections
3. For missing LICENSE: add MIT license (dmzoneill's default) with copyright holder "Dave O'Neill"
4. For chronic CI failure: analyze failure pattern, create an issue with diagnosis if one doesn't already exist
5. Commit and push any file additions
6. Return `{repo, category, action_taken, success}`

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

For **repo health fixes (medium/low severity)**: Each agent gets one repo + list of findings. Batch related fixes per repo into minimal commits:
1. Clone/pull the repo to `~/src/{repo}`
2. For missing CI badges: add badge to top of README → `docs: fix README badges`
3. For outdated action versions: update in custom workflow files (NOT main.yml dispatch call) → `chore: update GitHub Actions to latest versions`
4. For missing .gitignore: create language-appropriate .gitignore → `chore: add .gitignore for {language}`
5. For stale branches: delete merged branches via API (NEVER delete main/master/develop/dev/gh-pages)
6. For missing community files: add CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CODEOWNERS, .editorconfig, issue/PR templates → `chore: add community health files`
7. For old artifacts: delete via API (no commit needed)
8. For license metadata mismatches: create an issue (don't auto-fix metadata)
9. Return `{repo, fixes_applied: [{category, detail}], issues_created: [...]}`

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
  "repo_health_fixed": [...],
  "repo_health_remaining": [...],
  "remaining_work": [...]
}
STATEEOF
```

The `repo_health_fixed` array tracks repos where health fixes were applied (with category and detail). The `repo_health_remaining` array tracks findings that weren't addressed in this iteration (for the next ralph-loop pass).

## Phase 5: Report

Output a summary:

```
=== SWARM MAINTENANCE REPORT ===

Pipelines:    X fixed / Y remaining
Issues:       X triaged / Y remaining
PRs merged:   X (dependabot)
PRs reviewed: X
Repo health:  X repos fixed / Y remaining

Repo health breakdown:
  READMEs fixed:        N
  Licenses added:       N
  Workflows updated:    N
  Health files added:   N
  .gitignore fixed:     N
  Branches deleted:     N
  Artifacts cleaned:    N

Actions taken:
- [repo] fixed lint failure (black formatting)
- [repo] triaged issue #N as bug, posted response
- [repo] auto-merged dependabot PR #N
- [repo] added MIT LICENSE file
- [repo] added community health files (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY)
- [repo] updated actions/checkout v3 → v4
- [repo] deleted 3 merged branches
- [repo] cleaned 12 old artifacts (45 MB reclaimed)
...

Remaining work (needs manual attention):
- [repo] test failure requires refactor (issue #N created)
- [repo] license mismatch between LICENSE and pyproject.toml (issue #N created)
...
```

## Completion Check

If there is NO remaining work (no failed pipelines, no untriaged issues, no unreviewed PRs, no repo health findings):

<promise>I DONE DID IT - ALL REPOS ARE MAINTAINED AND I'M HELPING</promise>

If there IS remaining work, do NOT output the promise tag. The ralph loop will re-run this command and pick up where we left off using the state file.

## Safety Rails

- Never push more than 10 fix commits per iteration
- Never auto-merge non-bot PRs
- If rate limit drops below 200 during execution, stop and save state
- Never modify dispatch.yaml (lives in profile repo)
- Use conventional commit messages: `fix:`, `feat:`, `chore:`
- Track everything in the state file so the next iteration doesn't redo work
- Never delete protected branches (main, master, develop, dev, gh-pages)
- Never overwrite existing community files — only create files that are missing
- Never change an existing LICENSE file — create an issue for mismatches
- Limit repo health fixes to 15 repos per iteration
