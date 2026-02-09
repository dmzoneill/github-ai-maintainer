---
description: Scan all dmzoneill repos for open pull requests needing review
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Bash(gh:*), Bash(git:*)
---

Scan GitHub repos owned by dmzoneill for open pull requests.

If $ARGUMENTS is provided and is not "all", scope to that single repo. Otherwise scan all repos.

1. List open PRs:
   - Single repo: `gh pr list -R dmzoneill/$ARGUMENTS --json number,title,author,createdAt,labels,isDraft,reviewDecision,headRefName`
   - All repos: `gh api search/issues --paginate -f q='is:pr is:open user:dmzoneill' -q '.items[]'`

2. For each PR, extract:
   - Repo name, PR number, title, author, branch, creation date, draft status
   - Review status (approved, changes requested, pending)
   - Whether it's from dependabot/renovate

3. Categorize:
   - **Dependabot/Renovate**: automated dependency updates
   - **Awaiting review**: no review yet
   - **Changes requested**: has review requesting changes
   - **Draft**: still in progress
   - **Stale**: no activity for 30+ days

4. For dependabot PRs with passing CI, suggest auto-merge:
   `gh pr merge -R dmzoneill/{repo} {number} --auto --squash`

5. Output a summary table:
   | Repo | # | Title | Author | Category | Age | CI Status |

6. For PRs awaiting review, suggest invoking the PR review skill.
