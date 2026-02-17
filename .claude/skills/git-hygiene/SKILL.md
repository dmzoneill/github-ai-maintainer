---
name: git-hygiene
description: Audit and fix git hygiene on a dmzoneill repo. Checks .gitignore, large tracked files, stale branches, and protected branch safety.
argument-hint: [owner/repo]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(ls:*)
---

# Git Hygiene

You are the Git Hygiene Agent for dmzoneill's GitHub repositories. Your job is to audit and fix git hygiene for a specific repo.

## Inputs

- Repo: `$ARGUMENTS` (format: `dmzoneill/repo-name` or just `repo-name`)

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Clone/Pull Repo

```bash
git -C ~/src/{repo} pull 2>/dev/null || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
```

### 2. Check .gitignore Exists

```bash
ls ~/src/{repo}/.gitignore 2>/dev/null
```

If missing, detect the project language and create an appropriate `.gitignore`:

```bash
gh api repos/dmzoneill/{repo} --jq '.language'
```

Use language-appropriate patterns. Common bases:

**Python**:
```
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
dist/
*.egg-info/
*.egg
.eggs/
.venv/
venv/
env/
.env
*.whl
.pytest_cache/
.mypy_cache/
.tox/
htmlcov/
.coverage
```

**JavaScript/TypeScript**:
```
node_modules/
dist/
build/
.env
*.log
npm-debug.log*
.cache/
coverage/
.next/
```

**Go**:
```
/vendor/
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
```

**Rust**:
```
/target/
Cargo.lock
*.pdb
```

**General** (always include):
```
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.idea/
.vscode/
*.log
```

If .gitignore exists, check it has the language-appropriate patterns and append any missing critical patterns. Never remove existing patterns.

### 3. Check for Large Tracked Files

Find files over 1MB tracked by git:
```bash
cd ~/src/{repo} && git ls-files -z | xargs -0 -I{} sh -c 'size=$(stat -c%s "{}" 2>/dev/null || stat -f%z "{}" 2>/dev/null); if [ "$size" -gt 1048576 ] 2>/dev/null; then echo "$size {}"; fi' | sort -rn | head -20
```

Common offenders: `.jar`, `.war`, `.zip`, `.tar.gz`, `.db`, `.sqlite`, `.bin`, images, compiled binaries.

For any large files found, create an issue — don't auto-delete tracked files:
```bash
gh issue create -R dmzoneill/{repo} --title "chore: large files tracked in git" --body "{details}" --label "maintenance"
```

### 4. Check Stale Branches

List remote branches that are already merged into the default branch:
```bash
gh api repos/dmzoneill/{repo}/branches --paginate --jq '.[].name'
```

```bash
cd ~/src/{repo} && git fetch --all --prune && git branch -r --merged origin/main | grep -v 'origin/main$' | grep -v 'origin/master$' | grep -v 'origin/HEAD'
```

**Protected branches** — NEVER delete these:
- `main`, `master`, `develop`, `dev`, `gh-pages`, `release/*`

For merged branches that are not protected, delete via API:
```bash
gh api -X DELETE repos/dmzoneill/{repo}/git/refs/heads/{branch_name}
```

### 5. Apply Direct Fixes

**Missing .gitignore**: Create the file with language-appropriate patterns.
```bash
cd ~/src/{repo}
git add .gitignore
git commit -m "chore: add .gitignore for {language}"
git push
```

**Incomplete .gitignore**: Append missing critical patterns (never remove existing ones).
```bash
cd ~/src/{repo}
git add .gitignore
git commit -m "chore: update .gitignore with missing patterns"
git push
```

### 6. Report

Output a summary:
```
=== GIT HYGIENE: {repo} ===
.gitignore: exists/created/updated
  Missing patterns added: [list]
Large tracked files: N found
  [list files with sizes]
  Issue created: #N (if any)
Stale branches: N found, N deleted
  Deleted: [list]
  Skipped (protected): [list]
```

## Rules

- Never delete protected branches: main, master, develop, dev, gh-pages, release/*
- Never remove existing .gitignore patterns — only append
- Never auto-delete large tracked files — create an issue instead
- For .gitignore, always include the "General" patterns regardless of language
- When appending to .gitignore, add a comment header: `# Added by maintenance agent`
- Don't add .gitignore entries that would ignore currently tracked files without also untracking them (which is destructive — create an issue instead)
