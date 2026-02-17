---
name: repo-sync
description: Clone or update all dmzoneill GitHub repos to ~/src/. Detects project type, checks for CLAUDE.md, and reports repo health. Use when setting up or refreshing the local development environment.
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(ls:*)
---

# Repo Sync

Sync dmzoneill's GitHub repositories to local ~/src/ directory.

## Inputs

- Target: `$ARGUMENTS` — a repo name, or "all" to sync everything

## Process

### 1. Get Repo List

```bash
gh repo list dmzoneill --limit 200 --json name,sshUrl,primaryLanguage,isArchived -q '.[] | select(.isArchived == false) | [.name, .sshUrl, .primaryLanguage.name] | @tsv'
```

Skip archived repos.

### 2. For Each Repo

**If already cloned** (`~/src/{name}` exists with `.git/`):
```bash
git -C ~/src/{name} fetch --all --prune
git -C ~/src/{name} pull --rebase 2>&1
```

**If not cloned**:
```bash
git clone {ssh_url} ~/src/{name}
```

### 3. Detect Project Type

After cloning/pulling, detect what kind of project it is:

| Indicator File | Project Type |
|---|---|
| `Makefile` | Has make targets (check for `test`, `lint`, `setup`) |
| `Pipfile` / `requirements.txt` / `pyproject.toml` | Python |
| `package.json` | Node.js/JavaScript |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `Dockerfile` | Containerized |
| `.github/workflows/main.yml` | Has CI via dispatch.yaml |
| `CLAUDE.md` | Has Claude Code documentation |

### 4. Report

Output a summary grouped by status:
- **Cloned**: newly cloned repos with their language
- **Updated**: repos with new commits pulled
- **Up-to-date**: repos with no changes
- **Failed**: repos that errored (with reason)

Then output project type stats:
- Count by primary language
- Count with/without CI workflows
- Count with/without CLAUDE.md
