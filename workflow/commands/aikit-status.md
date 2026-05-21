---
description: One-screen status of the current project's ai-kit install (version, marker, setup mode, drift)
argument-hint: "[path]"
allowed-tools: Bash
---

Show ai-kit status for the project.

!`bash "${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}/bin/ai-kit-status.sh" $ARGUMENTS`

Read the output and answer for the user:

- Is the project bootstrapped? (presence of `.ai-kit-setup` marker)
- Setup mode in use? (`solo-both`, `solo-global`, `project-only`, `brownfield`)
- Marker version vs current ai-kit `VERSION` — drift?
- Skills/agents/commands linked correctly?

If drift exists, point at `ai-kit-upgrade.sh` (or `/aikit-upgrade` if available) to re-stamp the marker. If not bootstrapped, point at `bin/bootstrap-project.sh .`.
