---
name: grill-first
description: Never jump to plan or implementation from an issue/PRD/spec — open with grill questions first, then name the ai-kit phase and skill that carry the work
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

When the user hands over an issue, PRD, spec, ADR or memory anchor and asks for work to begin, do **not** start with a plan, breakdown or code. Grill first. Source docs look deterministic but are under-specified: the framing may be wrong, implementation choices implicit. Finding that mid-plan costs a refactor cycle; pre-plan it is cheap.

## When the gate fires

Any of: an issue number / URL / spec path is passed · "implement this", "pak je dit op", "do issue #X", "start with X" · context holds a plan with no recent grill turn covering it · a memory anchor names a task list not challenged this session.

## How

1. Open with 3–7 questions via `AskUserQuestion`, at minimum: **scope split** (one PR or several, what ships first), **detection / trigger logic** (how is "when X happens" actually detected in the data), **override pattern** (hard block or escape hatch), **bundle vs defer** (what goes now, what becomes a follow-up issue), **data contract** (what owns each piece of state).
2. Route: domain docs exist (`CONTEXT.md`, ADRs, glossary) → `grill-with-docs`; otherwise → `grill-me`.
3. Wait for the answers before drafting plan, issues or code.
4. Then name, out loud, the phase the work sits in and the skill that carries it — an unnamed phase is how the workflow gets skipped while the work still looks fine:

   | Phase | Skill |
   | ----- | ----- |
   | Ideation — scope, requirements | `grill-with-docs`, `to-prd` |
   | Development — backlog → build | `to-issues` → `triage` → `tdd` |
   | Testing — test & fix | `tdd`, `review`, `qa`, `diagnose` |
   | Deployment — release | the project's release procedure (deployment-on-demand rule) |
   | Ops — feedback, retrospective | `retro` |

   Check `/ai:next` before opening a new issue; `/ai:which` when unsure of the skill.

## Skip only when

The user answered the open questions in the same turn · says "go", "skip grill", "no questions", "geen vragen, gewoon doen" · the task is a trivial one-liner the issue body fully specifies (typo, lint, version bump).

Completeness of the source doc ≠ completeness of the implementation spec; the grill closes the gap. See `grill-me` / `grill-with-docs` (the workflows) and `bin/hooks/phase-check.sh` (the enforcement half on Claude Code — it repeats the table on every work-start prompt; wire it with `bin/apply-phase-check-hook.sh` where `/ai:setup` has not).
