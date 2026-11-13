## Commands

- Test: `./tests/bin/run-all.sh`
- Skill-structure check: `./tests/bin/eval-structure.sh`
- Lint bash: `shellcheck bin/**/*.sh tests/bin/*.sh` (CI-enforced, zero warnings)
- Full conventions: [CONTRIBUTING.md](CONTRIBUTING.md)

## Architecture

- `bin/` — CLI scripts (ai-kit-*.sh: doctor, status, hygiene, dedupe, release.sh)
- `workflow/skills/<name>/SKILL.md` — skill sources, emitted to the plugin
- `workflow/agents/<name>.md` — paired subagents (generated region; re-run `bin/emit-agents.sh` after editing a SKILL.md with one)
- `tests/bin/` — test harness (`cases/`, `fixtures/`, `lib/`)
- `standards/rules/` — canonical rules (e.g. `git-hygiene.mini.md`, source of truth for `/ai:to-issues`)
- `docs/` — architecture docs, ADRs

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Review before release

Run `/ai:review` before a release, not after it. This repo has one committer,
so nothing else provides a second pass, and a reviewer starting from the diff
catches what the person who wrote it reads past.

## Working principles

The global `pre-write-discipline` and `quality-floor` rules apply; before the first Edit of a change ≥10 LOC, name which gates it passes.
