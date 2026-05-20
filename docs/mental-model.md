# Mental model

How the 16 skills fit together. Read this once; refer back when picking the right skill for a turn.

## The lifecycle loop

```
                ┌─────────────────────────────────────────────────┐
                │                                                 │
                ▼                                                 │
        ┌──────────────┐                                          │
        │  IDEATION    │   grill-me · grill-with-docs             │
        │              │   zoom-out · to-prd · prototype          │
        └──────┬───────┘                                          │
               │                                                  │
               ▼                                                  │
        ┌──────────────┐                                          │
        │ DEVELOPMENT  │   to-issues → triage → tdd               │
        └──────┬───────┘                                          │
               │                                                  │
               ▼                                                  │
        ┌──────────────┐                                          │
        │   TESTING    │   review · qa · diagnose                 │
        └──────┬───────┘                                          │
               │                                                  │
               ▼                                                  │
        ┌──────────────┐                                          │
        │ DEPLOYMENT   │   ship                                   │
        └──────┬───────┘                                          │
               │                                                  │
               ▼                                                  │
        ┌──────────────┐                                          │
        │   OPS/OPS    │   retro · handoff                        │
        └──────┬───────┘                                          │
               └──────────────────────────────────────────────────┘

   Cross-cutting:  setup · improve-codebase-architecture
```

## Which skill, when

| You are about to … | Use this skill |
| ------------------ | -------------- |
| Stress-test an idea by being interviewed | `grill-me` |
| Read external docs deeply and apply them | `grill-with-docs` |
| Understand unfamiliar code at a layer up | `zoom-out` |
| Turn a vague idea into a PRD | `to-prd` |
| Throw a quick prototype together | `prototype` |
| Turn a PRD into actionable tickets | `to-issues` |
| Pick the next ticket to work on | `triage` |
| Build a feature via red-green-refactor | `tdd` |
| Get a second pass on a diff before PR | `review` |
| Smoke-test a running web app | `qa` |
| Hunt a hard bug or perf regression | `diagnose` |
| Open the PR and prepare to merge | `ship` |
| Close a sprint or cycle | `retro` |
| Save context for a fresh session | `handoff` |
| Configure ai-kit in a new repo | `setup` |
| Reshape the codebase architecture | `improve-codebase-architecture` |

## Dependencies between skills

- `tdd` reads ADRs in the area you're touching (uses domain glossary from `CONTEXT.md`).
- `review` checks alignment with `CONTEXT.md` and recent ADRs — it expects them to exist.
- `ship` runs after `review` is clean.
- `retro` reads usage-stats (opt-in) from `bin/usage-stats.sh` to ground questions in observed behaviour.
- `diagnose` builds its feedback loop *first*; everything else is mechanical.

## The three habits the kit encodes

1. **Vertical slices over horizontal.** One test → one impl → repeat. Don't write all tests then all code. Encoded in `tdd`.
2. **Build the feedback loop first.** A failing test, a curl, a Playwright script — *something* that gives pass/fail in seconds. Encoded in `diagnose`.
3. **Make decisions visible.** Domain in `CONTEXT.md`, decisions in `docs/adr/`, agent config in `docs/agents/`. The skills lean on these; if they're missing, the skills get vaguer.

## What ai-kit deliberately does NOT do

- It does not run code for you.
- It does not auto-commit (each skill suggests; you approve).
- It does not send anything to the network (the opt-in usage log is local-only).
- It does not lock you to a stack — there are no curated lists of "good" frameworks. `dev-environment.md` is filled from your repo's detected tooling.
- It does not impose a methodology — Scrum and Kanban are both supported as optional Tier B.

See [eval.md](eval.md) for how to verify the skills haven't drifted, and the [examples](../.examples/) for setup walkthroughs.
