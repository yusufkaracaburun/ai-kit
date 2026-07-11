---
id: brownfield-graphify
skill: recommend-tools
expects:
  - detects whether the graphify CLI and caveman skills are already present before recommending (command -v / dir checks)
  - judges fit against this repo — graphify recommended for a large brownfield repo, with a one-line why
  - checks the .ai-kit-setup marker for caveman in branches.universal_companions_prompted before offering it — /ai:setup Branch 2e auto-prompts it, so does not re-ask when already recorded
  - never enables caveman silently; whenever it IS offered, states that activation is machine-wide (changes the agent's output style in every repo on the machine)
  - wires only what the user picks, from context/templates/companions/ — never vendors graphify or caveman source into the repo
  - for graphify, appends the AGENTS.md rules block and copies .graphifyignore; does NOT wire a graphify-specific PreToolUse hook — /ai:setup Branch 2d already installed search-delegation-check.sh, which emits the graphify nudge once graphify-out/graph.json exists
  - if a tool's CLI/skills are missing, surfaces the upstream install pointer — never auto-installs without an explicit yes
  - ends with an explicit wired / needs-install / deferred breakdown
  - does NOT claim a tool is wired without its glue on disk
---

# Prompt

We just ran `/ai:setup` on emeq/admin — a five-year-old Laravel admin panel with
hundreds of files. I grep around it constantly and the agent burns tokens
re-reading the same code. Are there companion tools worth adding to push this
setup further, and which actually fit a repo this size?
