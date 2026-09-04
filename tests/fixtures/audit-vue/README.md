# audit-vue fixture

Fixture for `tests/bin/cases/audit-extensions.sh`. Vue 3.5 + Composition-API shape,
with one deliberate Options-API outlier so `detect_api` reports `mixed`.

Every Vue heuristic V1-V8 has a triggering snippet under `src/`, marked with an
inline `V<N>:` token so the test harness can verify presence via `grep`. The
snippets aren't runnable — they exist to assert fixture shape, not to compile.

Two feature roots (`src/features/orders`, `src/features/customers`) exist so V6
(cross-feature reach-through import) has a real boundary to cross.

When the `audit-architecture-vue` extension runs against this fixture, it should
surface all 8 findings under their respective dimensions.
