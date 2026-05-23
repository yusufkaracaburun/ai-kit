# Changelog

## 1.3.0 — 2026-05-23

Add duplication detection for safer plugin updates.

- **New slash command** `/ai:dedupe` — scans four surfaces and reports
  duplicates/orphans without ever deleting:
  1. Personal skills (`~/.claude/skills/`) shadowing plugin skills.
  2. Personal agents (`~/.claude/agents/`) shadowing plugin agents.
  3. Orphan emitted rules (`.cursor/rules/ai-kit-*.mdc`) whose canonical
     source no longer exists in the plugin (stale after rule rename/removal).
  4. Hook overlap in project `.claude/settings.json`.
- **New bin script** `bin/ai-kit-dedupe.sh` — supports `--json` and `--fix`
  (prints suggested `rm` commands, never executes). Exit 0 = clean, 1 = dups.
  Mirrored to `workflow/bin/` so it ships in the plugin.

Motivation: every `/plugin update` risks personal-skill shadowing and orphan
emitted rules accumulating silently. `/ai:dedupe` surfaces them on demand
without auto-deleting anything — user always reviews the cleanup commands
before running them.

Shipping surface at v1.3.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (was 7) — adds `/ai:dedupe`
- 10 canonical rules (unchanged)

## 1.2.0 — 2026-05-23

Codify "grill before plan" — prevent agents from jumping straight to plan
or implementation when handed an issue/PRD/spec that *looks* complete.

- **New rule** `grill-first.mini.md` (`standards/rules/`) — universal, high
  weight. Specifies when the grill gate fires, the minimum question set
  (scope split, detection logic, override pattern, bundle-vs-defer, data
  contract), routing to `grill-with-docs` vs `grill-me`, and when to skip.
- **Skill update** `to-issues` — inserts a 1.5 Grill-first gate between
  "Gather context" and "Explore the codebase", with explicit reference to
  the new rule.
- **Skill update** `tdd` — adds grill-first as a precondition before the
  first failing test, alongside the existing `context-discipline` link.

Motivation: Issue bodies, PRDs, and memory anchors look deterministic but
are almost always under-specified. Discovering that mid-plan = wasted
context. Discovering it pre-plan = cheap. Prevention beats cure.

Shipping surface at v1.2.0:

- 24 skills (unchanged; 2 edited)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 10 canonical rules (was 9) under `standards/rules/`

## 1.1.0 — 2026-05-23

Surface expansion from personal `~/.claude/` companions.

- **New skill** `should-i-use` (`workflow/skills/should-i-use/`) — structured
  vendor / wire / adopt / ignore verdict for any candidate tool, repo, URL, or
  pasted artifact. Critical-advisor variant of `/ai:triage` for inbound tooling.
- **New rule** `context7.mini.md` (`standards/rules/`) — canonical
  ctx7 CLI usage guidance. Pairs with the existing `context7` MCP entry in
  `standards/external/mcp-servers.json` to close the docs-lookup loop.

Shipping surface at v1.1.0:

- 24 skills (was 23)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 9 canonical rules (was 8) under `standards/rules/`

## 1.0.0 — 2026-05-23

Initial release after version-history reset. Prior tags (v1.0.0–v5.0.2)
were deleted from origin on 2026-05-23 to consolidate the rapid pre-1.0
churn that accumulated during the May 2026 primitive-expansion + plugin
distribution work. Git history of `master` is preserved — only version
tags + this CHANGELOG were reset.

Current shipping surface at v1.0.0:

- 23 skills (workflow/skills/)
- 3 subagents (workflow/agents/)
- 7 slash commands (workflow/commands/)
- Self-contained Claude Code plugin distribution (workflow/bin/, workflow/hooks/)
- Cursor + Claude Code rule emitters (bin/lib/emitters/{cursor,claude-code,generic}.sh)
- 387-test regression suite
