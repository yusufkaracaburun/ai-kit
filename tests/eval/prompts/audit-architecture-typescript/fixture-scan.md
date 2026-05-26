---
id: fixture-scan
skill: audit-architecture-typescript
expects:
  - surfaces all 8 heuristics T1-T8 as dimension-keyed findings
  - excludes test fixtures (*.test.ts / *.spec.ts) from T1 (`any`-past-boundary)
  - respects ownership boundary — no React/Vue/Next framework-specific concerns surfaced
  - tools-ingested header line lists tsc / ts-prune / ESLint with ✓ or ✗
  - header includes `force-strict=yes` notice
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the TypeScript audit extension against `tests/fixtures/audit-typescript-pure/`. Report the 8 dimension-keyed findings and confirm the force-strict notice. Confirm the ownership boundary is respected (no framework-specific findings, since this fixture is framework-less).
