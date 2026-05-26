---
id: finding-a1
skill: audit-fix
expects:
  - reads the referenced audit report file before proposing any edit
  - locates the specific finding (e.g. A1) and lists only its affected paths
  - applies fixes scoped to those paths only — no drive-by edits to unrelated files
  - re-runs the touched dimension (or its check) after the edit to verify the finding closes
  - creates exactly one commit per finding with a message that references the finding id
  - rewrites the finding's row in the report to "✅ fixed" with the commit SHA
  - refuses to bundle multiple findings into one commit or expand scope without explicit approval
---

# Prompt

I ran `/ai:audit-architecture` an hour ago — the report is at
`docs/audits/audit-2026-05-26.md`. Take the first blocker finding (`A1 —
Coupling between auth middleware and tenant resolver`) and fix it. Stay
inside the finding's affected paths and stop when one finding is done so I
can approve the next one.
