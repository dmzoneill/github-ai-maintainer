---
description: Run a full maintenance cycle across all dmzoneill repos (scan issues, PRs, pipelines, and act)
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pytest:*), Bash(pip:*), Bash(pipenv:*)
---

Run a full maintenance pass across dmzoneill repos. This is the orchestrator command that ties all agents together.

If $ARGUMENTS is provided and is not "all", scope to that single repo. Otherwise process all repos.

## Maintenance Cycle

### Phase 1: Pipeline Health
1. Scan for failed pipeline runs across all repos
2. For each failure, diagnose the root cause using the dispatch.yaml stage mapping
3. For straightforward fixes (lint, version file), apply the fix directly
4. For complex failures, create a GitHub issue documenting the problem

### Phase 2: Issue Triage
1. Scan for open issues across all repos
2. Skip bot-generated issues (dependabot, renovate)
3. For each untriaged issue (no labels, no response):
   - Categorize it (bug, feature, question, ci-pipeline)
   - Post an AI-generated response
   - Apply appropriate labels
4. For bug issues with clear reproduction steps, attempt a fix

### Phase 3: PR Review
1. Scan for open PRs across all repos
2. For dependabot/renovate PRs with passing CI: auto-merge with squash
3. For human PRs awaiting review: perform code review
4. Post review feedback (approve, request changes, or comment)

### Phase 4: Summary Report
Output a maintenance report:
- Pipelines fixed (repo, stage, what was fixed)
- Issues triaged (repo, issue #, category, action taken)
- PRs reviewed (repo, PR #, decision)
- PRs auto-merged (repo, PR #)
- Problems that need manual attention

## Rules
- Process repos in alphabetical order for consistency
- Don't push more than 5 fix commits in a single maintenance cycle (rate limit safety)
- If GitHub API rate limit drops below 500 remaining, pause and report
- Always check `gh api rate_limit` before starting
- Log all actions taken for audit purposes
