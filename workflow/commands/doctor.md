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

Common fixes to suggest by name:
- Missing global symlinks → `~/.local/share/ai-kit/bin/install-global.sh`
- Project not bootstrapped → `~/.local/share/ai-kit/bin/bootstrap-project.sh .`
- Want to skip global checks → `~/.local/share/ai-kit/bin/ai-kit-no-globals.sh on`
- ai-kit root not resolvable → `export AI_KIT_ROOT=/path/to/ai-kit`

Don't editorialise — just route the user to the right next command.
