---
name: audit-architecture
description: Whole-codebase architecture-quality audit — 9 dimensions (design patterns, SOLID, DRY, YAGNI, naming+comment-drift, coupling, layering, error-handling, type-safety). Stack-agnostic. Writes a severity-tagged markdown report; no code changes. Use when user asks "audit the codebase", "review for SOLID/DRY/YAGNI", "find tech-debt", "scan for design-pattern violations", or "code-quality review of the whole repo".
---

# Audit Architecture

Whole-codebase audit against 9 dimensions of architecture-quality. Output: a severity-tagged markdown report. **Read-only.** Fixing is a separate step.

Not to be confused with:
- `/ai:review` — pre-merge **diff** review against the base branch.
- `/ai:improve-codebase-architecture` — deepening opportunities (shallow→deep refactors).
- `/ai:diagnose` — runtime / failure-mode investigation.

This skill is the **audit**, not the **fix**. Same discipline as a security audit: surface, triage, hand off.

## When to invoke

- "Audit the codebase / review the whole repo / scan for tech-debt"
- "Find SOLID / DRY / YAGNI violations"
- "Where are the smells / god classes / coupling hotspots"
- Periodic architecture review (quarterly, pre-major-release, post-acquisition due-diligence)
- After a long feature push, before opening up to new contributors

## Dimensions

