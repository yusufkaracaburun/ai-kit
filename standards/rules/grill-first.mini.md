---
name: grill-first
description: Never jump to plan or implementation from an issue/PRD/spec — open with grill questions first, even when the source doc looks complete
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Grill before plan

When the user hands over an issue reference, PRD, spec, ADR, or memory anchor
and asks for work to begin, do **not** start with a plan, breakdown, or code.
Open with grill questions first.

## Why

Source docs (issue bodies, PRDs, memory notes) look deterministic but are
almost always under-specified. The user may have framed the problem wrong, or
left implementation choices implicit. Discovering that mid-plan = wasted
context and a refactor cycle. Discovering it pre-plan = cheap.

Prevention beats cure.

## When the gate fires

Trigger when **any** of these is true:

- User passes an issue number, URL, or PRD/spec path.
- User says "implement this", "pak je dit op", "do issue #X", "start with X".
- Conversation context contains a plan, but no recent grill turn covering it.
- Memory anchor names a deterministic task list that has not been challenged
  in this session.

## How to apply

1. Open with 3–7 questions via `AskUserQuestion` covering at minimum:
   - **Scope split** — one PR or multiple? What ships first?
   - **Detection / trigger logic** — for any "when X happens, do Y" rule, how
     is X actually detected in the data model?
   - **Override pattern** — hard-block or escape hatch?
   - **Bundle-vs-defer** — which items in the source doc go now, which become
     follow-up issues?
   - **Data contract / scope boundaries** — what owns each piece of state?

2. Route to the right skill:
   - Domain docs exist (CONTEXT.md, ADRs, glossary) → `grill-with-docs`.
   - Otherwise → `grill-me`.

3. Wait for answers before drafting plan, issues, or code.

## When to skip

Only skip the gate when one of:

- User answered the open questions explicitly in the same turn.
- User says "go", "skip grill", "no questions", "geen vragen, gewoon doen".
- The task is a trivial single-line fix the issue body fully specifies
  (typo, lint, version bump).

## Anti-pattern

> "Issue body has scope + acceptance + source-doc pointers, so I'll plan now."

Completeness of the source doc ≠ completeness of the implementation spec.
The grill is what closes the gap.

## See also

- [`context-discipline.mini.md`](./context-discipline.mini.md) — token budget;
  use sub-agents for any wide exploration the grill surfaces.
- `grill-me`, `grill-with-docs` skills — the actual question-asking
  workflows.
