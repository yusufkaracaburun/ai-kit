# Mental model

How the 27 skills fit together, plus the 3 subagents and 8 slash commands they call. Read this once; refer back when picking the right skill (or subagent, or command) for a turn.

For "what is a skill vs a subagent vs a slash command?" see [glossary.md](glossary.md). For "I want to add X — which primitive?" see [primitives.md](primitives.md).

## The lifecycle loop

```
   ┌─→ IDEATION      grill-me · grill-with-docs · zoom-out ·
   │                 to-prd · prototype
   │      │
   │      ▼
   │   DEVELOPMENT   to-issues → triage → tdd
   │      │
   │      ▼
   │   TESTING       review · qa · diagnose
   │      │
   │      ▼
   │   DEPLOYMENT    ship
   │      │
   │      ▼
   │   OPS & REVIEW  retro · handoff
   │      │
   └──────┘

   Cross-cutting:   setup · recommend-rules · recommend-tools ·
                    improve-codebase-architecture
```

## Which skill, when

| You are about to … | Use this skill |
| ------------------ | -------------- |
| Stress-test an idea by being interviewed | `grill-me` |
| Read external docs deeply and apply them | `grill-with-docs` |
| Understand unfamiliar code at a layer up | `zoom-out` |
| Turn a vague idea into a PRD | `to-prd` |
| Throw a quick prototype together | `prototype` |
| Shatter a plan / PRD into N independently-grabbable tracer-bullet issues | `to-issues` |
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
| Save context for `/clear`, resume later | `checkpoint` ↔ `resume` |
| Recommend canonical rules for the detected stack | `recommend-rules` |
| Wire optional companion tools (graphify, caveman) | `recommend-tools` |
| Defer ONE surfaced lead — one issue + one roadmap paragraph (not for breaking down planned work; use `to-issues` for that) | `to-prd` (defer mode) |
| Drain a `ready-for-agent` queue end-to-end (spike) | `autonomous` |

## Subagents (Claude Code only)

| You are running … | Delegate to … |
| ----------------- | -------------- |
| `review` skill on Claude Code | `reviewer` (full pre-merge review with structured markdown report) |
| `qa` skill on Claude Code | `qa-runner` (full QA pass — Playwright/CLI tests, structured findings report; large browser output stays isolated) |
| Codebase walk from `diagnose`, `to-issues`, `improve-codebase-architecture` | `explore` (read-only sweeps, ≤300 lines, structured return) |
| Cross-file impact analysis from any other skill | `explore` |

Subagents are Claude Code-only. Cursor and other hosts fall back to the inline checklist inside the calling skill — single source of truth.

## Slash commands (IDE-native diagnostics)

| You want to … | Use this slash command |
| ------------- | ----------------------- |
| Check ai-kit install health from inside the chat | `/ai:doctor` |
| Route an intent to the right skill | `/ai:which "<your intent>"` |
| Show project ai-kit status (version, marker, drift) | `/ai:status` |
| Toggle the global-check opt-out | `/ai:no-globals on\|off\|status` |
| Re-stamp the project marker after pulling new ai-kit | `/ai:upgrade` |
| Defer a lead in one shot (issue + roadmap entry) | `/ai:to-prd defer "<lead>"` |

Slash commands wrap `bin/ai-kit-*.sh` scripts. They're optional — you can always run the underlying script directly.

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

See [architecture.md](architecture.md) for how primitives reach the host, [eval.md](eval.md) for how to verify the skills haven't drifted, and the [examples](../.examples/) for setup walkthroughs.
