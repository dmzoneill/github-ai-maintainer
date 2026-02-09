---
description: Check and distribute CI/CD workflows and secrets to all dmzoneill repos (like setup.sh + setup.py)
allowed-tools: Bash(gh:*), Bash(git:*), Bash(curl:*), Bash(md5sum:*)
---

Check which dmzoneill repos are missing or have outdated CI/CD workflows, and distribute them. This replicates the functionality of `setup.sh` and `setup.py` from the profile repo.

## Process

### 1. Check Rate Limit
```bash
gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit), Resets: \(.reset | strftime("%H:%M:%S"))"'
```

### 2. Get Reference Files
Fetch the current versions of the workflow files from the profile repo:
```bash
curl -sL https://raw.githubusercontent.com/dmzoneill/dmzoneill/main/.github/workflows/main.yml -o /tmp/ref-main.yml
curl -sL https://raw.githubusercontent.com/dmzoneill/dmzoneill/main/ai-responder.yml -o /tmp/ref-ai-responder.yml
```

Compute their MD5 checksums for comparison.

### 3. Scan All Repos
For each owned repo (via `gh repo list dmzoneill --limit 200`):
1. Check if `.github/workflows/main.yml` exists via raw.githubusercontent.com
2. Check if `.github/workflows/ai-responder.yml` exists
3. Compare MD5 checksums with reference files
4. Report: missing, outdated, or up-to-date

### 4. Output Report
| Repo | main.yml | ai-responder.yml | Action Needed |
Show counts: up-to-date, missing, outdated.

### 5. Fix (with confirmation)
For repos with missing or outdated workflows, ask before pushing:
- Clone the repo
- Copy the workflow files
- Commit and push

Do NOT push automatically — always ask the user first.
