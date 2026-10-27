# Onboarding — ai-kit

**Audience:** new contributor or agent (full-stack generic).
**Last refreshed:** 2026-10-27

## 1. What this project is

ai-kit is the agile lifecycle expressed as Claude Code + Cursor primitives.
Stack-agnostic. Pure Bash + Markdown. One canonical source emits skills,
slash commands and rules to both hosts, and subagents and hooks to Claude
Code. No per-host duplication, no runtime daemon, no network calls, no telemetry.

Today (v2.12.0): **35 skills · 6 subagents · 11 slash commands · 10 plugin-wired hooks ·
46 canonical mini-rules · 24 curated MCP servers · 28 curated hook recipes ·
23 curated plugins · 5 baseline repo templates.**

## 2. How to run it locally

```bash
git clone git@github.com:yusufkaracaburun/ai-kit.git
cd ai-kit
./tests/bin/run-all.sh          # full suite, parallel (JOBS=4 default)
./tests/bin/eval-structure.sh   # SKILL.md structural checks
shellcheck bin/**/*.sh tests/bin/*.sh
```

No build step. Pure Bash + Markdown. macOS and Linux (Bash 4+).

Install into another repo (dogfood):

```text
/plugin marketplace add yusufkaracaburun/marketplace
/plugin install ai@yusufkaracaburun
```

Or the curl path for non-Claude-Code hosts:

```bash
curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
```

## 3. The shape of the codebase

- `workflow/` — the canonical primitives that ship to hosts.
  - `skills/<name>/SKILL.md` (35) · `agents/<name>.md` (6) ·
    `commands/<name>.md` (11) · `hooks/` (10 hooks + `hooks.json`) ·
    `.claude-plugin/plugin.json` (manifest).
- `standards/rules/` — agent-agnostic mini-rules; `bin/emit-rules.sh`
  fans them out to per-host conventions.
- `bin/` — Bash scripts the skills/commands shell out to. `bin/lib/` for
  shared helpers. The repo-root `bin/` is a symlink to `workflow/bin/`
  (ADR-0016), so the plugin install is self-contained.
- `context/templates/` — drop-in templates (repo hygiene + agent docs).
- `tests/bin/` — harness (`run-all.sh`, `lib/harness.sh`) and case files
  (`cases/<group>.sh`), plus the structural checker `eval-structure.sh`.
  `tests/eval/` — fixtures, goldens and results.
- `docs/` — architecture, mental-model, install-plugin, roadmap, ADRs.

See [docs/architecture.md](docs/architecture.md) for the full diagram.

## 4. Domain language (key terms)

- **Skill** — a `SKILL.md` invoked by name (e.g. `/ai:setup`). Lives in
  `workflow/skills/`.
- **Subagent** — a `workflow/agents/<name>.md` a skill can delegate to. 6 exist:
  `explore`, `reviewer`, `qa-runner`, `verifier`, `builder`, `designer`.
- **Slash command** — a `workflow/commands/<name>.md` resolving to a
  bash script. 11 exist (`ls workflow/commands/`).
- **Mini-rule** — agent-agnostic rule book under `standards/rules/`,
  emitted per host by `bin/emit-rules.sh`.
- **Marker** — `.ai-kit-setup` JSON written by `/ai:setup` to record
  which Tier B branches a project opted into.
- **Tier A / Tier B** — `/ai:setup` fast path (bootstrap + dev env) vs.
  optional extensions (docker, tracker, domain docs, etc.).

## 5. How we work

- **Branching:** direct-to-master for the maintainer (solo project).
  External contributors: `feat/<area>-<desc>` or `fix/<area>-<desc>`.
- **Commits:** Conventional Commits (`feat(scope): subject`).
- **CHANGELOG.md:** Keep a Changelog; every release entry under its
  version header.
- **Releases:** `bin/release.sh` commits the VERSION bump + CHANGELOG entry
  and tags `vX.Y.Z`. The marketplace pins `source.ref` to that tag;
  `--bump-marketplace` pushes and bumps it so downstream `/plugin update`
  picks it up.
