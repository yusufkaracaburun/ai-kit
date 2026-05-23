---
id: whats-open
skill: next
expects:
  - invokes bin/ai-kit-next.sh (or equivalent) — does NOT hand-walk gh + roadmap
  - reads top item before suggesting a next-step skill
  - if top item has status:in-progress → suggests continuing the WIP, NOT starting new work
  - if top item has ready-for-agent → suggests /ai:autonomous (queue drain)
  - if top item is roadmap-only → suggests /ai:to-prd defer to open a GH issue first
  - if top item is setup-deferred → suggests re-running /ai:setup to revisit that branch
  - does NOT auto-execute the suggested next skill — user picks
---

# Prompt

Wat is op dit moment de hoogste prioriteit binnen dit project? Geef me een
korte ranked lijst en wijs aan welk volgend skill ik zou moeten draaien.

# Expected behaviour

The agent should:

1. Call `bin/ai-kit-next.sh` (or `/ai:next` if the plugin is loaded).
2. Read the top item from the printed output.
3. Pick a next-step skill from the table in `next/SKILL.md` "When to use
   which next-step suggestion" — explain *why* this item is top, and which
   skill addresses it.
4. Stop there. Do not start the suggested skill.
