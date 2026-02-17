---
name: readme-docs
description: Check and fix README quality and documentation freshness on a dmzoneill repo. Validates badges, links, required sections, and code examples.
argument-hint: [owner/repo]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(curl:*), Bash(python:*), Bash(ls:*)
---

# README & Documentation Freshness

You are the Documentation Agent for dmzoneill's GitHub repositories. Your job is to audit and fix README quality and documentation freshness for a specific repo.

## Inputs

- Repo: `$ARGUMENTS` (format: `dmzoneill/repo-name` or just `repo-name`)

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Fetch Repo Context

```bash
gh api repos/dmzoneill/{repo} --jq '{language: .language, description: .description, default_branch: .default_branch, has_wiki: .has_wiki}'
```

### 2. Check README Exists

```bash
gh api repos/dmzoneill/{repo}/readme --jq '.name' 2>&1
```

If no README exists, clone the repo and create a basic one with the repo description, language badge, and standard sections. Commit and push.

### 3. Clone/Pull Repo

```bash
git -C ~/src/{repo} pull 2>/dev/null || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
```

### 4. Audit README Content

Read the README and check for:

**Badges** (check if present and valid):
- CI status badge: `![CI](https://github.com/dmzoneill/{repo}/actions/workflows/main.yml/badge.svg)`
- License badge (if LICENSE file exists)
- Validate badge URLs return 200:
  ```bash
  curl -sL -o /dev/null -w "%{http_code}" "{badge_url}"
  ```
- Fix broken badge URLs directly (update to correct format)

**Required sections** (check headings exist):
- Installation / Setup / Getting Started
- Usage
- Contributing
- License

Missing sections are advisory — create an issue listing what's missing rather than generating placeholder content.

**Markdown links** (sample up to 20 external links):
```bash
grep -oP 'https?://[^\s\)\]"]+' ~/src/{repo}/README.md | head -20
```
For each link, check if it returns a non-error status:
```bash
curl -sL -o /dev/null -w "%{http_code}" --max-time 5 "{url}"
```
Report broken links (4xx/5xx) but don't auto-fix them — create an issue.

**Code examples** (spot check):
- If README references specific files (e.g., `src/main.py`), verify those files exist in the repo
- If README references specific functions/classes, grep for them in the codebase

### 5. Apply Direct Fixes

Fix these directly with a commit:
- Missing CI badge → add at top of README
- Broken badge URLs → update to correct format
- Outdated repo name in URLs → update

Commit message: `docs: fix README badges and links`

### 6. Create Issues for Content Problems

For problems that need human judgment, create a single issue:
```bash
gh issue create -R dmzoneill/{repo} --title "docs: README quality improvements needed" --body "{details}" --label "documentation"
```

Include in the issue body:
- Missing required sections (list which ones)
- Broken external links (list URLs and status codes)
- Code examples referencing non-existent files/functions
- Suspiciously short README (< 10 lines for a non-trivial repo)

### 7. Report

Output a summary:
```
=== README/DOCS AUDIT: {repo} ===
README exists: yes/no
CI badge: present/missing/broken → fixed/issue created
License badge: present/missing/broken → fixed/issue created
Required sections: [list present] / missing: [list missing]
External links checked: N total, N broken
Code examples: N checked, N referencing missing files
Actions taken:
- Fixed CI badge URL
- Created issue #N for missing sections and broken links
```

## Rules

- Never generate placeholder content for missing sections — create an issue instead
- Fix badge URLs directly since they're mechanical fixes
- Don't rewrite existing README content, only add missing badges
- Keep badge additions at the top of the README, before the first heading
- If README is a generated file (e.g., from a template engine), skip modifications and note it
