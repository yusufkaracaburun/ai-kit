---
description: One-shot hygiene/housekeeping for the current ai-kit project — runs doctor (install health), dedupe (duplicate skills/agents/rules), audit-setup-symmetry (catalog ↔ wiring), memory-audit (orphan/stale entries across .agents/memory/*/), and repo-skill-hint (project-scoped hygiene skills like docs-sync). Reports only — never deletes.
argument-hint: "[path] [--skip-doctor|--skip-dedupe|--skip-symmetry|--skip-memory|--skip-repo-skills]"
allowed-tools: Bash
---

Run `ai-kit-hygiene.sh` against the current project and surface findings from all five sections.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-hygiene.sh" $ARGUMENTS`

Summarise the output for the user, section by section:

1. **doctor** — blockers (exit 2) first with exact fix command, then warnings (exit 1), then all-clear. Common fixes:
   - Missing global symlinks → `~/.local/share/ai-kit/bin/install-global.sh`
   - Project not bootstrapped → `~/.local/share/ai-kit/bin/bootstrap-project.sh .`
   - Plugin manifest version drift → `bin/sync-plugin-version.sh`
   - `.ai-kit-setup` absent → `/ai:setup`
2. **dedupe** — list each `DUP` / `ORPHAN` plainly; ecosystem-audit divergences route to `/ai:dedupe` for full per-item table + `--fix` cleanup recipe. Never auto-run deletes.
3. **audit-setup-symmetry** — list any unwired catalogs; suggest adding either a scorer entry or a dedicated setup branch.
4. **memory-audit** — list ORPHAN entries (memory files not indexed in `.agents/memory/MEMORY.md`) and STALE entries (>90d untouched + 0 refs) across every typed subdir of `.agents/memory/` (typically `feedback/`, `reference/`, `decisions/`, `patterns/`, `project/`). README index files are ignored. Fix orphans by adding a bullet to MEMORY.md; resolve stale by refreshing content or archiving to `.agents/memory/archive/`. Skips silently when no `.agents/memory/` directory exists.
5. **repo-skill-hint** — list project-scoped skills under `.agents/skills/` whose name or description matches hygiene-style triggers (docs-sync, repo-hygiene, prune, cleanup, audit, etc.). These stay project-local — point the user at `/skill-name` rather than duplicating their content in ai-kit. Skips silently when the project has no `.agents/skills/` directory.

End with one line: max exit code + meaning (`0 clean / 1 warn / 2 block`).

Don't editorialise. Don't extend cleanup beyond what the scripts surfaced. Skip sections the user explicitly opted out via `--skip-*` flags.
