---
id: fixture-scan
skill: audit-architecture-shadcn
expects:
  - surfaces the 6 heuristics S1-S6 as dimension-keyed findings
  - flags S6 (components.json alias drift) as 🔴 when alias points at non-existent path
  - respects ownership boundary with the React extension (no R-rules in this output)
  - respects ownership boundary with the TypeScript extension (no T-rules in this output)
  - tools-ingested header line lists components.json with ✓ or ✗
  - shadcn-aliases header lists resolved ui / components / utils aliases
  - excludes type-only imports + shared `cn` util from the S5 cross-primitive-coupling walk
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the shadcn/ui audit extension against a sample project using shadcn/ui. Report the dimension-keyed findings and confirm the ownership boundary with the React + TypeScript extensions is respected (no R-rules or T-rules in this output).
