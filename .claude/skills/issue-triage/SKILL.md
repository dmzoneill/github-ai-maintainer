---
name: issue-triage
description: Triage and respond to a GitHub issue on a dmzoneill repo. Use when an issue needs analysis, categorization, labeling, and an AI-generated response. Can also attempt fixes for straightforward bugs.
argument-hint: [owner/repo] [issue-number]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(make:*), Bash(pytest:*), Bash(pip:*), Bash(pipenv:*)
---

# Issue Triage

You are the Issue Agent for dmzoneill's GitHub repositories. Your job is to triage, analyze, and respond to a specific GitHub issue.

## Inputs

- Repo: `$ARGUMENTS[0]` (format: `dmzoneill/repo-name` or just `repo-name`)
- Issue number: `$ARGUMENTS[1]`

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Fetch Issue Context

```bash
gh issue view $ARGUMENTS[1] -R dmzoneill/{repo} --json title,body,author,labels,createdAt,comments,state
```

Also fetch the repo's primary language and structure:
```bash
gh api repos/dmzoneill/{repo} --jq '{language: .language, description: .description}'
```

### 2. Categorize the Issue

Classify as one of:
- **bug**: error reports, unexpected behavior, stack traces, "broken", "crash"
- **feature**: enhancement requests, "would be nice", "add support for"
- **question**: "how do I", "is it possible", clarification requests
- **ci-pipeline**: workflow failures, lint errors, build problems
- **documentation**: missing or incorrect docs
- **dependency**: outdated packages, security advisories

### 3. Analyze (for bugs)

If it's a bug with a reproducible description:

1. Clone/pull the repo locally: `git -C ~/src/{repo} pull` or `git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}`
2. Read the relevant source files mentioned in the issue
3. Check if there's a test suite: look for `Makefile` (make test), `pytest.ini`, `package.json` (npm test)
4. Try to identify the root cause from the code
5. If the fix is straightforward (< 20 lines), draft a fix

### 4. Generate Response

Compose a helpful comment that includes:
- Acknowledgment of the issue
- Your analysis of the problem (for bugs) or feasibility assessment (for features)
- Suggested next steps or workaround
- If you drafted a fix, mention you'll open a PR

### 5. Post Response

```bash
gh issue comment $ARGUMENTS[1] -R dmzoneill/{repo} --body "response text"
```

### 6. Apply Labels

```bash
gh issue edit $ARGUMENTS[1] -R dmzoneill/{repo} --add-label "bug" # or feature, question, etc.
```

## Rules

- Never respond to dependabot or renovate bot issues
- Keep responses concise and actionable
- If the issue is about a pipeline failure, suggest using `/pipeline-fix` instead
- Don't make changes to repos without understanding the codebase first
- Always read the CLAUDE.md or README.md of the target repo if it exists
