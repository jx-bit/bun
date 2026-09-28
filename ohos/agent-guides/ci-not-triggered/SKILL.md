---
name: ci-not-triggered
description: Diagnose why a push did not trigger GitHub Actions. Use when CI did not start after a push, when a workflow run is missing, or when asked "why didn't CI run".
---

# CI Not Triggered

## 1. Confirm the push landed

`git rev-parse origin/<branch>` vs local HEAD. Then check for runs: `gh api repos/<owner>/<repo>/commits/<sha>/check-runs --jq '.total_count'`.

## 2. Check trigger conditions FIRST

Read `.github/workflows/<workflow-file>`:

- `on:` — does it cover this branch and event? (`push.branches` / `pull_request.branches`)
- `paths:` filters — the changed files may simply not match.
- `pull_request` runs use the workflow file from the BASE branch — a workflow added only on the head branch won't run.

## 3. Concurrency & delays

`concurrency.cancel-in-progress` may have cancelled an older run; a new run can queue for seconds to minutes. Wait briefly before concluding it never triggered.

## 4. Remediation (in order)

1. Close & reopen the PR (re-fires `pull_request`):
   `gh pr close <PR#> --repo <owner>/<repo> && sleep 3 && gh pr reopen <PR#> --repo <owner>/<repo>`
2. Empty commit: `git commit --allow-empty -m "chore: trigger CI" && git push`
3. Manual dispatch (needs actions:write; workflow file must exist on the default branch):
   `gh workflow run <workflow-file> --repo <owner>/<repo> --ref <branch>`

## 5. Common causes

| Cause                            | Note                                  |
| -------------------------------- | ------------------------------------- |
| branch not in `on.push.branches` | add the branch or use dispatch        |
| `paths:` filter mismatch         | touch a matching file or dispatch     |
| workflow only on head branch     | PR events read the base branch's file |
| concurrency cancelled            | newer push superseded; wait or re-run |
| Actions outage / queue delay     | check githubstatus, retry             |
