---
name: qa
description: QA a web app at a given URL — smoke test critical paths, report bugs with repro steps, optionally fix and re-verify. Use when validating a running build, after a deploy, or before handing off to stakeholders. Prefers Playwright or browser MCP when available.
---

# QA Pass

Systematically test a web application and report findings. Inspired by [gstack /ai:qa](https://github.com/garrytan/gstack) — stripped of gstack-specific tooling.

Browser/console output is large; quote only salient lines back into this context. Filter console logs with patterns instead of dumping all output. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full QA pass to the `qa-runner` subagent via the Task tool with `subagent_type=ai:qa-runner`. Pass: target URL, environment (`local`/`staging`), critical flows, tier (`quick`/`standard`/`exhaustive`, optionally `personas` with its lenses). The subagent drives Playwright / CLI checks so the large browser and console output stays out of this context; it returns the markdown report below. Surface that report to the user, then run the fix loop here if asked.
- **Browser-MCP interactive QA, or hosts without subagents:** run the process below inline. The process below is the canonical source of truth — `qa-runner`'s system prompt mirrors it.

## Process

1. **Clarify scope** — URL, environment (local/staging), and critical user flows.
2. **Smoke test** — load the app, check console errors, verify primary flows work.
3. **Deep test** — edge cases, form validation, auth boundaries, error states.
4. **Report** each issue with: severity (critical/high/medium/low), steps to reproduce, expected vs actual.
5. **Fix loop** (only if asked) — fix one issue, commit, re-test that path. A personas finding counts as fixed only with a regression test in the project's own test framework (unit or e2e, not necessarily Playwright).

Use Playwright E2E tests in the project when they exist. Prefer extending tests over one-off manual checks for regressions.

## Tiers

| Tier | Scope |
| ---- | ----- |
| Quick | Critical + high only |
| Standard | + medium |
| Exhaustive | + cosmetic / polish |
| Personas (opt-in) | + the persona lenses below, on top of any tier |

## Personas

Opt-in only. The caller picks the lenses per run; default is all 5. They run one after another in ONE runner, never in parallel browsers.

- **impatient:** skims, clicks the first button, quits at the first error.
- **skeptic:** reads pricing, terms and privacy before signing up.
- **mobile:** 375px viewport plus slow-3G via Playwright CDP throttling.
- **literal reader:** a second-language speaker of the UI's own language, who follows only the literal UI text.
- **breaker:** junk input, back mid-flow, double-clicks.

Before the first lens, run the heavy-run check `ps -Ao args | grep -E 'pest|paratest|phpunit|playwright|patrol|maestro|xcodebuild|gradle' | grep -v grep`. A hit from another repo means wait; still there after one recheck, report it and stop. Playwright runs with at most 2 workers.

Money guard, mandatory unless the caller states the flow has no payments or orders. Run on non-prod only. Print the payment key mode and abort on a live key: a key in page source or .env with prefix `pk_live_`/`sk_live_` (Stripe) or `live_` (Mollie). Route-abort the payment-provider hosts and the order-create endpoint. Never submit checkout. Use test-domain e-mail only: `@example.test` or the project's own test domain. No non-prod env: stop and report it as a blocker; the caller asks the user. Never fall back to prod.

Rank findings by severity times flow position, sign-up and checkout first. Never rank by how many lenses hit a finding: the lenses share one model, so their misses correlate. Persona rows add a `Smoke would catch` column (yes/no) to the Findings table in Output.

Evidence: the theorieplek run of 2026-10-18 found 5 findings (2 high); a smoke run caught 0 of the 5.

## Output

```markdown
## Health score: X/10

## Findings
| Severity | Flow | Issue | Repro |
| -------- | ---- | ----- | ----- |

## Ship readiness
READY | NOT READY — reason
```
