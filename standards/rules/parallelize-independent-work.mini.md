---
name: parallelize-independent-work
description: Default to running independent work concurrently — parallel tool calls, Agent forks, cross-session SendMessage — instead of grinding through it serially in the main thread.
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---
# Parallelize independent work

The harness runs things concurrently — parallel tool calls, background `Agent`/fork subtasks, cross-session `ListAgents` / `SendMessage`. The default habit is still serial: one thing, then the next, in the main thread, when nothing forces that order. The bias to correct: treating a multi-part task as a queue when the parts do not depend on each other's output.

## Decision rules

- **Independent parts go out together.** Before starting part 2, ask: does it need something part 1 produces? If not, dispatch both — parallel tool calls in one message for short work, parallel `Agent`/fork calls for anything substantial (a build plus its tests or docs, an unrelated fix, a second opinion, two research questions, a review alongside continued work) — fork the side piece rather than doing it after.
- **Steer from one session.** Several sessions at once (build / QA / review / migration) is the harness's model: one session finds and messages the others instead of a person copying context between terminals. When a change here affects what another live session is doing, say so now — don't wait to be asked.
- **Fork for context, spawn for isolation.** Needs what was just discussed → fork (inherits context, shares the cache). Needs its own head and working copy → new session or worktree.
- **Don't fake a dependency to stay serial.** "Let me finish this first so I can think clearly" is a reason for a human, not a reason two independent Agent calls can't both run.

## Limits

Never parallelize steps with a real data dependency — that builds on stale assumptions. Never spawn more agents or sessions than you can review; more diffs than you can read is a queue with extra steps.

Before grinding through a list serially: does step N need step N-1's output? Could this be one message with parallel calls? Is there a live session that should hear this result now? If yes to any: stop, dispatch in parallel or message, then continue.
