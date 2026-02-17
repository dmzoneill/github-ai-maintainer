---
description: Clone or pull all dmzoneill repos into ~/src/
argument-hint: [repo-name-or-all]
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(mkdir:*)
---

Sync dmzoneill GitHub repos to ~/src/.

If $ARGUMENTS is provided and is not "all", sync only that repo. Otherwise sync all owned repos.

1. Get list of repos to sync:
   - Single: just `$ARGUMENTS`
   - All: `gh repo list dmzoneill --limit 200 --json name,sshUrl -q '.[] | [.name, .sshUrl] | @tsv'`

2. For each repo:
   - If `~/src/{repo-name}` exists and is a git repo: `git -C ~/src/{repo-name} pull --rebase`
   - If `~/src/{repo-name}` exists but is NOT a git repo: skip and warn
   - If `~/src/{repo-name}` does not exist: `git clone {ssh_url} ~/src/{repo-name}`

3. Track results:
   - Cloned: newly cloned repos
   - Updated: repos that had new changes pulled
   - Up-to-date: repos with no changes
   - Failed: repos that failed to clone/pull (with error reason)

4. Output a summary:
   - Total repos processed
   - Cloned / Updated / Up-to-date / Failed counts
   - List any failures with their error messages
