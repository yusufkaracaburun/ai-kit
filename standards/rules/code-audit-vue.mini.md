---
name: code-audit-vue
description: Vue 3-specific audit heuristics — 8 Composition-API / SFC checks across the 9 canonical audit dimensions, including the feature-boundary import direction and provide/inject typing. Loaded when the project depends on vue.
applies_to:
  frameworks: ["vue"]
  languages: ["typescript", "javascript"]
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY Vue audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when the project depends on Vue (raw or Vite; Nuxt only when `vue` is a direct dependency). Layers on top of [`code-audit.mini.md`](code-audit.mini.md). Never introduces a new dimension.

Vue 3 only. Vue 2 reached end-of-life on 2023-12-31 — a Vue 2 codebase gets a single migration finding from the core walk, not a structural audit. Do not encode Vue 2 idioms (`Vue.extend`, `filters:`, `.sync`) as heuristics here.

Out of scope: pre-merge diff review (`/ai:review`), runtime / performance profiling, accessibility (separate audit), security (npm audit / `/ai:review` security-deep-pass), TypeScript-language smells (owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md)).

## Strictness

Default — per-finding severity, no floor. Surfaced in the report header: `**Extensions loaded:** audit-architecture-vue`.

## Ownership boundary

This rule fires only on **Vue-shaped** smells: SFC shape, Composition-API idioms, the compiler macros, provide/inject, feature-boundary imports.

Language-level TS smells (`any` past module boundaries, `as` casts past edges, generic variance) are owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md), which explicitly cedes `defineProps<T>()` to this extension.

Generic duplication (dimension 3) and dead-code (dimension 4) stay with the core walk — a duplicated composable is block-duplicate code, not a Vue-shaped smell, and re-encoding it here would double-report.

## The 8 heuristics

### Dimension 1 · Design patterns

**V1 — `watch` doing derived state where `computed` belongs (🟡)**
A `watch(source, cb)` whose callback body only assigns to a `ref`/`reactive` field, with no async call, no I/O, no `emit`. Derived state expressed as a side-effect: the dependency graph becomes imperative, the value can go stale, and two watchers assigning the same ref race. Evidence: walk `watch(`/`watchEffect(` bodies; flag those whose statements are all `x.value = …` assignments. Fix: `computed(() => …)`.

**V2 — Options-API SFC in a codebase that also uses `<script setup>` (🟡)**
A `.vue` file whose `<script>` block is `export default { … }` or `export default defineComponent({ … })` without its own `setup()`, in a project where other SFCs use `<script setup>`. Two idioms for one job: composables cannot be shared into the Options component without a `setup()` bridge, and reviewers context-switch per file.

**The finding always names the Options side, never the `<script setup>` side — regardless of which is the minority.** A codebase that is 90% `defineComponent({…})` and 10% `<script setup>` has 90% of the work ahead of it, not 10% of outliers to revert. Report it as one aggregate finding with the count, not one row per file.

Evidence: `bin/audit-vue-helpers.sh detect_api` → `mixed`, then count the Options side. Note that `defineComponent({…})` is the dominant Options form in TS codebases — counting only `export default {` undercounts it to near zero. Fix: migrate Options SFCs to `<script setup>` incrementally, or record the split in `docs/adr/` as deliberate.

### Dimension 2 · SOLID

**V3 — Vue 3 `mixins:` where a composable belongs (🟠)**
An SFC or a `defineComponent` declares `mixins: [...]`. Mixins inject properties implicitly: the component's real surface is invisible at the callsite, names collide silently across mixins, and there is no test seam to substitute one. Dependency-inversion violation with a Vue-shaped mask. Evidence: grep `mixins:` in `**/*.vue` and `**/*.ts`. Fix: extract to a `useX()` composable returning an explicit object.

### Dimension 6 · Coupling / cohesion

**V4 — Props-bloat > 8 props on an SFC (🟠)**
A component declares > 8 props (excluding `modelValue` pairs and attrs fallthrough). Likely a missing composition seam, or a god-component masquerading as a leaf. Evidence: count members of the `defineProps<T>()` type argument, or keys of the runtime-object form. Fix: group related props into one typed object prop, or split the component.

