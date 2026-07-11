# Companion tool glue

Integration glue for **companion tools** — third-party AI-productivity tools that
sit alongside ai-kit but are not part of its agile lifecycle. The `recommend-tools`
skill reads these templates and wires whichever tools the user picks.

ai-kit's rule here: **wire, do not vendor.** The tool installs from its own
upstream; ai-kit owns only the integration glue in this directory. Same pattern as
`recommend-rules` for community rule packs — see
[docs/architecture.md](../../../docs/architecture.md).

| File | Companion | Goes into |
| ---- | --------- | --------- |
| `graphify.md` | graphify | project `AGENTS.md` (agent-agnostic rules block) |
| `graphifyignore` | graphify | project `.graphifyignore` (root) — copied verbatim, skip-if-present |
| `caveman.md` | caveman | project `AGENTS.md` (mode note + how to toggle) |
| `llm-wiki/` | llm-wiki | project `wiki/` + `raw/` skeleton + `AGENTS.md` pointer |

There is no `graphify-hook.json`. The "grep → query the graph instead" nudge is
not graphify-specific: `/ai:setup` Branch 2d wires
[`bin/hooks/search-delegation-check.sh`](../../../bin/hooks/search-delegation-check.sh)
into **every** project, and that hook switches to the graphify message on its own
once `graphify-out/graph.json` appears. One hook, not two overlapping ones.

Adding a new companion tool: drop its glue here and add a row to the table in
`workflow/skills/recommend-tools/SKILL.md`.
