---
name: code-audit-typescript
description: TypeScript-specific audit heuristics — 8 framework-agnostic, language-level checks across the 9 canonical audit dimensions. Loaded whenever a tsconfig.json is present; fires alongside React/Vue/Next/etc. extensions.
applies_to:
  frameworks: []
  languages: ["typescript"]
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY TypeScript audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when the project contains a `tsconfig.json`. Framework-agnostic — fires alongside React/Vue/Next.js extensions when those are also loaded. Never introduces a new dimension.

Out of scope: pre-merge diff review (`/ai:review`), security scanning (npm audit / Snyk), runtime / performance profiling, framework+TS-specific concerns (owned by the framework extension — e.g. React's R7 typed `<form action={…}>`).

## Strictness

Default — per-finding severity, no floor. Surfaced in report header: `**Extensions loaded:** audit-architecture-typescript`. The helper-script's `tsc --noEmit --strict` invocation is **force-strict** regardless of the project's actual `tsconfig.json` strictness setting (audit-time signal-finder, not a project-policy enforcer).

## Ownership boundary

This rule owns **language-level** smells only. When a smell straddles framework+TS territory (e.g. React's `<form action>` typing, Vue's `defineProps<T>()`), the framework extension owns it.

Shared fixture `tests/fixtures/audit-react-ts-overlap/` is the contract-test boundary — each finding row appears exactly once across `[react]` and `[typescript]` prefixes. Audit yourself: every T-rule below must be triggerable in a framework-less file.

## The 8 heuristics

### Dimension 1 · Design patterns

**T6 — Decorator + runtime mismatch (🟠)**
A `@Decorator` is applied to the wrong target (`@Injectable` on a non-class, `@Component` on a function, parameter decorator on a return type), or the runtime expects `emitDecoratorMetadata: true` but `tsconfig.json` doesn't set it. Evidence: walk decorator annotations + `tsconfig.json` compilerOptions.

### Dimension 3 · DRY (knowledge-duplication)

**T7 — Duplicated type alias > 2x (🟡)**
The same type literal is declared in ≥3 files (modulo type-parameter renaming). Should be extracted to a shared `types.ts` / domain module. Evidence: AST-hash of type-alias bodies across the codebase.

### Dimension 4 · YAGNI / dead-code

**T8 — Unused type export (🟡)**
An exported `type` / `interface` / `enum` has no consumer outside its defining module. Surfaces from `ts-prune --json`. Evidence: `ts-prune` output + cross-check against barrel-files.

### Dimension 9 · Type safety / contract clarity

**T1 — `any` past module boundary (🟠)**
An exported function signature has `any` in its parameter or return type. Excludes test files (`*.test.ts`, `*.spec.ts`, `__tests__/`). Evidence: grep `^export .*: any|=>.*\\bany\\b` against non-test files.

**T2 — `as` cast past system edge (🟠)**
A type assertion at a boundary where runtime validation should sit instead — `JSON.parse(s) as User`, DB row cast directly to domain entity. Evidence: grep `as\\s+\\w+` paired with `JSON.parse|fetch|query`.

**T3 — Discriminated union encoded as function overload (🟡)**
Multiple `function foo(x: A): B; function foo(x: C): D;` overloads that differ only by parameter shape — should be a discriminated-union parameter. Evidence: overload-block detection.

**T4 — Missing exhaustive switch — no `never` check on default branch (🟠)**
A `switch` on a discriminated-union tag without a `default` branch that asserts `_exhaustive: never`. Adding a variant won't fail compile. Evidence: walk `switch` statements + check the default branch's body.

**T5 — Mutable shared state typed `readonly` (or vice-versa) (🟡)**
A `readonly T[]` / `Readonly<T>` annotation on a value that is mutated via index assignment or `.push()`, or a mutable annotation on a value treated as immutable (frozen with `Object.freeze`, never reassigned). Evidence: annotation vs mutation-site mismatch.

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the TypeScript extension emits `## Per-stack findings — typescript` blocks dimension-keyed, with `[typescript]` row prefix added by the core merge.

## Anti-patterns

- Flagging `any` in test fixtures or stub typing.
- Re-flagging React/Vue framework concerns under T-rules.
- Promoting T5 to 🔴 — `readonly` drift is 🟡 unless it actually crashes (then it's T1/T2 territory).

## Final checklist

- All 8 heuristics walked (or skipped with reason)?
- Test files excluded from T1?
- Ownership boundary respected — no framework+TS concerns (those belong to the framework extension)?
- De-duplicated by root-cause, not by symptom?
