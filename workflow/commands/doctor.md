---
description: Run the ai-kit doctor (install health check) and summarise blockers + fixes
argument-hint: "[path] [--project-only|--check-global]"
allowed-tools: Bash
---

Run `ai-kit-doctor.sh` against the current project and surface its findings.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-doctor.sh" $ARGUMENTS`

Summarise the output for the user:

1. **Blockers first** (exit code 2) — for each, name the exact fix command.
2. **Warnings next** (exit code 1).
3. **All-clear last** (exit code 0) — single line: "ai-kit install is healthy."

Common fixes to suggest by name (the doctor prints the exact command per finding — repeat it verbatim):
- Hook not wired → `bash "${CLAUDE_PLUGIN_ROOT}/bin/apply-<name>-hook.sh" .`
- Marker version behind → `/ai:upgrade`
- Project not set up → `/ai:setup`
- Want to skip global checks → `/ai:no-globals on`

Don't editorialise — just route the user to the right next command.
