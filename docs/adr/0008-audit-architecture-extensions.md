# ADR-0008: Per-stack extensions for `/ai:audit-architecture`

## Status

Accepted (Unreleased)

## Context

EPIC [#35](https://github.com/yusufkaracaburun/ai-kit/issues/35) tracked per-stack tuning for the stack-agnostic `/ai:audit-architecture` skill: every audit dimension is universal, but the *shape* of a finding depends on the stack — Eloquent N+1 in Laravel, RSC boundary leaks in React, `any`-past-boundary in TypeScript. A flat global skill could not encode these without bloating into a stack-detection ladder.

A 2026-05-26 grilling session crystallised twelve design decisions. The foundational layer landed in [#79](https://github.com/yusufkaracaburun/ai-kit/issues/79) (contract spec + extension-loader + shared overlap fixture + 4 contract tests). v1 stack-extensions land in [#80](https://github.com/yusufkaracaburun/ai-kit/issues/80) (Laravel), [#81](https://github.com/yusufkaracaburun/ai-kit/issues/81) (React), [#82](https://github.com/yusufkaracaburun/ai-kit/issues/82) (TypeScript). [#83](https://github.com/yusufkaracaburun/ai-kit/issues/83) (Flutter) is deferred pending a real Flutter project.

## Decision

**Per-stack tuning ships as a fixed-shape extension triplet (skill + rule + helper-script) bundled in ai-kit and auto-loaded by the core skill on framework/language match.** Twelve design choices fix the architecture:

### 1. Extension form — skill + rule + helper-script triplet

Every extension ships three artifacts:

- `workflow/skills/audit-architecture-<stack>/SKILL.md` — the per-stack walk + merge contract
- `standards/rules/code-audit-<stack>.mini.md` — heuristics encoded by canonical dimension
- `bin/audit-<stack>-helpers.sh` — optional tool-gating + mode-detection

The triplet keeps responsibilities separate (skill = process, rule = catalogue, helper = deterministic side-effects). Single-file extensions were rejected because tool gating and fixture-shape verification do not belong in markdown.

### 2. Hosting — bundled in ai-kit, PR-gated contributions

Extensions live in the ai-kit repo proper, not in a sibling marketplace. A `standards/promotion-quorum.md`-style review gates additions. Off-repo extensions were rejected: the contract spec is too young to support external versioning.

### 3. Declaration — hybrid (convention + frontmatter + applies_to)

An extension is declared by:

- Folder convention: `workflow/skills/audit-architecture-<stack>/SKILL.md`.
- Frontmatter: `extends: audit-architecture` (literal; loader rejects mismatch).
- Reuse of existing `applies_to.frameworks` / `applies_to.languages` for matching.

This piggy-backs on the rule-emitter's already-mature `applies_to` schema and avoids a parallel declaration language. The folder convention doubles as a sanity check against frontmatter drift.

### 4. Auto-load — silent default + opt-out env var

The core skill calls `bin/audit-extension-loader.sh` and invokes each matched extension via the Skill tool. No user prompt, no marketplace install. `AI_KIT_AUDIT_NO_EXTEND=1` returns vanilla baseline (pre/post-extension comparison; known-broken extension workaround).

### 5. v1 scope — Laravel + React + TypeScript (Flutter deferred)

The 2026-05-26 PRD targeted four stacks (Laravel, React, TypeScript, Flutter). Flutter (#83) is deferred until a real Flutter project surfaces — without one, fixture shape would be guesswork. Go and Rails extensions are intentionally out of scope until v2.

### 6. Release shape — big-bang, contract-test mitigates risk

The three v1 extensions land together (vs. one-extension-per-release). The shared overlap fixture and the `audit-extension-contract.sh` case mitigate the risk of releasing 3 extensions in one go: ownership-boundary drift would surface on first run, not after a slow drip of partial coverage.

### 7. React + TypeScript overlap — fire-both-de-duped + ownership table

Both extensions load when a project has React + TS. Non-overlap is enforced at the **fixture-marker level**: `tests/fixtures/audit-react-ts-overlap/src/Dashboard.tsx` holds R\* markers only; `src/api.ts` holds T\* markers only. The actual audit (LLM-driven) inherits the contract by reading the rules; the contract-test asserts the discipline at fixture shape.

Each extension's SKILL.md owns the ownership claim in prose:

- React owns framework+TS-specific concerns (R7 typed `<form action={…}>`, RSC boundary, props-bloat, prop-typing on components).
- TypeScript owns language-level smells (any-leak, as-cast-past-edge, exhaustive-switch, decorator/runtime, duplicated-type-alias, unused-type-export, readonly drift).

### 8. Contract — markdown dimension-keyed, flat merge with `[<stack>]` prefix

Extensions return one or two markdown blocks (`## Per-stack findings — <stack>` + optional `## Per-stack appendix — <stack>`). The core skill stitches dimension-keyed findings into the final report's existing per-dimension sections, prefixing each merged row with `[<stack>]` for grep-ability. No new dimensions, no JSON contract — markdown stays the reader-facing surface.

### 9. Tools — optional ingestion, gracefully degrade

Helper-scripts wrap external linters/static-analysers (Larastan, PHPStan, ESLint, `tsc`, `ts-prune`). Each invocation is gated by `command -v` or `./node_modules/.bin/<tool>`. Tool absence is **never fatal**; the audit completes without the tool's signal and the report header surfaces `<tool> ✗` so the reader knows what is and isn't ingested. Format tools (Prettier, Pint, dart format) and security scanners (Snyk, npm/composer audit) are out of scope.

### 10. Laravel — strict-always-on (severity floor 🟡, API findings 🟠)

The Laravel extension declares `strictness: strict` in its frontmatter. Findings cannot drop below 🟡, and API-tier heuristics (L13-L18) floor at 🟠. The reasoning: backend correctness has tighter blast-radius than front-end ergonomics; a Laravel 🟢 finding usually means re-triage failure, not actual low-severity. Strict mode also forbids 🟢 outright. Surfaced in report header as `**Extensions loaded:** audit-architecture-laravel (strict, floor=🟡, api=🟠)`.

### 11. Target — latest stable only

Each extension targets the latest stable release of its stack at landing time (Laravel 13, React 19, TypeScript 5.7, Flutter 3.27). Older-version support is opt-in via per-heuristic notes; the default audit assumes upgrade-cadence-current projects. Rationale: an audit's job is to surface drift; encoding pre-stable idioms by default would surface false drift.

### 12. Mode-detect protocol — Laravel api-only vs full-stack

Some stacks have orthogonal modes that change which heuristics apply. Laravel's `api-only` vs `full-stack` is the v1 case: 3 of the 22 Laravel heuristics (L14, L16, L18) fire only in `api-only` mode. Detection lives in `bin/audit-laravel-helpers.sh::detect_mode`; result surfaces in the report header as `**Laravel mode:** <mode>`. Override env: `AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack`. Future modes follow `AI_KIT_AUDIT_<STACK>_MODE=<mode>` convention.

## Consequences

**Positive:**

- The core skill stays stack-agnostic — adding a new stack means adding a triplet, not editing the core.
- The contract spec (`standards/contracts/audit-architecture-extension.contract.md`) is the single source of truth for downstream extensions; future contributions don't need to re-derive shape.
- Fixture-level ownership-boundary discipline catches drift at test time, not at LLM-output time.
- Tool absence never blocks an audit; the report header is honest about what was and wasn't ingested.

**Negative / trade-offs:**

- Adding a stack requires writing five artifacts (SKILL + rule + helper + fixture(s) + test case). A skill author can't ship a 100-LOC PR.
- LLM-driven audit output cannot be deterministically asserted in shell tests; the contract-test asserts artifact shape + fixture-marker discipline, not actual finding rows.
- Per-stack extensions encode their own anti-patterns ("don't flag X if the ADR says Y"); ADRs in the audited project must be readable by the extension's walk or false-positives accumulate.
- The big-bang release shape (decision #6) front-loads risk; if the contract evolves in v2, three extensions need migration in lockstep.

## Alternatives considered

1. **Flat skill with stack-detection ladder** — rejected: would bloat the core skill linearly with stack-count.
2. **Per-stack PRD documents instead of bundled extensions** — rejected: knowledge would rot in PRDs; the rule file IS the cache.
3. **Off-repo extensions via a marketplace** — rejected at v1: contract spec too young; bundle now, decouple later if needed.
4. **JSON contract between core and extensions** — rejected: markdown is already the reader-facing surface; adding a parallel JSON channel doubles maintenance.
5. **Per-extension severity-floor escape hatches in `applies_to`** — rejected: severity-floor is a per-extension concern, not a global one; the rule file owns its own floor logic.
6. **Auto-recommend extension install during `/ai:setup`** — rejected: extensions are pure-bundle, no install step; if the stack is detected, the extension just fires.

## References

- EPIC: [#35](https://github.com/yusufkaracaburun/ai-kit/issues/35) — Per-stack tuning extensions PRD.
- Foundational: [#79](https://github.com/yusufkaracaburun/ai-kit/issues/79) — extension-loader + contract spec + shared overlap fixture.
- Implementing: [#80](https://github.com/yusufkaracaburun/ai-kit/issues/80) (Laravel), [#81](https://github.com/yusufkaracaburun/ai-kit/issues/81) (React), [#82](https://github.com/yusufkaracaburun/ai-kit/issues/82) (TypeScript).
- Deferred: [#83](https://github.com/yusufkaracaburun/ai-kit/issues/83) (Flutter).
- Docs: [#84](https://github.com/yusufkaracaburun/ai-kit/issues/84) — this ADR + CHANGELOG entry.
- Contract spec: `standards/contracts/audit-architecture-extension.contract.md`.
- Loader: `bin/audit-extension-loader.sh`.
- Core skill: `workflow/skills/audit-architecture/SKILL.md`.
