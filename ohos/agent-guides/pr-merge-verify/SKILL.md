---
name: pr-merge-verify
description: Verify a PR merge and sync the local branch. Use after a PR is merged, when checking merge state, or when asked to pull merged changes into the working branch.
---

# Post-Merge Verification

## 1. Confirm the merge

`gh pr view <PR#> --repo <owner>/<repo> --json state,mergedAt,mergeCommit`

## 2. Fetch the merged base

`git fetch origin <base>`

## 3. Sync the local working branch

```bash
git checkout <head> && git pull origin <head>
git merge origin/<base>        # bring the merge commit in
# or: git pull --rebase origin <base>
```

## 4. Verify the merged content

- `git log origin/<base> --oneline -5`
- Spot-check a key file: `git show origin/<base>:<path> | grep '<key-content>'`
- `git diff origin/<base> --stat` should show no unexpected differences.

## 5. Common situations

| Situation                                                  | Handling                                             |
| ---------------------------------------------------------- | ---------------------------------------------------- |
| local branch behind <base> (squash merge commit not local) | `git merge origin/<base>`                            |
| local ahead (next fix not yet PR'd)                        | normal — next PR carries it                          |
| divergence on both sides                                   | merge to reconcile                                   |
| analysis/docs appearing in the diff                        | keep them out of the PR branch; reset if uncommitted |

## 6. Post-merge CI

Merges to the default branch usually trigger the push pipeline:
`gh run list --repo <owner>/<repo> --branch <base> --limit 3`
