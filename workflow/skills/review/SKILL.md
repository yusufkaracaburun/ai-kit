---
name: review
description: Pre-merge code review on the current branch diff. Checks correctness, security, test coverage, and alignment with CONTEXT.md. Use before landing, opening a PR, or pre-release security checks.
---

# Code Review

Review the diff against the base branch before merge. Inspired by [gstack /ai:review](https://github.com/garrytan/gstack), stripped of gstack-specific tooling.

Read `CONTEXT.md` and relevant ADRs first; they're cached truth. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full review pass to the `reviewer` subagent via the Task tool with `subagent_type=reviewer`. Pass: base branch, target ref (default `HEAD`), mode (`daily` or `comprehensive`), security depth (`default` or `deep`). Run the verify pass below, return the adjusted report to the user, then discuss the verdict.
- **Cursor / hosts without subagents:** run the inline checklist below in the main context. The checklist below is the canonical source of truth — `reviewer`'s system prompt mirrors it.
- **Verify pass (Claude Code):** after `reviewer` returns and before you surface the verdict, spawn one `verifier` per item under **Blockers** and per high-severity item under **Security** — all in parallel, one Task call each with `subagent_type=verifier`. Claim: "`<file:line>` — <finding> is a blocker"; pass the report excerpt as evidence. REFUTED → move the item to **Suggestions**, appending the verifier's one-line basis. CONFIRMED → stays. UNTESTABLE → stays, annotated "(verifier: untestable — <residual doubt>)". Then re-derive the verdict (APPROVE only with zero Blockers and zero high-severity Security items). Hosts without subagents: skip the pass and say so under Scope.

For wide cross-file impact analysis where you don't need a full verdict, prefer `explore` (read-only sweep) over inline grepping.

## Process

1. **Scope** — identify changed files (`git diff --name-only` vs base branch).
2. **Understand** — read CONTEXT.md and relevant ADRs if they exist.
3. **Review** for:
   - Correctness and edge cases
   - Security (injection, auth, secrets, unsafe defaults)
   - Test coverage for behaviour changes
   - Naming aligned with CONTEXT.md domain language
   - No drive-by refactors mixed with the stated change
   - File-size threshold — a changed file crossing from <1000 to ≥1000 lines is a blocker unless justified
4. **Report** — blockers first, then suggestions. Be specific (file + line).
5. **Fix** — only fix blockers if the user asks; otherwise list them.

## Security deep pass

Run when the user asks for a security audit, before production deploys, or for periodic reviews.

| Mode | When | Bar |
| ---- | ---- | --- |
| Daily | Pre-merge on changed files | Report only high-confidence issues |
| Comprehensive | Monthly or pre-release | Full repo scan |

Checklist:

1. **Secrets** — scan for API keys, tokens, passwords in code and recent git history.
2. **Dependencies** — run dependency audit via lockfile (`pnpm audit`, `npm audit`, `yarn npm audit`, `composer audit`) — see `docs/agents/dev-environment.md`; flag critical/high CVEs.
3. **Auth & access** — verify auth boundaries on changed endpoints; no privilege escalation paths.
4. **Input validation** — injection (SQL, XSS, command), path traversal on new inputs.
5. **OWASP Top 10** — focus on items relevant to the change set.
6. **STRIDE sketch** — for new external surfaces: spoofing, tampering, repudiation, info disclosure, DoS, elevation.

Add security findings under **Blockers** or a separate **Security** section with severity.

## Output format

```markdown
## Scope
- Base: <branch>
- Target: <ref>
- Mode: <daily|comprehensive>
- Files: <count>
- Security depth: <default|deep>

## Blockers
- `path/to/file.ext:42` — <one-line description>
- ...

## Security
- `path/to/file.ext:n` — **<severity>** <one-line description>
- (deep mode: `package@version` — **<severity>** CVE-XXXX-NNNNN)
- ...

## Suggestions
- `path/to/file.ext:n` — <one-line description>
- ...

## Verdict
APPROVE | REQUEST CHANGES
```
