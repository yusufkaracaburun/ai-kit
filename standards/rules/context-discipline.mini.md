---
name: context-discipline
description: Token-budget discipline — grep before read, delegate wide exploration, lean on CONTEXT.md
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Context discipline

Token budget is a real cost. Agents that drown in context get measurably worse — vaguer answers, missed details, slower turns. Apply this rule always, not just when the window is "almost full."

## Primary bias to correct

Default behaviour of reading whole files, exploring broad swaths of code inline, and re-deriving knowledge each session. None of these are free.

## Decision rules

- **Search before read.** Use `grep` / `find` / `Glob` to locate; only `Read` the slices that matter. Never `cat` a whole file when 30 lines answer the question.
- **Delegate wide exploration.** For "search the codebase for X" / "how does this module fit" / "find all callers of Y," spawn a sub-agent so the raw output stays in *its* context and only the conclusion comes back to yours. Reach for `Explore` or `ai:explore` by default; `cavecrew-investigator` (caveman) when it is installed, since it returns a compressed `file:line` table instead of prose. A `grep` scoped to a file you already named is fine — the rule is about *sweeps*, not about every search.
- **Lean on cached truth.** `CONTEXT.md` (domain glossary) and `docs/adr/` (decisions) exist precisely so you don't re-derive. Read those before exploring code. If they contradict what you'd derive, trust the docs first — then verify only the conflict.
- **Don't re-read what you read.** Once a file's relevant slice is in your context, don't `Read` it again unless something changed. The harness tracks edits.
- **Skip the noise.** Never `Read` lockfiles (`package-lock.json`, `composer.lock`, `Cargo.lock`), `node_modules/`, `vendor/`, build artefacts, or generated code unless the user is asking about exactly that.
- **Quote, don't paste.** When citing existing code in your reply, cite `file:line` — don't reproduce blocks the user can already see in their editor.
- **Keep always-loaded files lean.** Root `CLAUDE.md` / `AGENTS.md` load at the start of every session — a fixed token tax before the first prompt. Target under 200 lines: only what every session needs (build commands, non-obvious conventions, absolute rules). Directory-specific notes belong in `<subdir>/CLAUDE.md`, stack conventions in path-scoped rules, procedures in skills — all load on demand. Curation beats compression: moved content costs zero tokens per session.
- **Shrink context with the cheapest tool that fits.** Three situations, three different answers — reaching for the heaviest one every time is its own waste:

  | Situation | Do this |
  | --------- | ------- |
  | Mid-task, context is big, the work continues | `/compact <what to keep>` — summarise in place. No checkpoint, no `/clear`, no resume. This is the default. |
  | Context is polluted with junk a summary would carry forward (test dumps, dead ends, abandoned approaches) | `/ai:checkpoint --mid-session --skip-housekeeping` → `/clear` → `/ai:resume` |
  | Session is ending, pausing, or switching topic | `/ai:checkpoint` → `/clear`. Next session: `/ai:resume`. Use `--to tmp` when the handoff crosses a machine or a teammate. |

  A checkpoint is a *state snapshot for a future reader*, not a compaction tool — `--mid-session` writes the memo but does not shrink your context; only `/compact` and `/clear` do that. Mid-task token-exhaustion still produces worse work than a deliberate restart, so do not ride the limit — just do not pay for a full checkpoint→clear→resume cycle when a `/compact` was the answer.

## Trigger rules

- **When the user pastes a stack trace, log, or huge diff** — summarise the salient lines and let the rest scroll out; don't quote it back.
- **When mid-task and you've read >5 files** — pause, ask: "could a sub-agent finish this?" If yes, delegate.
- **When the user asks "how does X work"** — try `CONTEXT.md`/ADRs/grep first; full file reads are the last step, not the first.
- **When two answers conflict** — prefer the more recently *changed* source (use `git log` on the file), not the most recently read.

## What NOT to do

- Don't open a directory listing of a build output, dist folder, or `.git/` to "see what's there."
- Don't `Read` a SKILL.md, ADR, or CONTEXT.md just because it might be relevant — open only the named section.
- Don't re-explore the same module across sessions; the previous session's outcome already lives in code, commits, or `CONTEXT.md`.

## Final checklist before a slow turn

- Did I `grep` before `Read`?
- Could a sub-agent have done this exploration?
- Am I re-deriving something `CONTEXT.md` or an ADR already states?
- If yes to any: stop, route, and continue.
