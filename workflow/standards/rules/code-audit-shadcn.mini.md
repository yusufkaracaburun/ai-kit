---
name: code-audit-shadcn
description: shadcn/ui-specific audit heuristics — 6 checks across the 9 canonical audit dimensions (cn() merge discipline, cva variants, forwardRef contract, import-path drift, primitive isolation, components.json drift). Loaded when `components.json` declares the shadcn schema.
applies_to:
  frameworks: ["shadcn"]
  languages: ["typescript", "javascript"]
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY shadcn/ui audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when `components.json` at the project root declares `"$schema": "https://ui.shadcn.com/schema.json"`. Layers on top of [`code-audit.mini.md`](code-audit.mini.md). Co-loads with [`code-audit-react.mini.md`](code-audit-react.mini.md). **Never introduces a new dimension.**

Out of scope: pre-merge diff review (`/ai:review`), runtime / performance profiling, accessibility (Radix primitives ship accessibility — out of audit scope), security, React-shaped smells (owned by [`code-audit-react.mini.md`](code-audit-react.mini.md)), TypeScript-language smells (owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md)).

## Strictness

Default — per-finding severity, no floor. Surfaced in the report header: `**Extensions loaded:** audit-architecture-shadcn`.

## Ownership boundary

This rule fires only on **shadcn/ui-shaped** smells (the `cn()`/`cva()`/`forwardRef`/aliases/primitive-isolation patterns). Each finding row appears exactly once across `[shadcn]`, `[react]`, `[nextjs]`, and `[typescript]` prefixes.

## The 6 heuristics

### Dimension 1 · Design patterns

**S1 — Class concatenation without `cn()` (🟠)**
A `className={…}` value built via template literal (`` `p-4 ${cond ? 'bg-blue-500' : ''}` ``) or `+` concatenation. Without `cn()` (or equivalent `clsx` + `tailwind-merge`), the last-wins merge for conflicting Tailwind utilities (`p-2` vs `p-4`, `bg-blue-500` vs `bg-red-500`) silently breaks — the browser keeps the rightmost in source order, which may not be the rightmost in the string. Evidence: grep `className={\`` and `className={[\`'].+[\`'] *\+`. Skip when the dynamic part is a single literal (no merge needed). Fix: wrap with `cn(...)` from the project's util module.

### Dimension 2 · SOLID

*(Owned by `[react]` R1 / R2 for component shape.)*

### Dimension 3 · DRY

*(Owned by `[react]` R3 for component-level duplication.)*

### Dimension 4 · YAGNI / dead-code

*(Owned by `[react]` R5.)*

### Dimension 5 · Naming + comment-drift

**S6 — `components.json` config drift (🔴)**
`components.json` declares an alias (`aliases.ui`, `aliases.components`, `aliases.utils`) that points at a path which does not exist on disk, OR is not resolvable via `tsconfig.json` `paths`. `shadcn` CLI invocations will write files to a phantom location; subsequent imports will fail at build time or — worse — silently resolve to a different file with the same name. Evidence: parse `components.json` → resolve each alias against `tsconfig.json` + on-disk. Fix: re-run `npx shadcn init` or repair the alias by hand.

### Dimension 6 · Coupling / cohesion

**S2 — Inline variant instead of `cva()` extension (🟡)**
A consumer of a shadcn primitive (e.g. `<Button>`) extends its visual style via conditional className strings (`className={cn(isDanger && 'bg-red-500 text-white')}`) instead of adding the variant to the primitive's `cva()` config. Variant explosion across consumers — same visual concept declared N times. Evidence: grep `<<Primitive>.*className={cn\(` with conditional Tailwind class injections; check the primitive's `cva` config for the matching enum case. Heuristic — surface for reviewer confirm. Fix: add the variant to the primitive's `cva(...)` and use the typed `variant=` prop.

### Dimension 7 · Layering / dependency direction

**S4 — Deep relative import instead of declared alias (🟡)**
A consumer imports `components/ui/<X>` via `../../../components/ui/button` rather than the `aliases.ui` value from `components.json` (typically `@/components/ui/button`). Aliases exist precisely so refactors don't break callers; bypassing them re-introduces the coupling shadcn aliases are designed to remove. Evidence: grep imports targeting `components/ui/` and confirm path matches the alias prefix. Fix: use the alias.

**S5 — Cross-primitive coupling inside `components/ui/` (🟠)**
A file under `components/ui/` imports another file under `components/ui/`. Primitives must remain leaf-level — `Dialog` should not import `Button`; consumers compose them. Exceptions: type-only imports + the shared `cn` util (typically `@/lib/utils`). Evidence: walk imports in each `components/ui/*.tsx` and resolve the target. Fix: hoist the composition to the consumer; if a shared sub-pattern is needed, extract into a non-primitive helper.

### Dimension 8 · Error handling / failure modes

*(shadcn-specific failure modes overlap with `[react]` and the core — no S-rule here.)*

### Dimension 9 · Type safety / contract clarity

**S3 — Primitive wrapped without `forwardRef` (🟠)**
A file in `components/ui/` re-exports or wraps a Radix primitive (or another underlying DOM element) without `React.forwardRef`. Callers can't pass a `ref` through — breaks the contract that shadcn primitives promise (every shipped primitive uses `forwardRef`). Evidence: grep `components/ui/*.tsx` for component declarations and confirm `React.forwardRef<…>` (or `forwardRef<…>`) wraps the export. Fix: convert the export to a `forwardRef` wrapper and type the ref argument.

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the shadcn extension emits `## Per-stack findings — shadcn` blocks dimension-keyed, with `[shadcn]` row prefix added by the core merge.

## Anti-patterns

- Re-flagging god-component / props-bloat / RSC boundary — owned by `[react]`.
- Promoting `S2` to 🔴 without inspecting the variant config — it's a 🟡 by default; shadcn permits inline overrides for one-off cases.
- Flagging `<Button asChild>` patterns (Radix Slot composition) — that IS the canonical pattern.
- Treating `style: "default"` vs `"new-york"` as a finding — stylistic, not architectural.

## Final checklist

- All 6 heuristics walked (or skipped with reason)?
- `components.json` parsed + aliases surfaced in the report header?
- Cross-primitive coupling walk excluded the `cn` util + type-only imports?
- De-duplicated by root-cause, not by symptom?
- Ownership boundary respected — no React-shaped or TS-language smells (those belong to their own extensions)?
