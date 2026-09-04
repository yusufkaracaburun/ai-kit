---
id: fixture-scan
skill: audit-architecture-vue
expects:
  - surfaces all 8 heuristics V1-V8 as dimension-keyed findings
  - flags V6 (cross-feature reach-through import) as 🔴 with the sibling feature named
  - fires V2 only because detect_api reports `mixed` (not on a uniform codebase)
  - respects ownership boundary with TypeScript extension (no T-rules, and V8 owns the defineProps finding)
  - emits no V-rules under dimensions 3, 4 or 5 (core walk owns those)
  - tools-ingested header line lists ESLint / vue-tsc with ✓ or ✗ based on availability
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the Vue audit extension against `tests/fixtures/audit-vue/`. Report the 8 dimension-keyed findings, state the detected API split and feature root, and confirm that the ownership boundary with the TypeScript extension is respected (no TS-language smells in this output).
