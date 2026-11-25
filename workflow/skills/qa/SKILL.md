---
name: qa
description: QA a web app at a given URL — smoke test critical paths, report bugs with repro steps, optionally fix and re-verify. Use when validating a running build, after a deploy, or before handing off to stakeholders. Prefers Playwright or browser MCP when available.
---

# QA Pass

Systematically test a web application and report findings.

Browser/console output is large; quote only salient lines back into this context. Filter console logs with patterns instead of dumping all output. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full QA pass to the `qa-runner` subagent via the Task tool with `subagent_type=ai:qa-runner`. Pass: target URL, environment (`local`/`staging`), critical flows, tier (`quick`/`standard`/`exhaustive`, optionally `personas` with its lenses). A caller that wants its worktree tested passes the **Worktree run** inputs instead of a running URL. The subagent drives Playwright / CLI checks so the large browser and console output stays out of this context; it returns the markdown report below. Surface that report to the user, then route fixes through the fix loop below if asked.
- **Browser-MCP interactive QA, or hosts without subagents:** run the process below inline. The process below is the canonical source of truth — `qa-runner`'s system prompt mirrors it.

## Process

1. **Clarify scope** — URL, environment (local/staging), and critical user flows.
2. **Smoke test** — load the app, check console errors, verify primary flows work.
3. **Deep test** — edge cases, form validation, auth boundaries, error states.
4. **Report** each issue with: severity (critical/high/medium/low), steps to reproduce, expected vs actual.
5. **Fix loop** (only if asked) — send each issue to a builder brief (`subagent_type=ai:builder`, in the shape of [`triage/AGENT-BRIEF.md`](../triage/AGENT-BRIEF.md)) with its repro as the first failing test; the lead never fixes. Re-test that path once the builder reports green. A personas finding counts as fixed only with a regression test in the project's own test framework (unit or e2e, not necessarily Playwright).

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

Run every full suite, production build and dependency install through `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-heavy-run.sh" <cmd>`; exit 75 means another run holds the lock: report it and stop. Playwright runs with at most 2 workers.

Money guard, mandatory unless the caller states the flow has no payments or orders. Run on non-prod only. Print the payment key mode and abort on a live key: a key in page source or .env with prefix `pk_live_`/`sk_live_` (Stripe) or `live_` (Mollie). Route-abort the payment-provider hosts and the order-create endpoint. Never submit checkout. Use test-domain e-mail only: `@example.test` or the project's own test domain. No non-prod env: stop and report it as a blocker; the caller asks the user. Never fall back to prod.

Rank findings by severity times flow position, sign-up and checkout first. Never rank by how many lenses hit a finding: the lenses share one model, so their misses correlate. Persona rows add a `Smoke would catch` column (yes/no) to the Findings table in Output.

Evidence: the content site run of 2026-10-18 found 5 findings (2 high); a smoke run caught 0 of the 5.

## Worktree run

Only when the caller passes a worktree path and a start command. Without them the runner tests the given URL and starts nothing.

1. **Port.** A fixed port named by the caller is the only choice; taken means skipped. Otherwise pick a free one. Check with `lsof -nP -iTCP:<port> -sTCP:LISTEN`. Fill it in for `{port}` in the start command and the URL. The URL's host must be local, and there must be a `{port}` or a fixed port; otherwise skipped.
2. **Start.** First take the tree hash, in the worktree root: `{ git status --porcelain -uall; git diff --binary HEAD; git ls-files -oz --exclude-standard | xargs -0 git hash-object; } | git hash-object --stdin`, and keep the status output. Builds, missing dependency installs (lockfile-frozen only) and unfiltered Playwright runs go through `AI_KIT_HEAVY_WAIT=60 bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-heavy-run.sh" <cmd>` with a Bash timeout of 600000 ms; exit 75: retry once, then skipped. Playwright uses at most 2 workers. Then start the server with the Bash tool's `run_in_background`, unwrapped (the wrapper would hold the machine lock): `cd <worktree> && ps -o pid=,pgid= -p $$ ><scratch dir>/qa.pid && <start command>`. PID and PGID must be equal (its own process group); if not, stop that PID and skip.
3. **Verify.** The URL answers, and the process listening on the port is in the recorded process group (`ps -o pgid= -p <pid>`) and has its working directory inside the worktree (`lsof -a -p <pid> -d cwd -Fn`). Not provable (a container, another process took the port) means skipped; never test a server you did not start.
4. **Test.** Do not write or extend tests; scripts, Playwright output, screenshots, traces and reports all go to the scratch dir (`--output`, reporter paths). Load each touched page cold and watch for wrong data, wrong rendering and visible layout shift (`layout-shift` performance entries, or screenshots during load). Run on test or mock data; never submit a real payment or order. A login you have no credentials for is untested; nothing testable left means skipped.
5. **Severity and cause.** The caller's severity override outranks the tier table. Add a `Cause` column to Findings: `slice` (the diff causes it, name the `file:line`) or `older` (it exists without the diff). Cannot tell: `slice`, and say so. Quick tier reports older bugs only when critical or high.
6. **Stop, on every way out, a failed or skipped run included.** Confirm the recorded group is still this run's: `lsof -a -g <pgid> -d cwd -Fpn` lists at least one process with its working directory inside the worktree. Then `kill -- -<pgid>`; this works when its parent already died. Not confirmed: do not kill, report it. Never `pkill`, `killall` or kill by port. Check that the port is free, or report what still listens. Then take the tree hash again: changed means name every changed path in the report and leave it.

Ship readiness is then READY, NOT READY or `SKIPPED - <reason>`; only SKIPPED has no health score.

## Output

```markdown
## Health score: X/10

## Findings
| Severity | Flow | Issue | Repro |
| -------- | ---- | ----- | ----- |

## Ship readiness
READY | NOT READY — reason
```
