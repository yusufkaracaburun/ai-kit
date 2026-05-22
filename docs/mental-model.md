# Mental model

How the 20 skills fit together, plus the 3 subagents and 5 slash commands they call. Read this once; refer back when picking the right skill (or subagent, or command) for a turn.

For "what is a skill vs a subagent vs a slash command?" see [glossary.md](glossary.md). For "I want to add X — which primitive?" see [primitives.md](primitives.md).

## The lifecycle loop

```
   ┌─→ IDEATION      aikit-grill-me · aikit-grill-with-docs · aikit-zoom-out ·
   │                 aikit-to-prd · aikit-prototype
   │      │
   │      ▼
   │   DEVELOPMENT   aikit-to-issues → aikit-triage → aikit-tdd
   │      │
   │      ▼
   │   TESTING       aikit-review · aikit-qa · aikit-diagnose
   │      │
   │      ▼
   │   DEPLOYMENT    aikit-ship
   │      │
   │      ▼
   │   OPS & REVIEW  aikit-retro · aikit-handoff
   │      │
   └──────┘

   Cross-cutting:   aikit-setup · aikit-recommend-rules · aikit-recommend-tools ·
                    aikit-improve-codebase-architecture
```

## Which skill, when

| You are about to … | Use this skill |
| ------------------ | -------------- |
| Stress-test an idea by being interviewed | `aikit-grill-me` |
| Read external docs deeply and apply them | `aikit-grill-with-docs` |
| Understand unfamiliar code at a layer up | `aikit-zoom-out` |
| Turn a vague idea into a PRD | `aikit-to-prd` |
| Throw a quick prototype together | `aikit-prototype` |
| Turn a PRD into actionable tickets | `aikit-to-issues` |
| Pick the next ticket to work on | `aikit-triage` |
| Build a feature via red-green-refactor | `aikit-tdd` |
| Get a second pass on a diff before PR | `aikit-review` |
| Smoke-test a running web app | `aikit-qa` |
| Hunt a hard bug or perf regression | `aikit-diagnose` |
| Open the PR and prepare to merge | `aikit-ship` |
| Close a sprint or cycle | `aikit-retro` |
| Save context for a fresh session | `aikit-handoff` |
| Configure ai-kit in a new repo | `aikit-setup` |
| Reshape the codebase architecture | `aikit-improve-codebase-architecture` |
| Save context for `/clear`, resume later | `aikit-checkpoint` ↔ `aikit-resume` |
| Recommend canonical rules for the detected stack | `aikit-recommend-rules` |
| Wire optional companion tools (graphify, caveman) | `aikit-recommend-tools` |

## Subagents (Claude Code only)

| You are running … | Delegate to … |
| ----------------- | -------------- |
| `aikit-review` skill on Claude Code | `aikit-reviewer` (full pre-merge review with structured markdown report) |
| `aikit-qa` skill on Claude Code | `aikit-qa-runner` (full QA pass — Playwright/CLI tests, structured findings report; large browser output stays isolated) |
| Codebase walk from `aikit-diagnose`, `aikit-to-issues`, `aikit-improve-codebase-architecture` | `aikit-explore` (read-only sweeps, ≤300 lines, structured return) |
| Cross-file impact analysis from any other skill | `aikit-explore` |

Subagents are Claude Code-only. Cursor and other hosts fall back to the inline checklist inside the calling skill — single source of truth.

## Slash commands (IDE-native diagnostics)

| You want to … | Use this slash command |
| ------------- | ----------------------- |
| Check ai-kit install health from inside the chat | `/aikit-doctor` |
| Route an intent to the right skill | `/aikit-which "<your intent>"` |
| Show project ai-kit status (version, marker, drift) | `/aikit-status` |
| Toggle the global-check opt-out | `/aikit-no-globals on\|off\|status` |
| Re-stamp the project marker after pulling new ai-kit | `/aikit-upgrade` |

Slash commands wrap `bin/ai-kit-*.sh` scripts. They're optional — you can always run the underlying script directly.

## Dependencies between skills

- `aikit-tdd` reads ADRs in the area you're touching (uses domain glossary from `CONTEXT.md`).
- `aikit-review` checks alignment with `CONTEXT.md` and recent ADRs — it expects them to exist.
- `aikit-ship` runs after `aikit-review` is clean.
- `aikit-retro` reads usage-stats (opt-in) from `bin/usage-stats.sh` to ground questions in observed behaviour.
- `aikit-diagnose` builds its feedback loop *first*; everything else is mechanical.

## The three habits the kit encodes

1. **Vertical slices over horizontal.** One test → one impl → repeat. Don't write all tests then all code. Encoded in `aikit-tdd`.
2. **Build the feedback loop first.** A failing test, a curl, a Playwright script — *something* that gives pass/fail in seconds. Encoded in `aikit-diagnose`.
3. **Make decisions visible.** Domain in `CONTEXT.md`, decisions in `docs/adr/`, agent config in `docs/agents/`. The skills lean on these; if they're missing, the skills get vaguer.

## What ai-kit deliberately does NOT do

- It does not run code for you.
- It does not auto-commit (each skill suggests; you approve).
- It does not send anything to the network (the opt-in usage log is local-only).
- It does not lock you to a stack — there are no curated lists of "good" frameworks. `dev-environment.md` is filled from your repo's detected tooling.
- It does not impose a methodology — Scrum and Kanban are both supported as optional Tier B.

See [architecture.md](architecture.md) for how primitives reach the host, [eval.md](eval.md) for how to verify the skills haven't drifted, and the [examples](../.examples/) for setup walkthroughs.
