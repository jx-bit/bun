---
name: gh-ci-status
description: Check the CI status of a pull request with the gh CLI. Use when the user asks whether a PR's checks passed, what CI is running, or which workflow failed.
---

# Check CI Status (gh)

## 1. All checks on a PR

`gh pr checks <PR#> --repo <owner>/<repo>`
Failures only: `gh pr checks <PR#> --repo <owner>/<repo> | grep -i fail`

## 2. Recent workflow runs

- `gh run list --repo <owner>/<repo> --branch <branch> --limit 5`
- Filter by workflow: `gh run list --repo <owner>/<repo> --workflow=<workflow-file> --limit 3`

## 3. Inspect one run

- `gh run view <run_id> --repo <owner>/<repo> --json status,conclusion`
- Job breakdown: `gh api repos/<owner>/<repo>/actions/runs/<run_id>/jobs --jq '.jobs[] | {name, status, conclusion}'`

## 4. Identify which workflow does what

Read `.github/workflows/*.yml`: the `name:` field + `on:` triggers tell you which channel is build vs test vs gate. Note: `pull_request` runs use the workflow file from the BASE branch.

## 5. Interpret conclusions

`success / failure / cancelled / timed_out / action_required / neutral / skipped`.
A cancelled run is normal when concurrency `cancel-in-progress` supersedes it with a newer push.

## 6. Waiting for long builds

- `gh pr checks <PR#> --repo <owner>/<repo> --watch --fail-fast -i 15` (blocks until done; set a shell timeout ~1200s).
- Native/OS builds commonly take 20-60 minutes. Poll sparingly to avoid rate limits.
