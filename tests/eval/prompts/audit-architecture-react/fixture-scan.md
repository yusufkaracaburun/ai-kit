---
id: fixture-scan
skill: audit-architecture-react
expects:
  - surfaces all 8 heuristics R1-R8 as dimension-keyed findings
  - flags R6 (RSC boundary leak) as 🔴 when a `'use client'` file imports a server-only module
  - respects ownership boundary with TypeScript extension (no T-rules in this output)
  - tools-ingested header line lists ESLint / tsc with ✓ or ✗ based on availability
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the React audit extension against `tests/fixtures/audit-react/`. Report the RSC boundary findings, the 8 dimension-keyed findings, and confirm that the ownership boundary with the TypeScript extension is respected (no TS-language smells in this output).
