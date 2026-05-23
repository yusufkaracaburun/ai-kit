---
description: Re-stamp the project's .ai-kit-setup marker to the current ai-kit VERSION (preserves branch choices)
argument-hint: "[path]"
allowed-tools: Bash
---

Refresh the project's `.ai-kit-setup` marker after pulling a new ai-kit version. Branch choices are preserved verbatim — only the version field changes.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-upgrade.sh" "${ARGUMENTS:-$(pwd)}"`

Confirm the marker version moved to the expected value. If the script fails with "No .ai-kit-setup", the project isn't bootstrapped — point the user at `bin/bootstrap-project.sh` and `/ai:setup` instead.
