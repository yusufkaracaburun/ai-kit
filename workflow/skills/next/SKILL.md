---
name: next
description: Ranked "what's next" list for the current project — combines open GitHub issues (P0-P3 + status:in-progress + ready-for-agent labels), roadmap-only tasks, and setup-deferred branches into one prioritized backlog. Use when the user asks "wat is open", "what's next", "wat moet ik nu doen", "openstaande taken", "status van het project", "hoogste prioriteit", or invokes /ai:next.
---

# next

Show the highest-value open work for this project, ordered. Three sources merged into one ranked list:

1. **GitHub issues** — `gh issue list --state open`. Priority via `P0-`/`P1-`/`P2-`/`P3-` labels (installed by `setup-gh-workflow.sh`). Bonus for `status:in-progress` (finish before start) and `ready-for-agent` (queue-drainable).
2. **Roadmap-only tasks** — open `- [ ] …` checkboxes in `docs/roadmap.md` (or `ROADMAP.md` / `.planning/roadmap.md`). Closed `[x]` and free prose bullets are skipped.
3. **Setup-deferred branches** — anything in `.ai-kit-setup` with value `"deferred"` (e.g. `automation_recommender: deferred`).

## How to invoke

```bash
$AI_KIT_ROOT/bin/ai-kit-next.sh [PATH] [--limit N] [--no-gh] [--no-roadmap] [--json]
```

- Default `PATH` = current dir.
- Default `--limit 10`.
- `--no-gh` if offline or no remote.
- `--json` for machine-readable output (when chaining into another tool).

## Scoring (deterministic)

| Signal | Score |
| ------ | ----- |
| `P0-…` label | +1000 |
| `P1-…` label | +100 |
| `P2-…` label | +10 |
| `P3-…` label | +1 |
| Unlabelled (default) | +5 |
| `status:in-progress` | +50 |
| `ready-for-agent` | +20 |
| `area/<x>` matches current branch | +10 |
| Per week since last update | -1 |

Highest score first. Tie-broken by recency.

## When to use which next-step suggestion

The top item drives the recommendation:

- **`status:in-progress`** → continue the existing branch / WIP. Do not start anything new.
- **`ready-for-agent`** → `/ai:autonomous` to drain the queue (or hand the issue # to a fresh chat).
- **Roadmap-only** → `/ai:to-prd defer` to open a GH issue + roadmap link (so it earns a P-label).
- **Setup-deferred** → re-run `/ai:setup` and pick `change` on the relevant branch.
- **Generic open GH issue** → `/ai:to-issues` to break into vertical slices, or `/ai:tdd` to implement.

## Not this skill

- **`/ai:status`** — single project's setup-marker + version, not a backlog.
- **`/ai:resume`** — session continuation from the latest checkpoint memo.
- **`/ai:triage`** — process for *creating* issues, not for ranking existing ones.
