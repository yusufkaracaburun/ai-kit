# Spike — `aikit-autonomous` (Ralph pattern)

> **Status:** SPIKE — exploratory artifact. Not yet a shippable skill.
> Tracks [#17](https://github.com/yusufkaracaburun/ai-kit/issues/17).
> Date: 2026-05-23.

## Question

Does the Geoffrey-Huntley / `snarktank/ralph` autonomous-loop mechanic
(fresh-instance-per-story + persistent `progress.txt` + git-log-as-memory)
fit ai-kit's deliberate-HITL lifecycle, and if so, how should it ship?

## Mechanic, recapped

Ralph's invariants:

1. **One issue per agent context.** Long-running contexts drift; fresh
   contexts don't accumulate cruft.
2. **State lives on disk, not in-context.** `progress.txt` + git log are
   the durable memory. The next iteration reads them cold.
3. **Loop until queue empty or gate.** No interactive prompts mid-loop;
   any uncertainty short-circuits to a human gate (uncommitted PR, open
   question, failing test).

## Mapping to ai-kit primitives

| Ralph element | ai-kit mapping |
| ------------- | -------------- |
| Story queue | `gh issue list --label ready-for-agent` (already produced by `aikit-triage`) |
| Per-story spec | Agent Brief comment (already structured per `aikit-triage/AGENT-BRIEF.md`) |
| Implement | `aikit-tdd` invocation |
| Verify | `aikit-review` invocation |
| Commit + close | `aikit-ship` invocation (PR + merge per project policy) |
| Persistent log | `.ai-kit/autonomous/progress.txt` |
| Fresh instance | `Task` tool with a dedicated `aikit-autonomous-runner` subagent, OR `/loop` scheduling fresh top-level invocations |

The queue + per-story spec already exist as first-class ai-kit
concepts. Ralph's contribution is the **discipline of cold-start
iteration** — not new primitives.

## Three open design questions from the issue

### Q1. Sibling skill, flag on existing skill, or separate plugin?

**Verdict: sibling skill.**

- *Flag on existing skill* — fragile. Which skill carries the flag?
  `aikit-tdd --autonomous` is wrong (TDD is the inner loop, not the
  orchestrator). A standalone skill is the natural fit because the
  unit of work is "drain the queue", not "implement one feature".
- *Separate plugin* — overkill for one skill. Plugin distribution
  exists for cross-cutting bundles. Revisit only if the autonomous
  layer grows to ≥3 skills (e.g., `aikit-autonomous-status`,
  `aikit-autonomous-resume`, `aikit-autonomous-cancel`).
- *Sibling skill* — matches the existing pattern. Lives at
  `workflow/skills/aikit-autonomous/SKILL.md`. Logs via
  `bin/log-skill.sh` like every other skill.

### Q2. Conflict with `/loop`?

**Verdict: complementary, not competing.**

- `/loop` is a **scheduler** — repeats a single prompt or slash command
  on an interval (or self-paced) with cache-aware wakeups.
- `aikit-autonomous` is a **worker** — picks one issue, runs the full
  TDD → review → ship sequence, commits state to `progress.txt`,
  exits.

Two valid composition patterns:

1. **Manual driver:** user invokes `/aikit-autonomous` once per
   iteration. Skill exits after one issue; user re-invokes when ready.
2. **Scheduled driver:** user invokes
   `/loop 600s /aikit-autonomous` — `/loop` handles the scheduling +
   cache-warm wakeups; the skill handles one issue per fire and exits
   cleanly. The fresh-instance invariant is preserved because each
   `/loop` fire is a fresh slash-command invocation.

The skill **must not** internally call `ScheduleWakeup` or chain
itself — that would tangle scheduler/worker concerns and break the
fresh-context invariant.

### Q3. Does the mechanic work on a real ai-kit issue queue?

**Smoke-tested:** `gh issue list --label ready-for-agent --json number,title`
on this repo returns 0 results today (open issues are `#15` brainstorm
and `#17` this spike — neither is `ready-for-agent`). The queue
mechanic works; the queue is just empty. Real validation requires
`aikit-triage`'ing a small issue to `ready-for-agent` and watching the
loop drain it. Defer that to the first production-use spike, not this
design spike.

## Stop conditions (must be explicit)

The skill exits — never silently continues — on any of:

| Trigger | Reason |
| ------- | ------ |
| Queue empty | Normal termination |
| Agent Brief missing or thin | Cannot proceed cold without a contract |
| `aikit-tdd` cycle introduces a failing test that won't go green in ≤3 attempts | Tighter than human TDD because there is no human to ask "is this the right test?" |
| `aikit-review` returns `REQUEST CHANGES` with any **Blocker** | Hand back to human |
| Security finding at `high` or above | Hand back to human |
| Push/merge would require force-push or conflict resolution | Hand back to human |
| `max_iterations` reached (config, default 5) | Safety cap; user re-invokes |

Every exit writes a one-line entry to `progress.txt` with the reason.

## `progress.txt` schema

Append-only, one event per line. Format:

```
<ISO-8601 timestamp>\t<issue#>\t<event>\t<detail>
```

Events: `pick`, `brief-ok`, `tdd-green`, `review-pass`, `ship-ok`,
`exit-empty`, `exit-gate`, `exit-error`. Trivially `grep`-able for
the next iteration to learn what already happened.

`git log` carries the *code* memory; `progress.txt` carries the
*orchestration* memory.

## Trust model

Same posture as `/aikit-recommend-rules` and `/aikit-recommend-tools`:
**never auto-merge to `main`/`master`.** The skill opens a PR; the
project's existing merge policy (CI green, human approval, branch
protection) is the actual safety net. ai-kit does not bypass it.

For the spike, the skill draft documents `dry-run` as the default
mode — surfaces what *would* happen across the queue without
touching git.

## Decision matrix vs. just shipping `aikit-tdd` in a loop

| Concern | `/loop /aikit-tdd` (status quo) | `aikit-autonomous` |
| ------- | ------------------------------- | ------------------- |
| Picks next issue automatically | No | Yes |
| Persists cross-iteration state | No (context drift) | Yes (`progress.txt`) |
| Explicit human-gate triggers | No | Yes |
| Fresh-context invariant | Only if user `/clear`s between fires | Built in |
| Integrates with `aikit-triage` queue | No | Yes |

The status quo *can't* drain a backlog unsupervised; the spike
artifact can.

## Recommendation

Ship a **draft** of `workflow/skills/aikit-autonomous/SKILL.md` with:

- `dry-run` as default mode (logs what it would do, touches nothing)
- explicit stop conditions
- `progress.txt` schema documented
- complementary-not-competing note re `/loop`

Do **not** wire it into the plugin or `aikit-setup` until the first
real-queue drain succeeds end-to-end. Treat as opt-in, hand-installed
during the validation period.

## Follow-ups (out of scope for spike)

- `bin/autonomous.sh` helper (queue read, progress-log append) once
  the skill stabilises.
- Parallel iteration (Ralph's `--parallel` flag) — explicitly out of
  scope per #17.
- `aikit-autonomous-resume` companion skill — only if `progress.txt`
  proves insufficient for context recovery after long pauses.
