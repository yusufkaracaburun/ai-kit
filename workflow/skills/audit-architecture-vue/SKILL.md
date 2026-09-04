---
name: audit-architecture-vue
description: Vue 3-specific architecture audit — 8 Composition-API / SFC heuristics across the 9 audit dimensions, including cross-feature import direction, provide/inject typing and the compiler-macro type contract. Default strictness (per-finding severity, no floor). Use when `/ai:audit-architecture` runs against a Vue project (auto-loaded by the extension loader).
extends: audit-architecture
applies_to:
  frameworks: ["vue"]
  languages: []
strictness: default
---

# Audit Architecture — Vue extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). Adds 8 Vue 3-specific heuristics under the canonical 9 dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). **Never introduces a new dimension.**

Auto-loaded by `bin/audit-extension-loader.sh` when the project package.json declares `vue`. Skip with `AI_KIT_AUDIT_NO_EXTEND=1`.

**Vue 3 only.** Vue 2 went end-of-life 2023-12-31. Against a Vue 2 project this extension emits one migration finding and stops — it does not encode Vue 2 idioms as heuristics.

## Ownership boundary with the TypeScript extension

This extension owns **Vue-shaped** smells: SFC shape, Composition-API idioms, compiler macros (`defineProps` / `defineEmits`), `provide`/`inject`, mixins, cross-feature imports.

The [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) extension owns **language-level** TypeScript smells: `any` past module boundaries, `as` casts past edges, generic variance. Its rule text explicitly cedes `defineProps<T>()` to this extension — V8 is the Vue-side owner of that finding, and no `T*` row may restate it.

Generic duplication and dead-code stay with the **core** walk (dimensions 3 and 4). This extension emits no V-rules there.

## Heuristics

8 heuristics encoded in [`standards/rules/code-audit-vue.mini.md`](../../../standards/rules/code-audit-vue.mini.md). Stable ID prefix `V<N>`.

| ID | Dim | Severity | Heuristic |
|---|---|---|---|
| V1 | 1 | 🟡 | `watch` doing derived state where `computed` belongs |
| V2 | 1 | 🟡 | Options-API SFC in a codebase that also uses `<script setup>` |
| V3 | 2 | 🟠 | Vue 3 `mixins:` where a composable belongs |
| V4 | 6 | 🟠 | Props-bloat > 8 props on an SFC |
| V5 | 6 | 🟠 | `provide`/`inject` on a string key instead of `InjectionKey<T>` |
| V6 | 7 | 🔴 | Cross-feature reach-through import (sibling feature's internals) |
| V7 | 8 | 🟠 | Top-level `await` in `<script setup>` with no `<Suspense>` ancestor |
| V8 | 9 | 🟠 | Runtime-object `defineProps` / `defineEmits` in a TS SFC |

## Process

When invoked after the core walk:

1. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-vue-helpers.sh" run_tools <project-path>` to ingest ESLint (`eslint-plugin-vue`) + `vue-tsc --noEmit` output. Both gated by presence in the project's `node_modules/.bin/` or on `PATH`. Cached under `$TMPDIR/ai-kit-audit-vue-<ts>/`.
2. **Detect the API split.** Call `bash "$AI_KIT_ROOT/bin/audit-vue-helpers.sh" detect_api <project-path>` → `composition` | `options` | `mixed` | `none`. V2 fires only on `mixed`; on a uniform `options` codebase V2 is silent (that is a migration question, not an audit finding). When it fires, the finding names the **Options** side and its count, even when Options is the majority — never the `<script setup>` files. `detect_api` counts `defineComponent({…})` without `setup()` as Options; that wrapper is the dominant Options form in TS codebases.
3. **Detect the feature root.** Look for `src/features/`, `src/modules/`, or `src/views/` with ≥2 sub-directories. No feature root → V6 does not fire; flag the absence once under dimension 7 instead ("no layering rules declared"), per the core rule.
4. **Walk the 8 heuristics.** V4/V8 are macro-shape — grep + member count. V1/V3/V5 are call-shape greps. V2 needs the step-2 ratio. V6 needs import resolution against the step-3 feature root. V7 needs callsite analysis: async `<script setup>` SFCs, then their parents' templates for `<Suspense>`.
5. **Apply severity per the rule.** Default strictness — no floor. Per-finding severity stands.
6. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — vue

### Dimension 7 · Layering / dependency direction
- src/features/orders/composables/useOrders.ts:4 · 🔴 · V6 cross-feature reach-through — orders imports customers' internals · `import { fmt } from '@/features/customers/lib/format'` · re-export from `features/customers/index.ts` or hoist `fmt` into `shared/`

### Dimension 9 · Type safety / contract clarity
- src/features/orders/OrderCard.vue:2 · 🟠 · V8 runtime-object `defineProps` in a TS SFC · `defineProps({ id: { type: String } })` · switch to `defineProps<{ id: string }>()`
```

7. **Hand markdown back to the core skill.** Do NOT write the report.

## Helper-script

[`bin/audit-vue-helpers.sh`](../../../bin/audit-vue-helpers.sh):

- `run_tools <project-path>` — runs ESLint in JSON format when a config and binary are present; runs `vue-tsc --noEmit` when `tsconfig.json` is present. Both gated. Emits a one-line `Tools ingested:` header on stdout. Caches per-tool raw output to `$TMPDIR/ai-kit-audit-vue-<ts>/`.
- `detect_api <project-path>` — counts `<script setup>` vs Options-API SFCs and emits `composition` | `options` | `mixed` | `none`. Surfaced in the report header (`**API style:** …`) and gates V2.

Format tools (Prettier) and security scanners (npm audit) are out of scope.

## Anti-patterns

- Firing V2 on a uniformly Options-API codebase — that is a migration decision, not an audit finding.
- Reporting V2 against the `<script setup>` files because they are the minority — the finding is always the Options side, and one aggregate row, not one per file.
- Firing V6 without a detected feature root — inventing a layering scheme the project never declared.
- Restating `defineProps<T>()` findings as `T*` rows — V8 owns them (see ownership boundary).
- Encoding Vue 2 idioms (`Vue.extend`, `filters:`, `.sync`) as heuristics.
- Re-flagging dimensions the core already handled.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill.
- [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) — TypeScript-language smells (separate ownership).
- [`code-audit-vue.mini.md`](../../../standards/rules/code-audit-vue.mini.md) — 8 heuristics with evidence patterns.
- [`bin/audit-vue-helpers.sh`](../../../bin/audit-vue-helpers.sh) — ESLint + vue-tsc gates, API-split detection.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract.
