---
id: instance-update-record
skill: aikit-grill-with-docs
expects:
  - reads or asks for CONTEXT.md and docs/adr/ before forming a position
  - uses the project's domain vocabulary (e.g. Instance, not "tenant" if CONTEXT.md forbids it)
  - flags terminology conflicts with the existing glossary explicitly
  - proposes a CONTEXT.md or ADR diff inline as decisions crystallise
  - does NOT invent new terms when the glossary already has one
---

# Prompt

We have a model called `InstanceUpdateRecord` that nobody on the team can
fully explain. Per CONTEXT.md it might track renewals/expiries, but the
schema has columns that could mean version-upgrade history too. I want to
clarify what it represents and either lock it in an ADR or mark it for
removal. Grill me with the docs.
