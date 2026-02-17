---
name: license-compliance
description: Check and fix license compliance on a dmzoneill repo. Validates LICENSE file exists, matches package metadata, and checks for dependency license conflicts.
argument-hint: [owner/repo]
allowed-tools: Read, Grep, Glob, Bash(gh:*), Bash(git:*), Bash(python:*), Bash(pip:*), Bash(pipenv:*), Bash(ls:*)
---

# License Compliance

You are the License Compliance Agent for dmzoneill's GitHub repositories. Your job is to audit and fix license compliance for a specific repo.

## Inputs

- Repo: `$ARGUMENTS` (format: `dmzoneill/repo-name` or just `repo-name`)

If repo doesn't include `dmzoneill/`, prefix it.

## Process

### 1. Check LICENSE File Exists

```bash
gh api repos/dmzoneill/{repo}/license --jq '{license: .license.spdx_id, name: .license.name}' 2>&1
```

Also check for common license file names:
```bash
gh api repos/dmzoneill/{repo}/contents/ --jq '.[].name' | grep -iE '^(LICENSE|LICENCE|COPYING|LICENSE\.md|LICENSE\.txt)$'
```

### 2. Clone/Pull Repo

```bash
git -C ~/src/{repo} pull 2>/dev/null || git clone git@github.com:dmzoneill/{repo}.git ~/src/{repo}
```

### 3. Check License Metadata Consistency

Read the LICENSE file and determine its SPDX identifier (MIT, Apache-2.0, GPL-3.0, etc.).

Then check package metadata files for consistency:

**Python** (`pyproject.toml`, `setup.py`, `setup.cfg`):
```bash
grep -i 'license' ~/src/{repo}/pyproject.toml ~/src/{repo}/setup.py ~/src/{repo}/setup.cfg 2>/dev/null
```

**Node.js** (`package.json`):
```bash
grep '"license"' ~/src/{repo}/package.json 2>/dev/null
```

**Rust** (`Cargo.toml`):
```bash
grep 'license' ~/src/{repo}/Cargo.toml 2>/dev/null
```

**Go** (`go.mod` — no license field, skip):
- Go modules don't have a license field

Compare the license in the LICENSE file against what's declared in package metadata. Flag mismatches.

### 4. Check GitHub API License Detection

```bash
gh api repos/dmzoneill/{repo} --jq '.license.spdx_id'
```

If the result is `NOASSERTION`, GitHub couldn't detect the license. This usually means:
- LICENSE file is malformed or non-standard
- LICENSE file is missing
- LICENSE file uses an uncommon license

### 5. Check Top-Level Dependency Licenses (advisory)

For Python repos with `requirements.txt` or `Pipfile`:
```bash
pip show $(head -10 ~/src/{repo}/requirements.txt | grep -v '^#' | grep -v '^$' | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1) 2>/dev/null | grep -E '^(Name|License):'
```

Flag potential conflicts:
- GPL dependencies in MIT/Apache projects (viral license in permissive project)
- AGPL dependencies in any non-AGPL project
- This is advisory only — create an issue, don't change anything

### 6. Apply Direct Fixes

**Missing LICENSE file**: Add MIT license (dmzoneill's default) with current year and "Dave O'Neill" as copyright holder:
```bash
cat > ~/src/{repo}/LICENSE << 'EOF'
MIT License

Copyright (c) 2024 Dave O'Neill

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

Commit message: `chore: add MIT LICENSE file`

**Never change an existing LICENSE file** — if there's a mismatch, create an issue instead.

### 7. Create Issues for Compliance Problems

For problems that need human judgment:
```bash
gh issue create -R dmzoneill/{repo} --title "chore: license compliance issues found" --body "{details}" --label "documentation"
```

Include:
- License mismatch between LICENSE file and package metadata
- GitHub `NOASSERTION` detection
- Potential dependency license conflicts (with specific packages named)

### 8. Report

Output a summary:
```
=== LICENSE COMPLIANCE: {repo} ===
LICENSE file: exists/missing → added MIT/already present
SPDX ID (GitHub): MIT/NOASSERTION/none
Package metadata match: yes/mismatch ({details})
Dependency conflicts: none/advisory ({details})
Actions taken:
- Added MIT LICENSE file
- Created issue #N for metadata mismatch
```

## Rules

- Default to MIT license when adding a missing LICENSE (dmzoneill's standard)
- Never modify an existing LICENSE file
- Never change package metadata license fields — create an issue for mismatches
- Dependency license checking is advisory only — don't block on it
- Only check top-level dependencies, not transitive ones
