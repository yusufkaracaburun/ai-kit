# audit-typescript-pure fixture

Fixture for `tests/bin/cases/audit-extensions.sh`. Framework-less TypeScript library — no React, Vue, Next.js, etc.

Every TypeScript heuristic T1-T8 has a triggering snippet under `src/`, marked with an inline `// T<N>:` token so the test harness can verify presence via `grep`.

When the `audit-architecture-typescript` extension runs against this fixture, it should surface all 8 findings under their dimensions. Because this fixture has no framework, none of the framework extensions (React/Vue/Next) fire — making it the canonical control for the language-level ownership rule.
