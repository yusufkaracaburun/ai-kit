---
name: next
description: Ranked "what's next" list for the current project — combines open GitHub issues (Priority issue field and project Status field first, P0-P3 + status:in-progress + ready-for-agent labels as fallback), roadmap-only tasks, and setup-deferred branches into one prioritized backlog. Use when the user asks "wat is open", "what's next", "wat moet ik nu doen", "openstaande taken", "status van het project", "hoogste prioriteit", or invokes /ai:next.
---

# next

Show the highest-value open work for this project, ordered. Three sources merged into one ranked list:

1. **GitHub issues** — `gh issue list --state open`, plus two `gh api graphql` calls: one reads each issue's Priority issue field (matched by name), the other the Status field of its GitHub Projects items. The Priority issue field wins; `P0-`/`P1-`/`P2-`/`P3-` labels (installed by `setup-gh-workflow.sh`) are the fallback for repos without a board. Bonus for `status:in-progress` or Status Doing (finish before start) and `ready-for-agent` or Status Next (queue-drainable). Items with Status Blocked or Done are left out. A card in Doing or Next that still carries `needs-triage` or `needs-info` gets one warning line above the list; ranking does not change. Each call fails on its own (no network, missing scope) and that part falls back to labels. Status needs the `read:project` scope; add it with `gh auth refresh -s read:project`.
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
| Priority issue field Urgent, else `P0-…` label | +1000 |
| Priority issue field High, else `P1-…` label | +100 |
| Priority issue field Medium, else `P2-…` label | +10 |
| Priority issue field Low, else `P3-…` label | +1 |
| No Priority issue field and no P label (default) | +5 |
| `status:in-progress` label or Status Doing (counted once) | +50 |
| `ready-for-agent` label or Status Next (counted once) | +20 |
| Status Backlog | +0 |
| Status Blocked or Done | left out of the list |
| `area/<x>` matches current branch | +10 |
| Per week since last update | -1 |

Highest score first. Tie-broken by recency.

## When to use which next-step suggestion

The top item drives the recommendation. Propose it; do not run it. The user picks.

- **Status Doing or `status:in-progress`** → continue the existing branch / WIP. Do not start anything new.
- **`ready-for-agent`** → `/ai:autonomous` to drain the queue (or hand the issue # to a fresh chat).
- **Roadmap-only** → `/ai:to-prd defer` to open a GH issue + roadmap link (so it earns a P-label).
- **Setup-deferred** → re-run `/ai:setup` and pick `change` on the relevant branch.
- **Generic open GH issue** → `/ai:to-issues` to break into vertical slices, or `/ai:tdd` to implement.

Only in the ai-kit repo (`workflow/skills/workflow-audit/` exists): when the date in the newest `docs/audits/workflow-audit-<date>.md` filename is over 30 days old, add one line under the list: `last workflow audit N days ago, run /ai:workflow-audit`; when no such file exists, `no workflow audit yet, run /ai:workflow-audit`.

## Not this skill

- **`/ai:status`** — single project's setup-marker + version, not a backlog.
- **`/ai:resume`** — session continuation from the latest checkpoint memo.
- **`/ai:triage`** — process for *creating* issues, not for ranking existing ones.
