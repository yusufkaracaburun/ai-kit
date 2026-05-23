---
description: Pick the right ai-kit skill for what you're trying to do (deterministic keyword match — no LLM scoring)
argument-hint: "<intent in quotes> | --list | --explain <skill>"
allowed-tools: Bash
---

Route the user to the best-matching ai-kit skill via `ai-kit-which.sh`.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-which.sh" $ARGUMENTS`

If the script returns top matches, briefly explain to the user *why* the top hit fits — pull the rationale from the matched skill's description. If the user's intent doesn't match any skill, suggest `--list` and the closest 1-2 skills by topic.

Don't run the chosen skill — just point at it. Let the user trigger it explicitly so the right context loads.
