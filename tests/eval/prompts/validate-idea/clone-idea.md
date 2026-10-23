---
id: clone-idea
skill: validate-idea
expects:
  - spawns a research subagent with the fixed brief (market, competitors, incumbent, adjacent, international, legal, TAM/SAM/SOM)
  - every number carries a source URL or an (estimate) mark
  - spawns ai:verifier on the 5 numbers the verdict leans on and reports confirmed / refuted / unconfirmed per number
  - ends in exactly one exit (no-go, demand test, interview test, go)
  - any exit except no-go carries a measurable stop rule
  - writes <slug>.md and appends a row to ideas.md in $IDEAS_DIR
  - runs the competitor site inventory only on go
---

# Prompt

Toets dit idee: een kloon van rentslam.com voor Nederland, huur- en
koop-alerts per e-mail en Telegram, rond EUR 20 per maand. Heeft dit potentie?
