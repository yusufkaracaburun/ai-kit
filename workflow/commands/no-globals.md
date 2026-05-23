---
description: Toggle the machine-wide "skip global checks" opt-out for ai-kit-doctor (on / off / status)
argument-hint: "on | off | status"
allowed-tools: Bash
---

Toggle the global-check opt-out for `ai-kit-doctor.sh`.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-no-globals.sh" $ARGUMENTS`

Confirm the new state for the user. Note that **per-project setup-mode wins** — a project explicitly using `solo-both` will still be checked for globals even when the opt-out is active. Use the opt-out for machines where you only ever work on `project-only` repos (e.g. ai-kit's own clone, or shared/containerised dev environments).
