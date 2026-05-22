---
name: aikit-review
description: Pre-merge code review on the current branch diff. Checks correctness, security, test coverage, and alignment with CONTEXT.md. Use before landing, opening a PR, or pre-release security checks.
---

# Code Review

Review the diff against the base branch before merge. Inspired by [gstack /aikit-review](https://github.com/garrytan/gstack), stripped of gstack-specific tooling.

Read `CONTEXT.md` and relevant ADRs first; they're cached truth. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full review pass to the `aikit-reviewer` subagent via the Task tool with `subagent_type=aikit-reviewer`. Pass: base branch, target ref (default `HEAD`), mode (`daily` or `comprehensive`), security depth (`default` or `deep`). Return the subagent's markdown report to the user verbatim, then discuss the verdict.
- **Cursor / hosts without subagents:** run the inline checklist below in the main context. The checklist below is the canonical source of truth — `aikit-reviewer`'s system prompt mirrors it.

For wide cross-file impact analysis where you don't need a full verdict, prefer `aikit-explore` (read-only sweep) over inline grepping.

## Process

1. **Scope** — identify changed files (`git diff --name-only` vs base branch).
2. **Understand** — read CONTEXT.md and relevant ADRs if they exist.
3. **Review** for:
   - Correctness and edge cases
   - Security (injection, auth, secrets, unsafe defaults)
   - Test coverage for behaviour changes
   - Naming aligned with CONTEXT.md domain language
   - No drive-by refactors mixed with the stated change
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

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `aikit-retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-review start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-review done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