**V5 — `provide`/`inject` on a string key instead of `InjectionKey<T>` (🟠)**
`provide('someKey', value)` / `inject('someKey')` with a raw string. Ambient global state with no typed contract: the injected value is `unknown` (or worse, silently `any`), collisions across libraries are undetectable, and no compiler error fires when the provider disappears. Evidence: grep `provide(`/`inject(` for a string-literal first argument. Fix: export a `const key: InjectionKey<T> = Symbol('name')` from one module and use it on both sides.

### Dimension 7 · Layering / dependency direction

**V6 — Cross-feature reach-through import (🔴)**
A module under a feature root (`src/features/A/**`, `src/modules/A/**`, `src/views/A/**` — whichever convention the project uses) imports a **sibling feature's internals** rather than its public entry: `../B/composables/useThing`, `@/features/B/components/Inner.vue`, `@/modules/B/store/private`. Every such import welds two features together; the pair can no longer be moved, deleted, or owned separately, and the "features" stop being boundaries. Evidence: resolve every relative/aliased import to a feature root, flag any that crosses into a sibling and does not land on that sibling's `index.ts` / declared public surface. Fix: export the symbol from the sibling's public entry, or hoist the shared piece into `shared/`. Enforce mechanically with ESLint `import/no-restricted-paths` zones (already available via `eslint-plugin-import` — no new dependency) or `eslint-plugin-boundaries`.

Skip when the project has no feature-root convention — flag the absence once, do not invent one (mirrors the core walk's dimension-7 rule).

### Dimension 8 · Error handling / failure modes

**V7 — Top-level `await` in `<script setup>` with no `<Suspense>` ancestor (🟠)**
An SFC with `<script setup>` containing a top-level `await` (making it an async component) that is rendered without a `<Suspense>` boundary anywhere on its parent chain. The component silently never renders, and a rejected await has no handler — a blank region with no error in the console. Evidence: find `<script setup` SFCs with top-level `await`; walk their callsites for an enclosing `<Suspense>`. Fix: wrap the callsite in `<Suspense>` with a fallback and an `onErrorCaptured` handler, or move the await into `onMounted` with explicit loading/error state.

### Dimension 9 · Type safety / contract clarity

**V8 — Runtime-object `defineProps` / `defineEmits` in a TS SFC (🟠)**
`defineProps({ id: { type: String, required: true } })` or `defineEmits(['change'])` in a project with a `tsconfig.json`. The runtime form gives no compile-time contract: prop types are not checked at the callsite, emit payloads are untyped, and refactors silently break consumers. Evidence: grep `defineProps(`/`defineEmits(` followed by `{` or `[` instead of `<`. Fix: `defineProps<{ id: string }>()` / `defineEmits<{ change: [id: string] }>()`, with `withDefaults()` where defaults are needed.

### Dimensions 3, 4, 5

*(No Vue-shaped V-rules. Duplication, dead-code and naming-drift on the Vue surface are indistinguishable from the generic case — the core walk owns them. Do not add placeholders.)*

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the Vue extension emits `## Per-stack findings — vue` blocks dimension-keyed, with `[vue]` row prefix added by the core merge.

## Anti-patterns

- Flagging Options API in a codebase that is uniformly Options API — V2 fires on the **split**, not on the style.
- Flagging `watch` that performs I/O, emits, or debounces — V1 is derived-state-only.
- Promoting V6 below 🔴 because "it is only one import" — cross-feature reach-through is the finding that compounds.
- Encoding Vue 2 idioms as findings (see scope note above).
- Re-reporting findings the core already wrote.

## Final checklist

- All 8 heuristics walked (or skipped with reason)?
- Feature-root convention detected before V6 ran (or its absence flagged once)?
- Composition/Options split measured before V2 fired?
- De-duplicated by root-cause, not by symptom?
- Ownership boundary respected — no TS-language smells (those belong to `code-audit-typescript.mini.md`), no generic DRY/dead-code (core walk)?
