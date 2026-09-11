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

The harness supports real concurrency — parallel tool calls, background
`Agent`/fork subtasks, and cross-session messaging via `ListAgents` /
`SendMessage`. The default habit is still serial: one thing, then the next,
in the main thread, even when nothing forces that order. Serial-by-default
wastes wall-clock the tooling already solves.

## Primary bias to correct

Treating a multi-part task as a single queue to work through top to bottom,
when the parts don't actually depend on each other's output.

## Decision rules

- **Independent parts → parallel dispatch, not a queue.** Before starting
  part 2 of a task, ask: does 2 need something part 1 produces? If no, part 1
  and 2 should go out together — parallel tool calls in one message for
  short work, parallel `Agent`/fork calls for anything substantial (a build
  plus its test-writing, two unrelated research questions, a review running
  alongside continued work).
- **Steer from one session, don't context-switch by hand.** Several Claude
  Code sessions running at once (build / QA / review / migration) is the
  harness's own model for this — one session can find and message the others
  (`ListAgents` / `SendMessage`) instead of a person copying context between
  terminals. When a change in this session affects what another live session
  is doing, say so — don't wait to be asked.
- **Fork for context, spawn for isolation.** A task that needs what was just
  discussed → fork (inherits context, shares the cache). A task that needs
  its own head and its own working copy → a new session or worktree, not a
  fork.
- **Don't fake a dependency to justify going serial.** "Let me finish this
  first so I can think clearly" is a reason for a human, not a reason two
  independent Agent calls can't both run now.

## Trigger rules

- **A task has a clearly separable side piece** (tests, docs, a second
  opinion, an unrelated fix) — fork it rather than doing it after.
- **Another live session's work depends on something this session just
  changed** — message it now, don't leave it to find out later.

## What NOT to do

- Don't parallelize steps with a real data dependency just to look fast —
  that produces work built on stale assumptions.
- Don't spawn more parallel sessions/agents than you can actually review;
  more diffs than you can read is not throughput, it's a queue with extra
  steps.

## Final checklist before grinding through a list serially

- Does step N actually need step N-1's output?
- Could this have gone out as one message with parallel tool/Agent calls?
- Is there a live session this result should be told to, right now?
- If yes to any: stop, dispatch in parallel or message, then continue.
