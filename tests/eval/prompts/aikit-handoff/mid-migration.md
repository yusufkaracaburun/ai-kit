---
id: mid-migration
skill: aikit-handoff
expects:
  - lists concrete next steps the picking-up agent can act on directly
  - identifies open blockers or unresolved decisions, not just status
  - names specific files / branches / commits the next agent should look at
  - does NOT regurgitate the diff or commit log verbatim
  - includes how to resume the conversation thread (what to ask the user first)
---

# Prompt

I'm 4 hours into migrating the orders module from raw SQL to the new query
builder. Three files done, two tests still failing in `orders.test.ts`
because of a timezone issue I haven't tracked down. I need to stop. Write a
handoff for tomorrow.
