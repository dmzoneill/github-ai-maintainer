---
description: Show status overview of all dmzoneill repos (issues, PRs, pipelines, health)
argument-hint: [repo-name-or-all]
allowed-tools: Bash(gh:*), Bash(git:*)
---

Generate a health dashboard for dmzoneill repos.

If $ARGUMENTS is provided and is not "all", show status for that single repo. Otherwise show all repos.

1. For each repo, gather via `gh api`:
   - Open issue count
   - Open PR count
   - Latest workflow run status (success/failure/in_progress)
   - Last commit date
   - Primary language
   - Whether dispatch.yaml workflow exists

2. Calculate health indicators:
   - **Healthy**: latest CI passing, no open issues older than 30 days
   - **Needs attention**: CI failing or issues unresolved for 30+ days
   - **Stale**: no commits in 180+ days
   - **No CI**: missing dispatch.yaml workflow

3. Output a dashboard table:
   | Repo | Language | CI Status | Open Issues | Open PRs | Last Commit | Health |

4. Show aggregate stats:
   - Total repos, healthy/attention/stale/no-CI counts
   - Repos with most open issues
   - Repos with longest-failing pipelines
