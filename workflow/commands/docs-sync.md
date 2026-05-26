---
description: One-shot content-drift check for the current project — dead markdown links (v1), repo-hygiene + finished-work cleanup (follow-up issues). Standalone counterpart to /ai:hygiene; never auto-edits files. Reports findings, exits 0 (clean) or 1 (findings).
argument-hint: "[path] [--skip-dead-links] [--no-prompt]"
allowed-tools: Bash
---

Run `ai-kit-docs-sync.sh` against the current project and summarise findings section by section.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-docs-sync.sh" $ARGUMENTS`

For each section the script prints, surface:

1. **dead-links** — every broken link with `file:line` + the offending `[text](target)` + the missing resolved path. For each finding, suggest the manual fix: open the file at that line and either repoint the link or delete the reference. Never propose an automated edit — `/ai:docs-sync` is deliberately read-only against markdown content.

End with the driver's summary line (`docs-sync: all sections clean.` / `docs-sync: findings reported (exit 1).`).

Don't editorialise. Don't extend cleanup beyond what the script surfaced. When stdin is a TTY and the user wants per-finding fix suggestions, the script will prompt; under `--no-prompt` (or in non-interactive contexts) the report is the complete output.

The skill is intentionally narrow — see the `## Non-goals` section in the SKILL.md for what `/ai:docs-sync` will never do. If a project needs repo-specific drift checks (ADR triggers, persona names, status tables, structure conventions), that belongs in a project-local `/docs-sync` skill, not here.
