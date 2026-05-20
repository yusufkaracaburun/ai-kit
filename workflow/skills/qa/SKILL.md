---
name: qa
description: QA a web app at a given URL — smoke test critical paths, report bugs with repro steps, optionally fix and re-verify. Use when validating a running build, after a deploy, or before handing off to stakeholders. Prefers Playwright or browser MCP when available.
---

# QA Pass

Systematically test a web application and report findings.

## Process

1. **Clarify scope** — URL, environment (local/staging), and critical user flows.
2. **Smoke test** — load the app, check console errors, verify primary flows work.
3. **Deep test** — edge cases, form validation, auth boundaries, error states.
4. **Report** each issue with: severity (critical/high/medium/low), steps to reproduce, expected vs actual.
5. **Fix loop** (only if asked) — fix one issue, commit, re-test that path.

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

Use Playwright E2E tests in the project when they exist. Prefer extending tests over one-off manual checks for regressions.

Inspired by [gstack /qa](https://github.com/garrytan/gstack) — stripped of gstack-specific tooling.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" qa start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" qa done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

