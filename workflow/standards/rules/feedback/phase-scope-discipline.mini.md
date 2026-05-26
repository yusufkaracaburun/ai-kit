---
name: phase-scope-discipline
description: Stay within the scope of the current phase or task; capture out-of-scope finds as deferred follow-ups instead of doing them inline
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Phase-scope discipline

A change should touch only what the asked task requires. Adjacent
improvements ("while I'm here…"), drive-by refactors, and opportunistic
formatting tweaks belong in a separate change, not the current one.

## Why

Scope sprawl turns 30-line PRs into 300-line PRs. Reviewers stop
distinguishing the intentional change from the drive-bys; bugs hide
inside the noise. The cost is paid twice: once at review, once when the
mixed commit needs to be reverted or cherry-picked.

A separate follow-up issue costs ~1 minute to file and preserves the
finding without contaminating the current diff. The asymmetry favours
defer-then-resume.

## How to apply

1. **Before each edit, ask: "is this in scope of the stated task?"** If
   no, stop. Capture as a follow-up.
2. **For follow-ups, use defer-mode** — `/ai:to-prd` Defer mode opens a
   GH issue + roadmap entry without prompting. One-line capture, then
   continue.
3. **No mixed commits.** Refactor + feature + format = three commits, or
   three branches, never one.
4. **End-of-turn summary names the deferred items** so the user sees
   what was parked.

## When to skip

- Trivial inline fix that lives on the same line you're already editing
  (e.g. fixing a typo in a string you're already changing).
- The user has explicitly asked for a sweep ("clean up this file while
  you're in there"). Then the sweep *is* the scope.

## See also

- [`pragmatic.nano.md`](../pragmatic.nano.md) — minimum-code principle.
- [`grill-first.mini.md`](../grill-first.mini.md) — surface scope
  ambiguity before coding, not after.
