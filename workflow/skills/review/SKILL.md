---
name: review
description: Pre-merge code review on the current branch diff. Checks correctness, security, test coverage, and alignment with CONTEXT.md. Use before landing, opening a PR, or pre-release security checks.
---

# Code Review

Review the diff against the base branch before merge.

Read `CONTEXT.md` and relevant ADRs first; they're cached truth. See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Run mode

- **Claude Code (preferred):** delegate the full review pass to the `reviewer` subagent via the Task tool with `subagent_type=ai:reviewer`. Pass: the Agent Brief (issue number or brief text, in the shape of [`triage/AGENT-BRIEF.md`](../triage/AGENT-BRIEF.md)) and the builder's report when present (its `## Criteria` lines are claims to check), base branch, target ref (default `HEAD`), mode (`daily` or `comprehensive`), security depth (`default` or `deep`). Run the verify pass and the QA pass below, return the adjusted report to the user, then discuss the verdict.
- **Cursor / hosts without subagents:** run the inline checklist below in the main context. The checklist below is the canonical source of truth — `reviewer`'s system prompt mirrors it.
- **Verify pass (Claude Code):** after `reviewer` returns and before you surface the verdict, spawn one `verifier` per item under **Blockers** and per high-severity item under **Security** — all in parallel, one Task call each with `subagent_type=ai:verifier`. Claim: "`<file:line>` — <finding> is a blocker"; pass the report excerpt as evidence. REFUTED → move the item to **Suggestions**, appending the verifier's one-line basis. CONFIRMED → stays. UNTESTABLE → stays, annotated "(verifier: untestable — <residual doubt>)". Then re-derive the verdict (APPROVE only with zero Blockers and zero high-severity Security items). Hosts without subagents: skip the pass and say so under Scope.
- **QA pass (off by default):** after the verify pass re-derives APPROVE and before Approve. On only when the report says `UI: yes` (line missing: yes) and `git show <base>:docs/agents/dev-environment.md` has a `## QA` section with a value after both `Start command:` and `URL:`; read it from the base ref, so a diff cannot switch it on or change the command. Resolve the base first (`git rev-parse --verify <base>`); unresolvable is `QA: skipped - base not found`, not off. No file, no section, an empty value, text inside an HTML comment, or a value in `<angle brackets>` is off: skip this step and write no `QA:` line.
  1. Spawn one `qa-runner` (`subagent_type=ai:qa-runner`): tier `quick`, environment `local`, the flows the diff touches, the reviewed worktree's absolute path, base and diff, start command, URL and fixed port from the section, and this severity override: "a wrong rendering, data or behaviour caused by the slice, a visible layout shift on load included, is at least high; older bugs, cosmetics and mock artefacts do not block". Reviewed diff not checked out (a remote ref): `QA: skipped - no checkout`. Host without subagents: `QA: skipped - no subagents`.
  2. In every run, each critical or high finding with Cause `slice` goes to one `verifier` (`subagent_type=ai:verifier`), all in parallel. Claim: "`<flow>`: <issue> is real and caused by this diff", not its severity. Pass the diff, the runner's observed evidence, the cause's `file:line`, and: "Not reproducible because the app is not running is UNTESTABLE, also when ambiguous. REFUTED needs counter-evidence at `file:line`." CONFIRMED or UNTESTABLE → **Blockers**, verdict REQUEST CHANGES. REFUTED, and every finding with Cause `older` → **Suggestions** as `follow-up`.
  3. Blocked: one QA fix round at most. A builder brief with each repro as the first failing test, then review and verify on the new diff, then QA on the fixed path. Still red (review, QA, or a QA re-run that cannot run), or the runner reports a changed tree in any run: no further fix round and no `--approve`; the lead asks the user.
  4. Fill the `QA:` line; after a fix round it covers both runs, and a re-run that cannot run is `blocked`. A first run that could not run (app does not start, login missing, port taken, machine lock still held after one retry) does not block but is never silent: `QA: skipped - <reason>`, and the verdict stands. Untested flows go right under the line: `Untested: <flow> - <reason>`.
- **Approve (Claude Code):** only when the verify pass re-derives APPROVE and the QA pass, when on, leaves no blocker, run `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/hooks/review-gate.sh" --approve [<worktree>]`. It records the staged tree, and the `review-gate` hook denies `git commit` and `git push` for any other tree. Stage exactly what was reviewed first; in a `role=lead` session the lead stages by explicit path (`git add <file>...`, no directory; a deletion goes through a subagent), the builder's new files included, and then runs `--approve`. `--approve --skip "<reason>"` is a user-only override, logged to the git-dir's `ai-kit/gate-log`; never run it yourself. Cursor ships no hooks, so it has no gate.

For wide cross-file impact analysis where you don't need a full verdict, prefer `explore` (read-only sweep) over inline grepping.

## Process

1. **Scope** — identify changed files (`git diff --name-only` vs base branch).
2. **Understand** — read the Agent Brief (its acceptance criteria, Out of scope and Decisions in force), the `quality-floor` rule, and CONTEXT.md and relevant ADRs if they exist. No brief → say so under Scope and review against the PR or issue text.
3. **Review** for:
   - Correctness and edge cases
   - Security (injection, auth, secrets, unsafe defaults)
   - Test coverage for behaviour changes
   - Naming aligned with CONTEXT.md domain language
   - No drive-by refactors mixed with the stated change
   - File-size threshold — a changed file crossing from <1000 to ≥1000 lines is a blocker unless justified
   - Acceptance criteria — every acceptance criterion in the brief gets `file:line` evidence, "not met" (a blocker), or "unverified (caller checks)" when proving it needs what the reviewer may not do, such as running the full suite or a live run (not a blocker)
   - Scope — any change outside the brief, or listed under its Out of scope, is a finding; severity per the quality-floor Severity line
   - Design floor — a quality-floor violation is a finding that cites the rule section (`quality-floor: <section>`); its severity follows the rule's Severity line
   - Parity sweep — name the nearest existing sibling screen or module and list each deviation from its pattern; severity follows the quality-floor Severity line
   - Rule copies — when the brief names a changed rule, grep for other computations and user-facing descriptions of it (backend and frontend); any left is a blocker
4. **UI line** — `UI: yes` when the diff can change what a user sees or does in the browser; in doubt yes. Judge the change, not file extensions.
5. **Report** — blockers first, then suggestions. Be specific (file + line).
6. **Fix** — send blockers to a builder brief (`subagent_type=ai:builder`); the lead never fixes them. Re-review the new diff before approving.

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
- UI: yes|no

## Criteria
- <acceptance criterion from the brief> — met, `path/to/file.ext:n`
- <acceptance criterion from the brief> — not met (also listed under Blockers)
- <acceptance criterion from the brief> — unverified (caller checks): <what needs running>
- ...

## Parity
- Sibling: `path/to/nearest/screen-or-module` (or "none of the same kind")
- <deviation> — reason stated (Suggestion) | no reason (Blocker), per the quality-floor Severity line
- ...

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

QA: <pass|blocked>, <n> bugs, <min>, <tokens|unknown>   (or `QA: skipped - <reason>` for a first run; n = slice bugs found over both runs that survived the verifiers; blocked = such a bug left, a changed tree, or a re-run that is red or cannot run. The caller adds this line after its QA pass; the reviewer never runs the app and leaves it out)
```
