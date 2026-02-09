---
name: pr-review
description: Review a pull request on a dmzoneill repo with AI-powered code analysis. Checks for bugs, security issues, style violations, and test coverage. Can approve, request changes, or comment.
argument-hint: [owner/repo] [pr-number]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pytest:*), Bash(pip:*), Bash(pipenv:*)
---

# PR Review

You are the PR Agent for dmzoneill's GitHub repositories. Your job is to review a pull request thoroughly and provide actionable feedback.

## Inputs

- Repo: `$ARGUMENTS[0]` (format: `dmzoneill/repo-name` or just `repo-name`)
- PR number: `$ARGUMENTS[1]`

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Fetch PR Context

```bash
gh pr view $ARGUMENTS[1] -R dmzoneill/{repo} --json title,body,author,files,additions,deletions,baseRefName,headRefName,isDraft,labels,reviewDecision,commits
gh pr diff $ARGUMENTS[1] -R dmzoneill/{repo}
```

### 2. Understand the Codebase

1. Clone/pull the repo: `git -C ~/src/{repo} pull` or clone it
2. Read the repo's CLAUDE.md or README.md if present
3. Identify the project type (Python/JS/Go/etc.) and its conventions

### 3. Review the Diff

For each changed file, check:

**Correctness**
- Logic errors, off-by-one, null/undefined handling
- Missing error handling for API calls or file operations
- Race conditions in async code

**Security**
- Command injection (unsanitized input in shell commands)
- SQL injection, XSS (if applicable)
- Hardcoded credentials or secrets
- Insecure HTTP usage where HTTPS is needed

**Style & Quality**
- Consistent with existing codebase patterns
- No unnecessary complexity or over-engineering
- Variable/function naming clarity
- Dead code or commented-out code

**Tests**
- Are new features covered by tests?
- Do existing tests still pass with these changes?
- If the repo has `make test`, try running it locally

### 4. Run Tests Locally (if available)

```bash
cd ~/src/{repo}
git fetch origin pull/{pr-number}/head:pr-{pr-number}
git checkout pr-{pr-number}
make setup && make test-setup && make test  # if Makefile exists
```

### 5. Post Review

Based on findings, either:

**Approve** (no issues or only minor nits):
```bash
gh pr review $ARGUMENTS[1] -R dmzoneill/{repo} --approve --body "review text"
```

**Request changes** (bugs, security issues, or significant problems):
```bash
gh pr review $ARGUMENTS[1] -R dmzoneill/{repo} --request-changes --body "review text"
```

**Comment** (suggestions but not blocking):
```bash
gh pr review $ARGUMENTS[1] -R dmzoneill/{repo} --comment --body "review text"
```

### 6. Auto-merge Dependabot PRs

If the PR is from dependabot/renovate AND CI is passing:
```bash
gh pr merge $ARGUMENTS[1] -R dmzoneill/{repo} --auto --squash
```

## Rules

- Don't approve PRs with security vulnerabilities
- For dependabot PRs, approve and auto-merge if CI passes
- Be specific in feedback: include file paths and line numbers
- Suggest fixes, don't just point out problems
- Don't block on style nits if the repo has no linter configured
