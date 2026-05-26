---
name: audit-fix
description: Apply atomic per-finding fixes from a `/ai:audit-architecture` report. One commit per finding, per-finding user approval (or `--batch` with severity filter), affected-paths-only scope, re-run the touched dimension after each fix, rewrite the report row to `✅ fixed`. Use when user says "fix the audit", "apply audit findings", "work through the audit report", or "fix finding A1".
---

# Audit Fix

Consume an `/ai:audit-architecture` report and apply atomic fixes — one
finding at a time, one commit per finding, user-approved (or batched with
a severity filter), scope-bounded to the finding's affected paths, with
read-after-write verification.

Not to be confused with:
- `/ai:audit-architecture` — the **audit** that produces the report this
  skill consumes. Read-only.
- `/ai:tdd` — red-green-refactor for **new behaviour**. Audit-fix is
  structural cleanup with behaviour preservation.
- `/ai:review` — pre-merge **diff** review.
- `/ai:improve-codebase-architecture` — deepening-opportunity hunting,
  not catalogued audit-finding remediation.

## When to invoke

Trigger phrases:
- "Fix the audit / apply audit findings / work through the audit
  report".
- "Fix finding A1" / "fix the 🔴 rows" / "do the audit cleanup".

If the user has just run `/ai:audit-architecture`, the report path is
already known from that session. Otherwise auto-discover the most recent
report in `docs/reviews/`:

```bash
ls -1t docs/reviews/*-architecture-audit.md 2>/dev/null | head -1
```

If no report exists, refuse and point at `/ai:audit-architecture`.

## Input contract

The audit report at `docs/reviews/<YYYY-MM-DD>-<scope>-architecture-audit.md`
carries one finding per row, with these fields per the audit's output
contract:

- **ID** — stable handle like `A1`, `B3`, `C2` (per dimension cluster).
- **Dimension** — one of the 9 canonical dimensions in
  `standards/rules/code-audit.mini.md`.
- **Severity** — 🔴 Blocker · 🟠 High · 🟡 Medium · 🟢 Low.
- **Affected paths** — concrete `path:line` evidence list.
- **Fix-direction** — the audit's recommended remediation sketch.

The skill refuses to act on rows missing any of these fields — that is
an audit-quality issue, not an audit-fix concern.

## Modes

| Mode | Behaviour |
| ---- | --------- |
| `interactive` *(default)* | Walk findings one at a time; prompt per finding. |
| `--batch --severity=🔴,🟠` | Skip per-finding prompt for findings in the listed severities; still emit summaries. |
| `--finding=A1[,A2,...]` | Restrict to specific IDs. |
| `--dimension=<n>` | Restrict to findings in one dimension. |

Invocation examples:

- `/ai:audit-fix` — interactive, walk every open finding in the most
  recent report.
- `/ai:audit-fix --finding=A1` — single finding, interactive.
- `/ai:audit-fix --batch --severity=🔴,🟠` — auto-fix blockers + highs
  without per-finding prompts (still commits one per finding).
- `/ai:audit-fix --dimension=DRY` — every DRY finding, interactive.

## Process per finding

1. **Read the finding** — ID, dimension, severity, affected paths,
   fix-direction. Refuse the row if any field is missing (point at the
   audit-quality issue).
2. **Show the user a fix sketch** — 1–3 sentences describing the diff
   you intend to apply and the paths you will touch. Quote the affected
   paths verbatim from the report.
3. **Wait for approval.** In `interactive` mode: prompt
   `apply / skip / abort`. Default: `apply`. In `--batch` mode with a
   matching severity: skip the prompt; log `auto-applying` inline.
4. **Apply the minimum diff.**
   - **Never touch a path outside the finding's affected-paths list.**
     If the fix can't be expressed without widening scope, abort the
     finding (record `aborted-scope-creep`) and move on — re-triage
     belongs in the audit, not here.
   - **Never bundle unrelated findings into one commit.** One commit per
     finding is the load-bearing invariant.
