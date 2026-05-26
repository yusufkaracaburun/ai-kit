---
name: audit-architecture-typescript
description: TypeScript-specific architecture audit — 8 framework-agnostic heuristics targeting language-level concerns (any-leak, as-cast-past-edge, exhaustive switch, decorator/runtime mismatch). Default strictness. Use when `/ai:audit-architecture` runs against any project that contains a `tsconfig.json` (auto-loaded by the extension loader; fires alongside React/Vue/Next/etc. extensions).
extends: audit-architecture
applies_to:
  frameworks: []
  languages: ["typescript"]
strictness: default
---

# Audit Architecture — TypeScript extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). Adds 8 TypeScript-specific heuristics under the canonical 9 dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). **Never introduces a new dimension.**

**Framework-agnostic.** Auto-loaded by `bin/audit-extension-loader.sh` whenever a `tsconfig.json` is present. Fires **alongside** the React / Vue / Next.js extensions, not instead of them.

## Ownership rule

This extension owns **language-level** TypeScript smells that no framework extension touches:

- `any` past module boundary
- `as` casts past system edges
- Discriminated-union encoded as function overload
- Missing exhaustive switch (no `never` check on default)
- `readonly` vs mutable contract drift
- Decorator + runtime mismatch
- Duplicated type alias
- Unused type export

Framework extensions own **framework+TS-specific** concerns (e.g. React's R7 — typing `<form action={…}>` server actions is a React idiom on top of TS, owned by React; the underlying `any`-on-export of the bound function is TS-territory, owned here).

Zero-overlap enforced by the shared fixture `tests/fixtures/audit-react-ts-overlap/` and the contract-test under #79. Every finding row appears exactly once across `[react]` and `[typescript]` prefixes.

## Heuristics

8 heuristics encoded in [`standards/rules/code-audit-typescript.mini.md`](../../../standards/rules/code-audit-typescript.mini.md). Stable ID prefix `T<N>`.

| ID | Dim | Severity | Heuristic |
|---|---|---|---|
| T1 | 9 | 🟠 | `any` past module boundary (exported function signature) |
| T2 | 9 | 🟠 | `as` cast past system edge (DB row → domain, JSON → DTO) |
| T3 | 9 | 🟡 | Discriminated union encoded as function overload — refactor to a tagged union |
| T4 | 9 | 🟠 | Missing exhaustive switch — no `never` check on default branch |
| T5 | 9 | 🟡 | Mutable shared state typed `readonly` (or vice-versa) |
| T6 | 1 | 🟠 | Decorator + runtime mismatch (`@Injectable` on non-class, decorator metadata stripped, wrong-target decorator) |
| T7 | 3 | 🟡 | Duplicated type alias > 2x — extract to shared type |
| T8 | 4 | 🟡 | Unused type export (no consumer outside module — `ts-prune` signal) |

## Process

When invoked after the core walk:

1. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-typescript-helpers.sh" run_tools <project-path>`:
   - `tsc --noEmit --strict` (force-strict-on for audit run, regardless of project's `tsconfig.json` strictness setting) → diagnostics under dimension 9.
   - `ts-prune --json` → unused exports under dimension 4 (T8).
   - ESLint with `@typescript-eslint/strict` subset → reinforces T1/T2/T4.

   All three gated; absence is never fatal. Report header surfaces the force-strict notice.
2. **Walk the 8 heuristics.** T1/T2/T4/T5 are type-shape grep. T3 needs AST-light (function-overload-followed-by-implementation pattern). T6 walks `@Decorator` annotations + the target class/method shape. T7 detects ≥3 textually-equivalent type-alias bodies. T8 ingests `ts-prune` output.
3. **Apply severity per the rule.** Default strictness — no floor.
4. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — typescript

### Dimension 9 · Type safety / contract clarity
- src/api/parser.ts:14 · 🟠 · T1 `any` past module boundary · exported `parse(raw: any): X` · type `raw` as `unknown` and validate at the seam
- src/db/users.ts:42 · 🟠 · T2 `as` cast past system edge · `JSON.parse(s) as User` without runtime check · adopt zod/io-ts at the boundary
```

5. **Hand markdown back to the core skill.**

## Helper-script

[`bin/audit-typescript-helpers.sh`](../../../bin/audit-typescript-helpers.sh):

- `run_tools <project-path>` — runs `tsc --noEmit --strict` (force-strict, regardless of project's tsconfig setting), `ts-prune --json`, and ESLint with the `@typescript-eslint/strict` recommended subset. All gated. Emits a one-line header on stdout including a `force-strict=yes` notice. Caches per-tool raw output to `$TMPDIR/ai-kit-audit-typescript-<ts>/`.

Format tools (Prettier, dprint) and security scanners (npm audit, Snyk) are out of scope.

## Anti-patterns

- **Flagging `any` in test files** — tests are allowed to use `any` for fixture builders and stub typing. Limit T1 to non-`*.test.ts` / non-`*.spec.ts` files.
- **Re-flagging React+TS findings.** R7 (typed `<form action={…}>`) is React's lane — do not duplicate as T1 here.
- **Promoting T5 to 🔴.** `readonly`/mutable drift is 🟡 unless it actually crashes — that's an `any`-or-`unsafe-cast` finding (T1/T2), not T5.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill.
- [`audit-architecture-react`](../audit-architecture-react/SKILL.md) — React+TS-specific concerns (separate ownership).
- [`code-audit-typescript.mini.md`](../../../standards/rules/code-audit-typescript.mini.md) — 8 heuristics with evidence patterns.
- [`bin/audit-typescript-helpers.sh`](../../../bin/audit-typescript-helpers.sh) — tsc + ts-prune + ESLint gates.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract.
