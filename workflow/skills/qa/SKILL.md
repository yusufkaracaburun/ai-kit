---
name: qa
description: QA a web app at a given URL — smoke test critical paths, report bugs with repro steps, optionally fix and re-verify. Use when validating a running build, after a deploy, or before handing off to stakeholders. Prefers Playwright or browser MCP when available.
---

# QA Pass

Systematically test a web application and report findings. Inspired by [gstack /ai:qa](https://github.com/garrytan/gstack) — stripped of gstack-specific tooling.

Browser/console output is large; quote only salient lines back into this context. Filter console logs with patterns instead of dumping all output. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full QA pass to the `qa-runner` subagent via the Task tool with `subagent_type=qa-runner`. Pass: target URL, environment (`local`/`staging`), critical flows, tier (`quick`/`standard`/`exhaustive`). The subagent drives Playwright / CLI checks so the large browser and console output stays out of this context; it returns the markdown report below. Surface that report to the user, then run the fix loop here if asked.
- **Browser-MCP interactive QA, or hosts without subagents:** run the process below inline. The process below is the canonical source of truth — `qa-runner`'s system prompt mirrors it.

## Process

1. **Clarify scope** — URL, environment (local/staging), and critical user flows.
2. **Smoke test** — load the app, check console errors, verify primary flows work.
3. **Deep test** — edge cases, form validation, auth boundaries, error states.
4. **Report** each issue with: severity (critical/high/medium/low), steps to reproduce, expected vs actual.
5. **Fix loop** (only if asked) — fix one issue, commit, re-test that path.

Use Playwright E2E tests in the project when they exist. Prefer extending tests over one-off manual checks for regressions.

## Tiers

| Tier | Scope |
| ---- | ----- |
| Quick | Critical + high only |
| Standard | + medium |
| Exhaustive | + cosmetic / polish |

## Output

```markdown
## Health score: X/10

## Findings
| Severity | Flow | Issue | Repro |
| -------- | ---- | ----- | ----- |

## Ship readiness
READY | NOT READY — reason
```

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" qa start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" qa done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
