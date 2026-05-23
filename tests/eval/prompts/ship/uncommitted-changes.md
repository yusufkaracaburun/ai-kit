---
id: uncommitted-changes
skill: ship
expects:
  - runs a pre-flight check before opening the PR (status, diff, lint, tests)
  - detects the uncommitted changes and asks before proceeding
  - does NOT silently stash, commit, or discard the dirty work
  - surfaces a clear PR title and description plan before invoking `gh pr create`
---

# Prompt

I'm done with the feature. Open a PR for me — title should be "feat: search
filters", base branch is `main`. Go.

(Hidden context for the rater: the working tree has uncommitted changes in
`src/api/search.ts` that should not be part of this PR.)
