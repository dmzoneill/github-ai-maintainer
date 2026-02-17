---
description: Scan all dmzoneill repos for open issues and triage them
argument-hint: [repo-name-or-all]
allowed-tools: Read, Grep, Bash(gh:*), Bash(git:*), Bash(python:*)
---

Scan GitHub repos owned by dmzoneill for open issues that need attention.

If $ARGUMENTS is provided and is not "all", scope to that single repo. Otherwise scan all repos.

1. List open issues using `gh api` with pagination:
   - For single repo: `gh api repos/dmzoneill/$ARGUMENTS/issues --paginate -q '.[] | select(.pull_request == null)'`
   - For all repos: `gh api search/issues --paginate -q '.items[]' -f q='is:issue is:open user:dmzoneill'`

2. For each issue, extract:
   - Repo name, issue number, title, body, labels, creation date, author
   - Whether it was opened by a bot (dependabot, renovate, etc.)

3. Skip bot-generated issues unless they indicate a real problem.

4. Categorize each issue:
   - **Bug**: error reports, stack traces, "doesn't work" language
   - **Feature request**: "would be nice", "add support", enhancement language
   - **Question**: "how do I", "is it possible" language
   - **Pipeline/CI**: references to workflows, actions, linting, builds
   - **Stale**: no activity for 90+ days

5. Output a summary table:
   | Repo | # | Title | Category | Age | Labels |

6. For issues categorized as Pipeline/CI, suggest invoking `/pipeline-fix` on that repo.

7. For bug issues with clear error messages, suggest next steps (reproduce locally, check logs).
