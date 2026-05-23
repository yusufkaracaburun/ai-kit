---
name: git-hygiene
description: Branch naming, Conventional Commits, PR conventions, merge strategy
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Git hygiene

Conventions every commit, branch, and PR in an ai-kit project should follow. Agent-readable so `/ai:ship`, `/ai:to-issues`, and `/ai:tdd` apply them without the user reminding them.

## Branch names

- `feat/<area>-<short-desc>` for features
- `fix/<area>-<short-desc>` for bugs
- `chore/<area>-<short-desc>` for non-functional work (deps, CI, docs-only)
- Avoid: PR titles in branch names, tickets-only without context, deep slashes (`feat/sub/sub/x`).

## Commit messages

Conventional Commits with scope. One line subject, imperative, ≤72 chars:

```
<type>(<scope>): <subject>

<body — what changed and why, wrapped at 80>

<footers — Fixes #123, BREAKING CHANGE:, Co-Authored-By:>
```

- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`.
- Scope is optional but recommended for repos with clear modules.
- The body answers **why**, not what — diff already shows what.
- Never `--no-verify` to bypass hooks. If a hook fails, fix the cause; if the hook itself is wrong, fix the hook in a separate commit.

## Pull requests

- Open against the project's main branch (default: `main` or `master` per repo convention).
- Use the project's PR template if present. If not, include: **Summary** (what + why), **Test plan** (how reviewer can verify), **Out of scope** (what this PR explicitly does not do).
- Keep diff ≤ 400 lines where possible. Split big PRs into vertical slices (see `/ai:to-issues`).
- Link issues with `Fixes #N` / `Closes #N` so they auto-close on merge.
- Title follows the same Conventional Commits format as the squash-merge commit would.

## Merge strategy

Default: **squash + merge** for feature/fix branches → single conventional-commit on `main`/`master`. Use `rebase + merge` only when the branch's individual commits are themselves clean and intentional. Avoid plain `merge` commits unless the project explicitly chooses them.

## Things that warrant user confirmation

- Force-push (`git push --force[-with-lease]`), even on your own branch — paste the command, wait for approval.
- Pushing to `main`/`master` directly — confirm the branch is meant to bypass PR review.
- `git reset --hard`, `git clean -fd`, `git checkout --` against uncommitted work — explain what's lost.
- Amending a published commit — the rewrite affects everyone who pulled it.

## Quick checklist before commit

- [ ] Branch name follows convention
- [ ] Commit subject is imperative + scoped
- [ ] Body explains why
- [ ] No `--no-verify`
- [ ] No secrets, no absolute user paths
- [ ] Tests pass locally
