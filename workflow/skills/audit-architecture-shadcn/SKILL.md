---
name: audit-architecture-shadcn
description: shadcn/ui-specific architecture audit — 6 heuristics across the 9 audit dimensions (cn() merge discipline, cva variants, forwardRef contract, import-path drift, primitive vs composed boundary, components.json drift). Default strictness. Use when `/ai:audit-architecture` runs against a project using shadcn/ui (auto-loaded by the extension loader alongside the React extension).
extends: audit-architecture
applies_to:
  frameworks: ["shadcn"]
  languages: []
strictness: default
---

# Audit Architecture — shadcn/ui extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). Adds 6 shadcn/ui-specific heuristics under the canonical 9 dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). **Never introduces a new dimension.**

Auto-loaded by `bin/audit-extension-loader.sh` when `components.json` exists at the project root and declares `"$schema": "https://ui.shadcn.com/schema.json"`. Loads alongside the React extension; ownership boundary below. Skip with `AI_KIT_AUDIT_NO_EXTEND=1`.

## Ownership boundary with the React + TypeScript extensions

This extension owns **shadcn/ui-shaped** smells: `cn()` merge discipline, `cva()` variant patterns, `React.forwardRef` contract on copy-paste primitives, import-path drift away from the `components.json`-declared alias, primitives leaking outside `components/ui/`, drift between `components.json` config and on-disk reality.

The [`audit-architecture-react`](../audit-architecture-react/SKILL.md) extension owns **React-shaped** smells (god-component, props-bloat, RSC boundary). The [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) extension owns **language-level** TypeScript smells.

Each finding row appears exactly once across `[shadcn]`, `[react]`, `[nextjs]`, and `[typescript]` prefixes.

## Heuristics

6 heuristics. Stable ID prefix `S<N>`.

| ID | Dim | Severity | Heuristic |
|---|---|---|---|
| S1 | 1 | 🟠 | Tailwind classes concatenated with template literals or `+` instead of `cn()` — last-wins merge silently broken |
| S2 | 6 | 🟡 | New variant added inline via conditional classes instead of extending the primitive's `cva()` config |
| S3 | 9 | 🟠 | shadcn primitive (Button/Input/Dialog/etc.) extended without `React.forwardRef` — loses ref-forwarding contract |
| S4 | 7 | 🟡 | shadcn primitive imported via deep relative path (`../../../components/ui/button`) instead of the `components.json`-declared alias |
| S5 | 7 | 🟠 | shadcn primitive (file under `components/ui/`) imported by another primitive in `components/ui/` — primitives must remain leaf-level, no cross-primitive coupling |
| S6 | 5 | 🔴 | `components.json` config drift — `aliases.ui` or `aliases.components` points at a path that does not exist on disk |

## Process

When invoked after the core walk:

1. **Read `components.json`.** Parse `aliases.ui`, `aliases.components`, `aliases.utils`, `tailwind.cssVariables`. Surface in report header (`**shadcn aliases:** ui=@/components/ui, utils=@/lib/utils`).
2. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-shadcn-helpers.sh" run_tools <project-path>` — currently emits a `**Tools ingested:** components.json ✓/✗` header. No external scanner yet.
3. **Walk the 6 heuristics.**
   - **S1:** grep `className={` followed by template-literal or `+`-concatenation of class strings; flag any without a `cn(` wrapper. Skip when the dynamic part is a single literal string (no merge needed).
   - **S2:** grep `className={cn(<primitive>Variants(`-shaped uses → look for sibling files that pass a manually-merged variant string instead of an enum case. Heuristic flag: 🟡, requires reviewer confirm.
   - **S3:** for each `components/ui/*.tsx` that re-exports / wraps a Radix primitive, confirm `React.forwardRef` (or `forwardRef`) is present. Missing → 🟠. Skip pure-render utility files.
   - **S4:** for each import of `components/ui/<X>`, confirm the import path starts with the `aliases.ui` value from `components.json`. Deep relative paths (`../../`) → 🟡.
   - **S5:** walk imports inside `components/ui/*.tsx` — flag any import whose path resolves to another file inside `components/ui/`. (Exception: type-only imports + the shared `cn` util.)
   - **S6:** for each alias in `components.json`, resolve against `tsconfig.json` `paths` + on-disk dir. Missing dir → 🔴.
4. **Apply severity per the rule.** Default strictness — no floor.
5. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — shadcn

### Dimension 9 · Type safety / contract clarity
- src/components/ui/button.tsx:12 · 🟠 · S3 Button wraps Radix Slot without `forwardRef` · `export const Button = (props) => …` · wrap with `React.forwardRef<HTMLButtonElement, ButtonProps>(…)` so callers can pass refs

### Dimension 1 · Design patterns
- src/components/UserCard.tsx:24 · 🟠 · S1 Tailwind classes concatenated via template literal — `cn()` not used · `className={\`p-4 \${isActive ? 'bg-blue-500' : ''}\`}` silently breaks last-wins on `bg-*` · wrap with `cn('p-4', isActive && 'bg-blue-500')`
```

6. **Hand markdown back to the core skill.** Do NOT write the report.

## Helper-script

[`bin/audit-shadcn-helpers.sh`](../../../bin/audit-shadcn-helpers.sh):

- `run_tools <project-path>` — confirms `components.json` is readable + parseable. Emits one-line `**Tools ingested:** components.json ✓` header. No external scanner.
- `read_aliases <project-path>` — emits the resolved aliases on stdout (one `key=value` per line): `ui=…`, `components=…`, `utils=…`. Surfaces drift to the core skill.

## Anti-patterns

- Re-flagging god-component or props-bloat on shadcn primitives — owned by `[react]` R1 / R2.
- Promoting `S2` to 🔴 without seeing the variant config — it's a 🟡 by default because shadcn explicitly permits inline overrides.
- Flagging primitives that intentionally compose `cn` + Radix Slot — that's the canonical pattern, not a violation.
- Treating `components.json` `style: "default"` vs `"new-york"` as a finding — it's a stylistic choice, not an architecture smell.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill.
- [`audit-architecture-react`](../audit-architecture-react/SKILL.md) — React-shaped smells (god-component, RSC boundary).
- [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) — TypeScript-language smells.
- [`code-audit-shadcn.mini.md`](../../../standards/rules/code-audit-shadcn.mini.md) — 6 heuristics with evidence patterns.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract.
