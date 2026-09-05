# Onboarding — ai-kit

**Audience:** new contributor or agent (full-stack generic).
**Last refreshed:** 2026-05-23

## 1. What this project is

ai-kit is the agile lifecycle expressed as Claude Code + Cursor primitives.
Stack-agnostic. Pure Bash + Markdown. One canonical source emits skills,
subagents, slash commands, hooks, and rules to both hosts — no per-host
duplication, no runtime daemon, no network calls, no telemetry.

Today (v1.39.0): **43 skills · 3 subagents · 11 slash commands · 2 hooks ·
41 canonical mini-rules · 21 curated MCP servers · 25 curated hook recipes ·
12 curated plugins · 5 baseline repo templates.**

## 2. How to run it locally

```bash
git clone git@github.com:yusufkaracaburun/ai-kit.git
cd ai-kit
./tests/bin/run-all.sh          # 408 tests, ~90s wall (JOBS=4)
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
  - `skills/<name>/SKILL.md` (27) · `agents/<name>/AGENT.md` (3) ·
    `commands/<name>.md` (8) · `hooks/` (2) ·
    `.claude-plugin/plugin.json` (manifest).
- `standards/rules/` — agent-agnostic mini-rules; `bin/emit-rules.sh`
  fans them out to per-host conventions.
- `bin/` — Bash scripts the skills/commands shell out to. `bin/lib/` for
  shared helpers. Mirrored to `workflow/bin/` by `bin/sync-plugin-bin.sh`
  so the plugin install is self-contained.
- `context/templates/` — drop-in templates (repo hygiene + agent docs).
- `tests/bin/` — harness (`run-all.sh`, `lib/harness.sh`) and case files
  (`cases/<group>.sh`). `tests/eval/` — fixtures + structural checker.
- `docs/` — architecture, mental-model, install-plugin, roadmap, ADRs.

See [docs/architecture.md](docs/architecture.md) for the full diagram.

## 4. Domain language (key terms)

- **Skill** — a `SKILL.md` invoked by name (e.g. `/ai:setup`). Lives in
  `workflow/skills/`.
- **Subagent** — an `AGENT.md` a skill can delegate to. Three exist:
  `explore`, `reviewer`, `qa-runner`.
- **Slash command** — a `workflow/commands/<name>.md` resolving to a
  bash script. Eight exist (`doctor`, `which`, `status`, `no-globals`,
  `upgrade`, `next`, `dedupe`, `prefer-plugin`).
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
- **Releases:** VERSION bump + `vX.Y.Z` tag + `git push --tags` in one
  commit. Marketplace ref is pinned to `master` so downstream
  `/plugin update` picks up new tags automatically.
- **Tests:** `./tests/bin/run-all.sh` must stay green (408 currently).
  Count assertions in `structure.sh` and `release-install.sh` are the
  usual culprits when adding skills/commands/rules.
- **Eval fixtures:** every skill needs ≥1 fixture under
  `tests/eval/prompts/<skill>/` or `eval-structure.sh` fails.
- **Shellcheck:** zero warnings on `bin/**/*.sh tests/bin/*.sh`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full checklist.

## 6. Load-bearing decisions

- [ADR-0001](docs/adr/0001-setup-modes.md) — `/ai:setup` four-mode model
  (solo-both / solo-global / project-only / brownfield).
- [ADR-0002](docs/adr/0002-skill-eval-approach.md) — fixtures + golden
  responses + structural checks as the evaluation triangle.
- [ADR-0003](docs/adr/0003-merge-security-audit-into-review.md) — single
  `/ai:review` instead of a separate security skill.
- [ADR-0004](docs/adr/0004-aikit-skill-prefix.md) — `/ai:*` namespace to
  avoid collisions with host-bundled skills.
- [ADR-0005](docs/adr/0005-monorepo-boost-context-drift.md) — monorepo
  + Laravel Boost handling in `/ai:setup`.
- [ADR-0006](docs/adr/0006-scope-claude-code-cursor-only.md) — drop
  Aider/Cline/Continue/Cody emitters; Claude Code + Cursor only.

Read these before proposing structural changes.

## 7. Surface area for first contribution

- **Add a curated MCP / hook / plugin** — edit the matching JSON under
  `context/recommendations/` and re-run `tests/bin/cases/recommend.sh`.
  Lowest-risk way to learn the project layout.
- **Add a stack-specific mini-rule** — drop a new `*.mini.md` under
  `standards/rules/`, set `universal: false` + `stack:` frontmatter,
  re-run `tests/bin/cases/bootstrap-emit.sh`.
- **Add a starter skill** — copy an existing `workflow/skills/<x>/SKILL.md`
  as template, add a fixture under `tests/eval/prompts/<new>/`, bump
  the skill count in `structure.sh` + `release-install.sh` + README +
  `plugin.json` description + `docs/{architecture,mental-model,install-plugin}.md`.
- **Fix an open `good-first-issue`** — `gh issue list --label good-first-issue`.

## 8. Footguns

- **Skill count drift.** Adding a skill without bumping all five count
  sites breaks `structure.sh`. The CHANGELOG of v1.10.2 lists every site.
- **`workflow/bin/` is a mirror.** Edit `bin/` and run
  `bash bin/sync-plugin-bin.sh`; the `--check` mode is gated in CI.
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
