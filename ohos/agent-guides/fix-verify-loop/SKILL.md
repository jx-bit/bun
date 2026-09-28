---
name: fix-verify-loop
description: Iteratively fix CI failures on a pull request until green. Use when a PR's CI fails and the user wants it fixed, when asked to "fix the build", "make CI green", or to iterate on failing checks.
---

# Fix-Verify Loop

## 1. Setup

- `MAX_ITERATIONS` default 5 (user may override). Never loop forever.
- Get failed checks: `gh pr checks <PR#> --repo <owner>/<repo>` or `gh api repos/<owner>/<repo>/commits/<sha>/check-runs`.

## 2. Classify failures

- Auto-fixable: `conclusion == failure` and app is `github-actions` → pull logs (see gh-ci-logs skill).
- Not auto-fixable: `timed_out / cancelled / startup_failure / action_required`, or non-Actions apps → report to the user, do not attempt.

## 3. Diagnose

Follow the gh-ci-logs triage protocol: earliest failed job → first meaningful error → root cause with confidence.

## 4. Fix + validate locally

Edit code → run local tests/formatters/linters → commit.

- Same problem again → `git commit --amend --no-edit` (keep the PR single-commit).
- Genuinely new problem → new commit.

## 5. Push + wait

`git push` (add `-u origin <branch>` if no upstream; `--force-with-lease` after amend).
`gh pr checks <PR#> --repo <owner>/<repo> --watch --fail-fast -i 15` (shell timeout ~1200s).

## 6. Re-check with FRESH data

Re-fetch the head SHA and failure logs each iteration — never diagnose from stale logs.

- Still failing and iterations < MAX_ITERATIONS → back to step 4.
- MAX_ITERATIONS reached → stop, report remaining failures honestly.

## 7. Convergence (optional monitoring)

When green, optionally monitor ~10 minutes for new CI failures or review comments; a new issue resets the iteration counter and re-enters the loop.

## 8. Report

Summarize: checks fixed, remaining failures, unaddressed review comments, iterations used.

Rules:

- Never disable/skip failing tests to go green.
- Never claim success without the checks actually passing.
