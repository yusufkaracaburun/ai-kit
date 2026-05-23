---
id: legacy-laravel-monolith
skill: audit-architecture
expects:
  - walks the codebase against the 9 canonical dimensions (patterns, SOLID, DRY, YAGNI, naming+comment-drift, coupling, layering, error-handling, type-safety)
  - reads CONTEXT.md and docs/agents/architecture.md before walking
  - tags every finding with one of 🔴 Blocker / 🟠 High / 🟡 Medium / 🟢 Low
  - writes the report to docs/reviews/<YYYY-MM-DD>-<scope>-architecture-audit.md
  - includes a tech-debt rolling table at the bottom of the report
  - does NOT write code fixes — read-only audit only
  - cross-refs /ai:review for security and /ai:improve-codebase-architecture for deepening
---

# Prompt

This is a 4-year-old Laravel monolith. I want a whole-codebase architecture
audit before we onboard two new engineers — find the SOLID violations, the
god-controllers, the DRY breakages, anything that's been growing tech-debt
quietly. Don't fix anything yet; I want the report first so we can triage.
