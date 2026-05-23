---
description: Ranked list of highest-value open work for this project — GH issues + roadmap + setup-deferred branches, scored by P-label + status + freshness
argument-hint: "[--limit N] [--no-gh] [--no-roadmap] [--json]"
allowed-tools: Bash
---

Print the prioritized "what to do next" backlog for the current project. Combines three sources via `bin/ai-kit-next.sh`:

- Open GitHub issues (P0-P3 + status:in-progress + ready-for-agent labels)
- Open `- [ ]` tasks in `docs/roadmap.md` (or ROADMAP.md / .planning/roadmap.md)
- `.ai-kit-setup` deferred branches

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-next.sh" $ARGUMENTS`

Read the top item and propose the most appropriate next-step skill (see `next/SKILL.md` "When to use which next-step suggestion"). Do not auto-execute — the user picks.
