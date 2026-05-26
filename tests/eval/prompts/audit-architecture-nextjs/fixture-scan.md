---
id: fixture-scan
skill: audit-architecture-nextjs
expects:
  - surfaces the 7 heuristics N1-N7 as dimension-keyed findings
  - flags N7 (App + Pages route collision) as 🔴 when the same segment exists in both trees
  - respects ownership boundary with the React extension (no R-rules in this output)
  - respects ownership boundary with the TypeScript extension (no T-rules in this output)
  - tools-ingested header line lists `next lint` with ✓ or ✗ based on availability
  - router-detected header line emits `app`, `pages`, `both`, or `none`
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the Next.js audit extension against a sample Next.js project. Report the App-Router findings across dimensions 1, 7, 8, and 9, and confirm the ownership boundary with the React and TypeScript extensions is respected (no R-rules or T-rules in this output).
