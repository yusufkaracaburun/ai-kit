---
name: qa
description: QA a web app at a given URL — smoke test critical paths, report bugs with repro steps. Optionally fix and re-verify. Use Playwright or browser MCP when available.
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
