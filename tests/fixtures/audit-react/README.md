# audit-react fixture

Fixture for `tests/bin/cases/audit-react-extension.sh`. React 19 + Next.js 15 shape.

Every React heuristic R1-R8 has a triggering snippet under `app/` or `src/`, marked with an inline `// R<N>:` token so the test harness can verify presence via `grep`. The snippets aren't runnable — they exist to assert fixture shape, not to compile.

When the `audit-architecture-react` extension runs against this fixture, it should surface all 8 findings under their respective dimensions.
