---
name: branch-cleanup-after-merge
description: Delete merged feature branches locally and on remote immediately after the PR merges
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Branch cleanup after merge

When a PR merges, the feature branch's purpose is over. Delete it
locally and on the remote in the same beat as the merge confirmation.

## Why

Stale branches accumulate fast in active repos. Branch-name autocomplete
becomes a minefield: wrong-branch checkouts produce hours of confused
debugging on already-merged code. Stale remote branches also trip up
`git fetch --prune` workflows and can cause CI to fire against dead
heads.

The cleanup costs two commands. Skipping it costs an incident every few
weeks. Easy win.

## How to apply

After a merge (squash or rebase):

```bash
# from the project root, default branch checked out
git branch -d <feature-branch>
git push origin --delete <feature-branch>
```

When using `gh pr merge --squash --delete-branch`, the remote branch is
deleted automatically; still run `git branch -d <feature-branch>`
locally afterwards.

## When to skip

- Long-lived branches by design (`release/*`, `hotfix-staging`, etc.) —
  these aren't feature branches and follow their own lifecycle.
- Branch is shared with another active worktree (rare; verify before
  deletion).

## See also

- [`git-hygiene.mini.md`](../git-hygiene.mini.md) — wider git workflow
  conventions.