The canonical 9 dimensions live in [`standards/rules/code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). Read it first — every finding in this audit must trace to exactly one dimension defined there:

1. Design patterns
2. SOLID
3. DRY (knowledge-duplication)
4. YAGNI / dead-code
5. Naming + comment-drift
6. Coupling / cohesion (local / structural)
7. Layering / dependency-direction (global / architectural)
8. Error handling / failure modes
9. Type safety / contract clarity

If a concern doesn't fit one of those, it's out of audit scope — note it separately. Security, performance, and runtime concerns are explicitly out-of-scope; cross-ref `/ai:review` security-deep-pass or a separate audit discipline.

## Run mode

- **Claude Code (preferred):** delegate the codebase walk to the `explore` subagent via the Task tool with `subagent_type=explore`. Ask for one structured pass per dimension (or one batched pass with the dimension list inline) and have it return a ≤300-line summary per pass. Writing the report stays in this context.
- **Cursor / hosts without subagents:** walk inline, but budget tightly — see [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md). For large repos (>200 files), pick a scope first (one bounded context, one layer, one module) and audit it; iterate.

## Process

### 1. Scope

Decide the audit boundary before walking. One of:

- **Whole repo** (small/medium codebases, <200 files)
- **One context / module / package** (large repos — name it explicitly)
- **One layer** (e.g. "backend only", "domain layer only")

State the scope in the report header. An unscoped audit drifts into pedantry.

### 2. Read the cached truth

Read in order:

1. `CONTEXT.md` (domain language)
2. `docs/agents/architecture.md` if present (declared structure)
3. ADRs in `docs/adr/` touching the scope (don't re-litigate landed decisions)
4. `standards/rules/code-audit.mini.md` (the dimensions catalog)

See [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

### 3. Detect stack + load per-stack extensions

Run `bash "$AI_KIT_ROOT/bin/detect-tooling.sh" <project-path> --json` to capture frameworks/languages. Use the result to:

- Skip dimensions that don't apply (e.g. "design patterns" on a 200-LOC shell-script repo).
- Decide whether per-stack extensions should fire.

Then run `bash "$AI_KIT_ROOT/bin/audit-extension-loader.sh" <project-path>` to discover bundled per-stack extensions (`audit-architecture-laravel`, `audit-architecture-react`, `audit-architecture-nextjs`, `audit-architecture-typescript`, `audit-architecture-flutter`, …). The loader returns the SKILL.md paths of every matching extension in stable filename-sorted order. Honours `AI_KIT_AUDIT_NO_EXTEND=1` as an opt-out (returns empty → vanilla baseline audit). See [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) for the contract every extension must satisfy.

### 4. Walk per dimension (+ invoke each matched extension via the Skill tool)

For each of the 9 dimensions in `code-audit.mini.md`, surface concrete findings with `path:line` evidence. Skip a dimension only when it's genuinely out-of-scope for this codebase — say so explicitly in the report ("covered, no findings" or "skipped: <reason>").

For each matched extension from step 3, invoke it via the Skill tool with structured input (audit scope + detected framework versions). The extension returns markdown blocks dimension-keyed per the contract spec (`## Per-stack findings — <stack>` + optional `## Per-stack appendix — <stack>`). Hold the extension output until step 6 (Write the report) — do not interleave with the core walk.

De-duplicate by **root-cause**, not by **symptom**. One god-module appearing in 12 hotspots is one finding with 12 affected paths, not 12 findings.

### 5. Triage

Tag every finding with one of: 🔴 Blocker · 🟠 High · 🟡 Medium · 🟢 Low.

Sanity-check the distribution before writing:
- <10% 🔴/🟠 → probably pedantry, re-triage up.
- >40% 🔴 → probably catastrophising, re-triage down.

### 6. Write the report

Path: `docs/reviews/<YYYY-MM-DD>-<scope>-architecture-audit.md`. Create `docs/reviews/` lazily if it doesn't exist.

Structure:

```markdown
# Architecture audit — <scope> — <YYYY-MM-DD>

**Scope:** <whole-repo | context-name | layer>
**Stack:** <detected frameworks>
**Extensions loaded:** <comma-separated extension names, e.g. "audit-architecture-laravel (strict, floor=🟡)" — or "none">
**Tools ingested:** <per-extension tool status, e.g. "Larastan ✓ · composer outdated ✗" — or "none">
**Files walked:** <N>  ·  **LOC:** <N>  ·  **Audit duration:** <minutes>
**Auditor:** /ai:audit-architecture (ai-kit vX.Y.Z)

## Summary

- 🔴 N · 🟠 N · 🟡 N · 🟢 N findings across <K> dimensions
- Top 3 themes: <one line each>

## 1. Design patterns
<findings or "covered, no findings">

## 2. SOLID
...

(repeat per dimension)

## Tech-debt rolling table

| ID | Finding | Severity | Fix direction | Suggested owner |
|----|---------|----------|---------------|-----------------|
| A1 | ... | 🟠 | ... | ... |
```

**Merging extension output into the dimension sections:** each extension returns its own dimension-keyed markdown. For every `### Dimension N · <name>` block in an extension's output, append its findings under the matching `## N. <name>` section in the final report. Each merged finding row gets a `[<stack>]` tag prefix so the reader (and `grep`) can attribute the row to its source extension. Extension `## Per-stack appendix` blocks are appended after the per-dimension report, before the tech-debt rolling table. Stack tags also propagate into the rolling-table IDs (`L1`, `R3`, `T7`, …) for per-stack batch issue-filing.

The tech-debt table at the bottom is copy-paste-ready for batch issue-filing — same pattern as the naschool 2026-05-23 session and the `audit-fix` follow-up workflow.

### Env-var escape hatches

- `AI_KIT_AUDIT_NO_EXTEND=1` — skip extension loading entirely; run vanilla baseline audit (pre/post-extension comparison, or when an extension is known-broken).
- Extension-specific overrides follow the convention `AI_KIT_AUDIT_<STACK>_<KEY>=<value>` (e.g. `AI_KIT_AUDIT_LARAVEL_MODE=api-only`) — defined by each extension, not by the core.

### 7. Hand off

After writing the report, **stop**. Don't fix. Tell the user:

- The report path.
- The severity counts.
- The top 3 themes.
- Offer the next step: "Want me to file the 🔴/🟠 rows as GH issues?" (use `/ai:to-issues`) or "Want to drop into a fix session for one finding?" (separate skill / explicit follow-up).

## Anti-patterns

- **Writing code during the audit.** Audit and fix have different review-thresholds; mixing them costs trust.
- **Padding the report.** Skip dimensions cleanly — "covered, no findings" is a valid section.
- **Pre-existing-pattern envy.** Flagging "should use Repository pattern" in a codebase that has explicitly chosen plain ORM access (check ADRs first).
- **Replicating diff-review.** If the user wants a diff review, use `/ai:review`. This skill is for code that already landed.
- **Auditing the wrong scope.** A 200-file repo + "audit everything" + 30-minute session = pedantry. Pick a context first.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" audit-architecture start
bash "$AI_KIT_ROOT/bin/log-skill.sh" audit-architecture done
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

## Related

- [`standards/rules/code-audit.mini.md`](../../../standards/rules/code-audit.mini.md) — canonical 8-dimension catalog.
- [`improve-codebase-architecture`](../improve-codebase-architecture/SKILL.md) — deepening / refactor candidates (different scope).
- [`review`](../review/SKILL.md) — pre-merge diff review (different scope).
- [`diagnose`](../diagnose/SKILL.md) — runtime / failure-mode investigation.
- [`to-issues`](../to-issues/SKILL.md) — turn the tech-debt rolling table into GH issues.
