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

Conventions for every commit, branch and PR. `/ai:ship`, `/ai:to-issues` and `/ai:tdd` apply them without being reminded.

## Branches

`feat/<area>-<desc>`, `fix/<area>-<desc>`, `chore/<area>-<desc>` (deps, CI, docs-only). No PR titles or bare ticket numbers as names, no deep slashes.

## Commits

Conventional Commits, imperative subject ≤ 72 chars, scope recommended:

```
<type>(<scope>): <subject>

<body — why, wrapped at 80; the diff already shows what>

<footers — Fixes #123, BREAKING CHANGE:, Co-Authored-By:>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`. Never `--no-verify`; a failing hook is fixed at its cause, a wrong hook in its own commit.

**Stage by path — never `git commit -a` / `-am`.** `-a` sweeps in every modified tracked file, including work another session wrote; in a repo with more than one session open that is the normal state. Read `git diff --staged` before every commit: you commit what is staged, not what you remember changing.

**Issue keywords.** `closes`/`fixes`/`resolves` (and `fix`, `fixed`, `close`, `closed`, `resolve`, `resolved`) before `#N` close that issue on merge — the parser reads keyword + number, not your sentence. "track entry-scan fix #120" and "does not fix #134" both closed an issue. To reference without closing use `refs #N` / `see #N`; to close, put it on its own line.

## Pull requests

- Base: the project's main branch — or `epic/<name>` when the work is a slice of an epic (below).
- Project PR template if present; otherwise **Summary** (what + why), **Test plan**, **Out of scope**.
- Diff ≤ 400 lines where possible; split into vertical slices (`/ai:to-issues`). Link issues with `Fixes #N`.
- Title in the Conventional Commits form the squash commit will carry.

## Epic branches

The exception to straight-to-main: slices that only make sense reviewed together, or must not reach main one at a time. `epic/<name>` is cut from main once; slice branches keep their normal prefix and target it (`gh pr create --base epic/<name>`); the epic lands on main as one PR at the end. `/ai:to-issues` asks which model applies before publishing and writes the base into each issue — there is no safe default.

**Never merge a slice into the epic branch locally.** Once its commits are in the base, GitHub refuses to open the PR (`422 There are no new commits between base branch and head branch`) and the slice lands with no PR and no merge record. Push, open the PR against `epic/<name>`, merge there.

Review an epic in a worktree (`git worktree add .agents/worktrees/<name> epic/<name>`), and run a real `composer install` / `npm install` in it: a worktree shares only tracked files, and symlinked `vendor/` resolves Composer's autoload paths against the checkout they were built in — the suite then tests the *origin* tree and passes for the wrong reason.

## Merge strategy

Squash + merge by default → one conventional commit on main. `rebase + merge` only when the branch's commits are individually clean and intentional. Plain merge commits only if the project chose them.

## Ask first

Force-push (even your own branch — paste the command, wait), pushing straight to main, `git reset --hard` / `git clean -fd` / `git checkout --` over uncommitted work (say what is lost), amending a published commit.

## Before commit

- [ ] Staged by path; `git diff --staged` read and contains only your change
- [ ] Branch name and commit subject follow the convention; body says why
- [ ] No `--no-verify`, no stray `fix`/`close`/`resolve` before a `#N`
- [ ] No secrets, no absolute user paths; tests pass locally
