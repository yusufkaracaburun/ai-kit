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

Token budget is a real cost: an agent drowning in context gives vaguer answers, misses details, turns slower. Apply this always, not only when the window is nearly full. The bias to correct: reading whole files, exploring broad swaths inline, re-deriving knowledge every session.

## Decision rules

- **Search before read.** `grep` / `find` / `Glob` to locate, `Read` only the slice that matters. Never `cat` a whole file when 30 lines answer the question.
- **Delegate sweeps.** "Search the codebase for X", "how does this module fit", "find all callers of Y" → a sub-agent (`Explore` / `ai:explore`; `cavecrew-investigator` when caveman is installed — it returns a `file:line` table), so the raw output stays in *its* context and only the conclusion returns. A `grep` in a file you already named is not a sweep.
- **Cached truth first.** `CONTEXT.md` (domain glossary) and `docs/adr/` exist so you do not re-derive. Read them before code; if they contradict what you would derive, trust the docs and verify only the conflict.
- **Don't re-read.** Once a slice is in context, do not `Read` it again unless it changed — the harness tracks edits.
- **Skip the noise.** Lockfiles, `node_modules/`, `vendor/`, build output, generated code, `.git/` — never, unless the user asks about exactly that.
- **Quote `file:line`**, don't paste blocks the user can see in their editor.
- **Keep always-loaded files lean.** Root `CLAUDE.md` / `AGENTS.md` (and pathless `.claude/rules/`) load every session: under 200 lines, only what every session needs. Directory notes → `<subdir>/CLAUDE.md`, stack conventions → path-scoped rules, procedures → skills. Moved content costs zero tokens per session.
- **Shrink with the cheapest tool.** Mid-task, big context, work continues → `/compact <what to keep>` (the default). Context polluted with junk a summary would carry forward → `/ai:checkpoint --mid-session --skip-housekeeping` → `/clear` → `/ai:resume`. Session ending or switching topic → `/ai:checkpoint` → `/clear`, `--to tmp` for a handoff across machines or people. A checkpoint is a snapshot for a future reader, not a compaction tool — only `/compact` and `/clear` shrink context. Do not ride the limit; do not pay for checkpoint→clear→resume when `/compact` was the answer.

## Triggers

- Pasted stack trace, log or huge diff → summarise the salient lines, let the rest scroll out.
- Mid-task and >5 files read → ask "could a sub-agent finish this?"; if yes, delegate.
- "How does X work" → `CONTEXT.md` / ADRs / grep first; full reads last.
- Two sources conflict → prefer the more recently *changed* (`git log` on the file), not the more recently read.
- Never `Read` a SKILL.md, ADR or CONTEXT.md because it *might* be relevant — open the named section. Never re-explore a module across sessions; the outcome lives in code, commits or `CONTEXT.md`.
