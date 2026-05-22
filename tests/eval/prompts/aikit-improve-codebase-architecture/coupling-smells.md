---
id: coupling-smells
skill: aikit-improve-codebase-architecture
expects:
  - reads CONTEXT.md and docs/adr/ before proposing changes
  - cites specific files and uses the project's domain language
  - prioritises by impact (high-coupling / high-change-frequency first)
  - proposes deepening opportunities, not just renames
  - flags any proposed change that would contradict an existing ADR
---

# Prompt

The team keeps saying our codebase "feels messy" but nobody can point at
what's wrong. The hot spots seem to be `services/billing/` and
`controllers/Instances/`. Find concrete architectural improvements I can
sequence into the next 2 sprints.
