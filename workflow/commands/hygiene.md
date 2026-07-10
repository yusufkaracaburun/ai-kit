---
description: One-shot hygiene/housekeeping for the current ai-kit project — runs doctor (install health), dedupe (duplicate skills/agents/rules), audit-setup-symmetry (catalog ↔ wiring), memory-audit (orphan/stale entries across .agents/memory/*/), repo-skill-hint (project-scoped hygiene skills like docs-sync), and context-lean (always-loaded CLAUDE.md/AGENTS.md over 200 lines). Always emits a `Score: N/100` install-quality grade with ranked "to reach 100" recipe. Reports only — never deletes.
argument-hint: "[path] [--skip-doctor|--skip-dedupe|--skip-symmetry|--skip-memory|--skip-repo-skills|--skip-context-lean]"
allowed-tools: Bash
---

Run `ai-kit-hygiene.sh` against the current project and surface findings from all six sections.

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
5. **repo-skill-hint** — list project-scoped skills under `.agents/skills/` whose name or description matches hygiene-style triggers (docs-sync, repo-hygiene, prune, cleanup, audit, etc.), AND surface the framework `/ai:docs-sync` when applicable (any markdown file, `docs/` dir, or >1 local branch). When both a project-local docs-sync skill AND `/ai:docs-sync` apply, both are listed side-by-side with a one-line "use which for what" hint — project skill handles repo-specific drift (vocabulary, ADR triggers, status tables), framework skill handles universal drift (dead links, repo-hygiene, finished-work cleanup). Skips silently when neither source has anything to surface.
6. **context-lean** — root `CLAUDE.md` / `AGENTS.md` are loaded at the start of every session (fixed token tax); WARN when either exceeds 200 lines. Fix by curating, not compressing: keep only what every session needs (build commands, non-obvious conventions, absolute rules) and move directory-specific notes to `<subdir>/CLAUDE.md`, stack conventions to path-scoped rules, and multi-step procedures to a skill. Skips silently when neither file exists at the project root.

End with the **score line** the script prints verbatim (`Score: N/100`) and — when below 100 — the ranked "To reach 100" recipe lines. Score rubric: start 100, each blocker section −20, each warning section −5, clean 0. Score is always emitted, even on a fully clean run; treat it as the canonical install-quality signal.

Then one line: max exit code + meaning (`0 clean / 1 warn / 2 block`).

Don't editorialise. Don't extend cleanup beyond what the scripts surfaced. Skip sections the user explicitly opted out via `--skip-*` flags.
