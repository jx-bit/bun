---
name: gh-create-pr
description: Create or update a GitHub pull request with the gh CLI. Use when the user asks to open a PR, push a branch for review, or update an existing PR's description.
---

# Create / Update a Pull Request (gh)

## 1. Pre-flight checks (before push)

- Single-commit rule: `git rev-list --count <base>..HEAD` must print `1`. If more, squash: `git reset --soft <base>` then recommit.
- Self-check commit message for forbidden references (internal repo names, internal workspace paths):
  `git log --format=%B -1 | grep -icE '<forbidden-patterns>'` → must be 0.
- Review the diff: `git diff <base>..HEAD --stat`. Internal workspace files (e.g. under the fork's private directory) must not leak into the PR unless the repo's allowlist permits them.

## 2. Push the branch

`git push -u origin <head>` (retry on network failure; `--force-with-lease` only when rewriting the single commit).

## 3. Create the PR

```bash
gh pr create --repo <owner>/<repo> \
  --base <base> --head <head> \
  --title "<short imperative title>" \
  --body '### Problem
<what is broken>
### Fix
<what changed, list files>
### Risk
<what could break>'
```

- Description in English, upstream style. State root cause, the exact fix, and how it was verified.
- Do not overstate: never claim more than was actually tested.

## 4. Update an existing PR

`gh pr edit <PR#> --repo <owner>/<repo> --body '<new body>'`

## 5. Post-create self-check

```bash
gh pr view <PR#> --repo <owner>/<repo> --json body --jq '.body' | grep -icE '<forbidden-patterns>'   # must be 0
```

## 6. Compatibility

- Requires `gh` authenticated (`gh auth status`) with repo scope.
- If a pre-push gate script exists in the repo (e.g. a check-pr.sh), run it before pushing. FAIL = do not push.
