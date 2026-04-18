# GitHub AI Maintainer

Multi-agent system for autonomous GitHub repository maintenance across the `dmzoneill` organization (~189 repos).

## Overview

This project uses specialized AI agents to monitor and act on:
- **Issues**: Auto-triage, label, and respond with AI-generated analysis
- **Pull Requests**: Code review, test execution, auto-merge dependabot PRs
- **CI/CD Pipelines**: Diagnose failures, apply fixes, push commits
- **Repo Health**: Check README quality, license compliance, workflow maintenance, git hygiene

## Architecture

```
Orchestrator (Swarm Coordinator)
├── Issue Agent       → Triage, analyze, respond to issues
├── PR Agent          → Review code, run tests, auto-merge
├── Pipeline Agent    → Fix lint/test/build failures
└── Repo Health Agent → Maintain community files, workflows, docs
```

## Key Features

- **Parallel Execution**: Work across multiple repos simultaneously
- **Smart Triage**: Label and prioritize issues based on content analysis
- **Auto-Merge**: Dependabot PRs with passing CI
- **Fix Automation**: Lint errors, missing version files, broken workflows
- **Proactive Maintenance**: README quality, license compliance, stale branch cleanup

## Usage

### Scan and Report
```bash
/scan-issues [repo|all]       # Find and categorize open issues
/scan-prs [repo|all]          # Find mergeable PRs
/scan-pipelines [repo|all]    # Find failed CI runs
/scan-repo-health [repo|all]  # Check 6 health categories
/repo-status [repo|all]       # Dashboard view
```

### Execute Maintenance
```bash
/maintain [repo|all]          # Full maintenance cycle
/swarm                        # Parallel agent swarm (one iteration)
/unleash                      # Continuous maintenance until clean
```

### Individual Skills
```bash
/issue-triage [repo] [#]      # Triage single issue
/pr-review [repo] [#]         # Review single PR
/pipeline-fix [repo] [run-id] # Fix failed pipeline
/readme-docs [repo]           # Fix README quality
/license-compliance [repo]    # Check license compliance
/workflow-maintenance [repo]  # Update GitHub Actions
```

## Swarm Operation

The `/unleash` command runs continuous maintenance cycles via ralph-loop:

**Phase 1 - Discovery** (4 parallel agents)
- Scan pipelines, issues, PRs, repo health across all 189 repos

**Phase 2 - Triage**
- Build priority queue (6 severity levels)

**Phase 3 - Execution** (up to 5 parallel agents)
- Fix critical failures first
- Auto-merge passing dependabot PRs
- Triage issues, review PRs
- Fix repo health issues

**Phase 4 - Persistence**
- Update `.claude/.swarm-state.json`
- Loop continues until zero remaining work

**Safety Rails**
- Max 10 fix commits per iteration
- Max 15 repo health fixes per iteration
- Max 20 ralph-loop iterations
- Rate limit check (stops if <500 remaining)
- Never auto-merges non-bot PRs
- Never modifies protected workflows
- Never deletes protected branches

## Integration

Works with existing `dmzoneill` infrastructure:
- **dispatch.yaml**: Centralized CI/CD workflow (~1400 lines)
- **setup.sh**: Distributes workflows to all repos
- **setup.py**: Distributes 14 secrets to all repos
- **Redis/Webdis**: Pipeline notifications
- **WordPress API**: Blog post generation

## Tech Stack

- **Language**: Python 3
- **GitHub API**: REST + GraphQL via `gh` CLI
- **AI Provider**: OpenAI API (configurable model)
- **Repos Path**: `~/src/<repo-name>`

## Development

```bash
make lint              # Format with Black
make test              # Run pytest
make run               # Start orchestrator
make version           # Bump version + commit
make push              # Lint + bump + commit + push
```

## Environment Variables

Uses the same 14 secrets distributed across all repos:
- `GITHUB_TOKEN` - GitHub API access
- `AI_API_KEY` - OpenAI API key
- `AI_MODEL` - Model name (e.g., `gpt-4o`)
- `REDIS_PASSWORD` - Webdis/Redis auth
- `WORDPRESS_URL` - Blog API endpoint
- `WORDPRESS_USERNAME` / `WORDPRESS_APPLICATION` - Auth

See `CLAUDE.md` for detailed architecture and implementation guide.

## License

Apache-2.0
