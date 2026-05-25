---
description: One-shot hygiene/housekeeping for the current ai-kit project — runs doctor (install health), dedupe (duplicate skills/agents/rules), and audit-setup-symmetry (catalog ↔ wiring). Reports only — never deletes.
argument-hint: "[path] [--skip-doctor|--skip-dedupe|--skip-symmetry]"
allowed-tools: Bash
---

Run `ai-kit-hygiene.sh` against the current project and surface findings from all three sections.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-hygiene.sh" $ARGUMENTS`

Summarise the output for the user, section by section:

1. **doctor** — blockers (exit 2) first with exact fix command, then warnings (exit 1), then all-clear. Common fixes:
   - Missing global symlinks → `~/.local/share/ai-kit/bin/install-global.sh`
   - Project not bootstrapped → `~/.local/share/ai-kit/bin/bootstrap-project.sh .`
   - Plugin manifest version drift → `bin/sync-plugin-version.sh`
   - `.ai-kit-setup` absent → `/ai:setup`
2. **dedupe** — list each `DUP` / `ORPHAN` plainly; ecosystem-audit divergences route to `/ai:dedupe` for full per-item table + `--fix` cleanup recipe. Never auto-run deletes.
3. **audit-setup-symmetry** — list any unwired catalogs; suggest adding either a scorer entry or a dedicated setup branch.

End with one line: max exit code + meaning (`0 clean / 1 warn / 2 block`).

Don't editorialise. Don't extend cleanup beyond what the scripts surfaced. Skip sections the user explicitly opted out via `--skip-*` flags.
