---
description: Re-stamp the project's .ai-kit-setup marker to the current ai-kit VERSION (preserves branch choices)
argument-hint: "[path]"
allowed-tools: Bash
---

Refresh the project's `.ai-kit-setup` marker after pulling a new ai-kit version. Branch choices are preserved verbatim — only the version field changes.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-upgrade.sh" "${ARGUMENTS:-$(pwd)}"`

When the upgrade crosses one or more releases, the script also slices the relevant section out of `CHANGELOG.md` and prints it so the user sees what changed between their previous marker version and the new one. The slice is reverse-chronological (newest first), trimmed to releases strictly newer than the old version.

Confirm the marker version moved to the expected value (`jq -r .ai_kit_version .ai-kit-setup`). If the script fails with "No .ai-kit-setup", the project isn't bootstrapped — point the user at `bin/bootstrap-project.sh` and `/ai:setup` instead. If it fails with "marker is newer than the running kit", this session still runs an older plugin: tell the user to restart the session, do not retry.
