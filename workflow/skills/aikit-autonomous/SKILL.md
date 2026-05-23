---
name: aikit-autonomous
description: SPIKE / opt-in. Autonomous backlog grinder — drains issues labeled `ready-for-agent` one at a time, fresh agent context per issue, persistent progress log. Wraps aikit-tdd → aikit-review → aikit-ship. Use when the user wants an AFK queue-drain run, references "Ralph pattern", or invokes `/aikit-autonomous`. Spike status — see docs/spikes/aikit-autonomous-ralph.md before relying on it.
---

# Autonomous backlog grinder

> **Status:** spike draft (2026-05-23). Tracks
> [#17](https://github.com/yusufkaracaburun/ai-kit/issues/17). Do not
> wire into `aikit-setup` until first real-queue drain succeeds. See
> [docs/spikes/aikit-autonomous-ralph.md](../../../docs/spikes/aikit-autonomous-ralph.md).

Drains a `ready-for-agent` queue by running ai-kit's existing
TDD → review → ship loop, one issue at a time, with cold-start
context per iteration. Pattern is adapted from Geoffrey Huntley's
"Ralph" and `snarktank/ralph` — fresh-instance-per-story, persistent
`progress.txt`, git-log-as-memory.

## Relationship to other ai-kit skills

| Skill | Role in this loop |
| ----- | ----------------- |
| `aikit-triage` | Produces the queue (`ready-for-agent` label) |
| `aikit-tdd` | Inner loop per issue |
| `aikit-review` | Pre-merge verification per issue |
| `aikit-ship` | PR open + (project-policy) merge |
| `aikit-autonomous` | **This skill** — orchestrates the above across N issues |

## Relationship to `/loop`

`/loop` is a scheduler, this skill is a worker. Use either:

- **Manual:** `/aikit-autonomous` — drains one issue, exits.
- **Scheduled:** `/loop 600s /aikit-autonomous` — `/loop` schedules
  fresh fires; each fire processes one issue and exits. Fresh-context
  invariant preserved because `/loop` re-invokes the slash command
  cleanly.

This skill MUST NOT call `ScheduleWakeup` or recurse — that would
tangle scheduler/worker concerns and break cold-start iteration.

## Modes

| Mode | Behavior |
| ---- | -------- |
| `dry-run` *(default)* | Pick next issue, print plan, exit. No git, no PR, no log mutation. |
| `one` | Drain exactly one issue end-to-end, then exit. |
| `drain` | Drain until queue empty or stop condition hit. |

Invocation: `/aikit-autonomous` (= `dry-run`), `/aikit-autonomous one`,
`/aikit-autonomous drain`.

## Process (one iteration)

1. **Read state.** `cat .ai-kit/autonomous/progress.txt` (cold). Note
   the last `pick` line that has no matching `exit-*` — that's an
   abandoned iteration; surface it and stop.
2. **Pick next issue.** `gh issue list --label ready-for-agent --json number,title,updatedAt --jq 'sort_by(.updatedAt) | .[0]'`. Oldest first. Queue empty → write `exit-empty`, stop.
3. **Read Agent Brief.** `gh issue view <n> --comments` — find the
   `## Agent Brief` comment. Missing or thin (no acceptance criteria)
   → write `exit-gate brief-thin`, stop.
4. **Branch.** `git switch -c agent/issue-<n>-<slug>` from the
   project's default branch. Fail-fast if dirty working tree.
5. **TDD.** Invoke `aikit-tdd` against the Agent Brief's acceptance
   criteria. Hard cap: each red→green cycle gets ≤3 attempts. Cap
   hit → `exit-gate tdd-stuck`, leave branch for human.
6. **Review.** Invoke `aikit-review` in `comprehensive` mode with
   security depth `deep`. Any **Blocker** or security finding ≥ `high`
   → `exit-gate review-blocked`, leave branch for human.
7. **Ship.** Invoke `aikit-ship` to open a PR. **Never auto-merge.**
   The project's merge policy (CI, approval, branch protection) is
   the safety net.
8. **Log.** Append `ship-ok` line to `progress.txt`. Loop continues
   (mode `drain`) or exits (mode `one`).

## Stop conditions

Always exit with a one-line `exit-*` entry in `progress.txt`:

| Trigger | Event tag | Action |
| ------- | --------- | ------ |
| Queue empty | `exit-empty` | Normal termination |
| Brief missing / thin | `exit-gate brief-thin` | Human re-triage |
| TDD cap (≤3 attempts per cycle) | `exit-gate tdd-stuck` | Human implementation |
| Review blockers | `exit-gate review-blocked` | Human review |
| Security ≥ high | `exit-gate security` | Human review |
| Push needs force / conflict resolution | `exit-gate git-conflict` | Human resolution |
| `max_iterations` reached | `exit-cap` | User re-invokes |
| Unexpected error | `exit-error <reason>` | Inspect log |

Default `max_iterations` = 5.

## `progress.txt` schema

Path: `.ai-kit/autonomous/progress.txt`. Append-only, one event per line:

```
<ISO-8601 ts>\t<issue#>\t<event>\t<detail>
```

Events: `pick`, `brief-ok`, `tdd-green`, `review-pass`, `ship-ok`,
`exit-empty`, `exit-gate`, `exit-cap`, `exit-error`.

Example trace:

```
2026-05-23T10:00:00Z	42	pick	feat: foo
2026-05-23T10:00:05Z	42	brief-ok	5 criteria
2026-05-23T10:02:30Z	42	tdd-green	cycles=4
2026-05-23T10:03:10Z	42	review-pass	mode=comprehensive
2026-05-23T10:03:45Z	42	ship-ok	pr=#101
2026-05-23T10:03:46Z	43	pick	fix: bar
2026-05-23T10:04:00Z	43	exit-gate	brief-thin
```

The next iteration reads this cold — no in-context memory required.

## Trust model

- **Never auto-merge.** Open PRs only. Project merge policy enforces
  the gate.
- **Never bypass CI / branch protection.** No `--no-verify`, no
  `--force` pushes.
- **Never silently widen scope.** If TDD or review reveals adjacent
  bugs, write a note in the PR description and stop — do not fix
  unrelated issues in the same PR.

## Limitations (spike-stage)

- No parallel iteration (out of scope per #17).
- No automatic queue re-triage when `exit-gate` fires.
- No resume-from-last-pick on stale `progress.txt` (manual cleanup).
- Not yet wired into `aikit-setup`. Hand-install only.
- Not yet validated on a real `ready-for-agent` issue. First production
  drain unblocks promotion from spike → released.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `aikit-retro` can
spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-autonomous start
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-autonomous done   # or `abort` if you bail
```

Silent no-op when the env var is unset. See
[SECURITY.md](../../../SECURITY.md) for what is logged and where.