- **Tests:** `./tests/bin/run-all.sh` must stay green.
  Count assertions in `structure.sh` and `release-install.sh` are the
  usual culprits when adding skills/commands/rules.
- **Eval fixtures:** every skill needs ≥1 fixture under
  `tests/eval/prompts/<skill>/` or `eval-structure.sh` fails.
- **Shellcheck:** zero warnings on `bin/**/*.sh tests/bin/*.sh`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full checklist.

## 6. Load-bearing decisions

- [ADR-0001](docs/adr/0001-setup-modes.md) — `/ai:setup` four-mode model
  (solo-both / solo-global / project-only / brownfield). Superseded by
  [ADR-0012](docs/adr/0012-setup-mode-decomposition.md).
- [ADR-0002](docs/adr/0002-skill-eval-approach.md) — fixtures + golden
  responses + structural checks as the evaluation triangle.
- [ADR-0003](docs/adr/0003-merge-security-audit-into-review.md) — single
  `/ai:review` instead of a separate security skill.
- [ADR-0004](docs/adr/0004-aikit-skill-prefix.md) — `aikit-` skill prefix
  to avoid collisions. Superseded: the plugin namespace gives `/ai:*`.
- [ADR-0005](docs/adr/0005-monorepo-boost-context-drift.md) — monorepo
  + Laravel Boost handling in `/ai:setup`.
- [ADR-0006](docs/adr/0006-scope-claude-code-cursor-only.md) — drop
  Aider/Cline/Continue/Cody emitters; Claude Code + Cursor only.

Read these before proposing structural changes.

## 7. Surface area for first contribution

- **Add a curated MCP / hook / plugin** — edit the matching JSON under
  `standards/external/` (`mcp-servers.json`, `hooks-patterns.json`,
  `plugins.json`) and re-run `tests/bin/cases/recommend.sh`.
  Lowest-risk way to learn the project layout.
- **Add a stack-specific mini-rule** — drop a new `*.mini.md` under
  `standards/rules/`, set `universal: false` + `applies_to:` and `paths:` frontmatter,
  re-run `tests/bin/cases/bootstrap-emit.sh`.
- **Add a starter skill** — copy an existing `workflow/skills/<x>/SKILL.md`
  as template, add a fixture under `tests/eval/prompts/<new>/`, bump
  the skill count in `structure.sh` + `release-install.sh`, then fix every
  doc site `bin/count-primitives.sh --check` reports.
- **Fix an open `good-first-issue`** — `gh issue list --label good-first-issue`.

## 8. Footguns

- **Skill count drift.** Adding a skill without bumping the counts breaks
  `structure.sh`; `bin/count-primitives.sh --check` lists every doc site.
- **`workflow/hooks/` is a copy.** Edit `bin/hooks/` and run
  `bash bin/sync-plugin-hooks.sh`; its `--check` mode catches drift.
- **Marker JSON.** `bin/write-setup-marker.sh` only writes fields that
  were passed — never silently defaults. If your new Tier B branch
  doesn't show up in `.ai-kit-setup`, you forgot the `--<branch>=...`
  flag in the skill's Done step.
- **Fixture required.** New skill without a `tests/eval/prompts/<name>/`
  fixture fails `eval-structure.sh` even when `run-all.sh` passes
  case-by-case.
- **Pre-write checklist (CLAUDE.md).** Score 4/4 (assumptions / minimum /
  surgical / verifiable) before the first Edit on changes ≥10 LOC. The
  project bias is caution over speed.

## 9. Where to ask

- GitHub Issues: <https://github.com/yusufkaracaburun/ai-kit/issues>
- Maintainer: info@emeq.nl
- Solo project — expect async, weekday response.

## 10. Suggested next skill

After reading this, run:

- `/ai:setup` — wire ai-kit into a new project (Tier A is ~5 min).
- `/ai:doctor` — verify the install end-to-end before opening a PR.
- `/ai:next` — pick the first issue from the prioritised backlog.
- `/ai:grill-me` — if anything in this guide is still ambiguous.
