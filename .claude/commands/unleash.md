---
description: Start the ralph loop swarm — continuously maintain all repos until everything is clean
allowed-tools: Read, Bash(gh:*), Bash(cat:*), Bash(date:*), Skill
---

# Unleash the Swarm

Start a ralph-loop that continuously runs the full maintenance swarm until all repos are healthy.

## What This Does

Invokes `/ralph-loop` with the `/swarm` command as the prompt. The ralph loop will:
1. Run `/swarm` — which launches parallel agents to scan and fix all repos
2. When `/swarm` finishes an iteration, ralph-loop feeds it back in
3. Each iteration sees previous work via the state file and git history
4. When everything is clean (no failed pipelines, no untriaged issues, no unreviewed PRs), the swarm outputs its completion promise and stops

## Launch

Invoke the ralph-loop skill with the swarm as the task:

```
/ralph-loop "Run /swarm to maintain all dmzoneill GitHub repos. Fix pipeline failures, triage issues, review PRs, auto-merge dependabot. Each iteration: scan for new work, process it, update state file. Output <promise>I DONE DID IT - ALL REPOS ARE MAINTAINED AND I'M HELPING</promise> when zero work remains." --completion-promise "I DONE DID IT" --max-iterations 20
```

## Monitoring

While the swarm runs, check progress:
```bash
cat ~/src/github-ai-maintainer/.claude/.swarm-state.json 2>/dev/null | python3 -m json.tool
```

## Emergency Stop

If things go sideways:
```
/cancel-ralph
```