5. **Run relevant verification** before the commit:
   - Project test suite scoped to the affected paths if the test runner
     supports path filters (e.g. `pytest <paths>`, `vitest run <paths>`,
     `phpunit --filter <Class>`). Fall back to the full suite when
     scoping is infeasible.
   - Linter / formatter on the affected paths if configured
     (`ruff`, `eslint`, `phpstan`, `pint`).
   - Typecheck on the affected paths if configured (`mypy`, `tsc --noEmit`,
     `pyright`).
   Treat any failure as a fix-broke-something signal: revert the diff,
   record `aborted-verification-failed: <command>`, move on.
6. **Commit** with the canonical message format:
   ```
   audit-fix(<dimension>): <one-line>

   Finding <ID> from <report-path>.
   ```
   Example:
   ```
   audit-fix(DRY): extract subsidy aggregation into Coalition::totalRequestedHoursPerYear

   Finding A3 from docs/reviews/2026-05-26-naschool-architecture-audit.md.
   ```
7. **Read-after-write verification.** Re-run the **dimension** check on
   the touched paths (re-invoke `/ai:audit-architecture` scoped via
   `--paths=<affected>` or run the dimension's heuristic by hand). If a
   new finding of the **same dimension** surfaces on the same paths:
   - Treat as a regression. Log `regression-introduced: <new-finding>`
     in the report.
   - Do not revert the commit — record it and surface in the closing
     summary so the user can decide.
8. **Mark the row** in the original report as `✅ fixed` — rewrite that
   row only, leave the rest of the report intact. Add a `Closed by:
   <commit-sha>` annotation in the row.
9. **Loop** to the next finding (or exit if none left / batch filter
   exhausted).

## Refusal cases

- **Out-of-scope path.** If applying the fix needs an edit to a path not
  in the finding's `affected_paths`, refuse with `aborted-scope-creep`
  and surface the missing path so the user can re-run the audit.
- **Bundling.** If two findings' fixes share a diff, refuse to merge
  them into one commit; do them as two atomic commits even when the
  later one is a no-op against the first.
- **Missing fields.** If the finding lacks ID / dimension / severity /
  affected paths, refuse the row and point at the audit-quality issue.
- **Behaviour-change risk.** If the proposed minimum diff would
  observably change behaviour (e.g. a "DRY" extraction that subtly
  reorders side effects), refuse with `aborted-behaviour-change` and
  surface so the user can decide whether to route through `/ai:tdd`.

## Output contract

End the session by reporting:

- **Applied:** list of finding IDs, severities, commit SHAs.
- **Skipped (by user):** IDs + reason if the user typed `skip` in
  interactive mode.
- **Aborted:** IDs + abort reason (`scope-creep`, `verification-failed`,
  `behaviour-change`, `bundling`).
- **Regressions:** any same-dimension findings introduced by a fix
  (from step 7).
- **Report path:** the audit report file with `✅ fixed` rows.

Never claim a fix landed if there is no commit on the branch. Never claim
verification passed if the post-fix test/lint/typecheck command errored.

## Trust model

- **One commit per finding.** Atomic, revertible. The user can
  cherry-pick or revert any single fix without unwinding the others.
- **Affected-paths-only scope.** Out-of-scope edits are refused; the
  audit is the audit, not a refactor charter.
- **Read-after-write check.** Same-dimension regressions are logged in
  the report — they don't unwind the commit, but they are visible.
- **No bundling.** Two findings with overlapping diffs land as two
  commits, even when the second is a no-op.
- **Behaviour-preservation.** The skill never widens scope from
  structural cleanup to functional change. When the fix can't be done
  without behaviour change, route to `/ai:tdd`.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot
patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" audit-fix start
bash "$AI_KIT_ROOT/bin/log-skill.sh" audit-fix done   # or `abort` if you bail
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
