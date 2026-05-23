---
id: brownfield-graphify
skill: recommend-tools
expects:
  - detects whether the graphify CLI and caveman skills are already present before recommending (command -v / dir checks)
  - judges fit against this repo — graphify recommended for a large brownfield repo, with a one-line why
  - treats caveman as opt-in only, never enabled by default — flags it as a communication mode
  - wires only what the user picks, from context/templates/companions/ — never vendors graphify or caveman source into the repo
  - for graphify, appends the AGENTS.md rules block and merges the PreToolUse hook into .claude/settings.json without clobbering existing hooks
  - if a tool's CLI/skills are missing, surfaces the upstream install pointer — never auto-installs
  - ends with an explicit wired / needs-install / deferred breakdown
  - does NOT claim a tool is wired without its glue on disk
---

# Prompt

We just ran `/ai:setup` on emeq/admin — a five-year-old Laravel admin panel with
hundreds of files. I grep around it constantly and the agent burns tokens
re-reading the same code. Are there companion tools worth adding to push this
setup further, and which actually fit a repo this size?
