# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/dynamic/regex?label=version&url=https%3A%2F%2Fraw.githubusercontent.com%2Fyusufkaracaburun%2Fai-kit%2Fmaster%2FVERSION&pattern=%5E(.%2B)%24)](VERSION)

Personal agent kit — **stack-agnostic**, full **agile lifecycle**, Claude Code + Cursor.

**Version:** see [VERSION](VERSION) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Quick start

**Usual flow:** paste the [project setup prompt](context/prompts/setup-project.md). Default is **Tier A (~5 min)**: one setup-mode question, bootstrap, dev-environment.

| Setup mode | When |
| ---------- | ---- |
| solo-both | Greenfield default — global + project merge-skills |
| solo-global | Machine-wide skills only |
| project-only | Project skills only |
| brownfield | Existing rules/MCP/custom skills — documents coexistence |

**ai-kit root** is resolved automatically (no hardcoded path):

1. `$AI_KIT_ROOT` environment variable
2. `~/.config/ai-kit/root` (written by `install-global.sh`)
3. Script location when run from the ai-kit clone

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"

# 1. Install skills globally (once)
$AI_KIT_ROOT/bin/install-global.sh

# 2. Open any project and run /setup (or paste the setup prompt)
/setup
```

New machine? See [install-global prompt](context/prompts/install-global.md).

## Agile lifecycle

| Fase | Skills |
| ---- | ------ |
| Ideation | `grill-me`, `grill-with-docs`, `to-prd`, `prototype`, `zoom-out` |
| Development | `to-issues` → `triage` → `tdd` |
| Testing | `review`, `qa`, `diagnose` |
| Deployment | `ship` |
| Ops & Review | `retro` |

Framework (Scrum/Kanban): optional via Full setup → `docs/agents/workflow.md`. Architecture: optional branch 7 in Full setup.

## Cross-tool setup

| Tool | Global skills | Project skills |
| ---- | ------------- | -------------- |
| Claude Code | `~/.agents/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.cursor/skills/` |

Bootstrap symlinks both project paths. `ai-kit.mdc` rule points agents to `AGENTS.md`.

## Structure

```
workflow/skills/   16 skills incl. setup, ship, retro
standards/rules/   Book rules (on-demand)
orchestration/     Sandcastle templates
context/templates/ Per-project doc templates
context/prompts/   Copy-paste agent prompts (setup)
bin/               Scripts invoked by /setup
.github/workflows/ CI test workflow
tests/bin/         Script regression tests
docs/              Dogfood and internal notes
```

## Setup automation

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/detect-tooling.sh .          # what is in this repo?
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal  # Tier A done
$AI_KIT_ROOT/bin/ai-kit-root.sh               # print resolved root
```

## Tests

```bash
./tests/bin/run-tests.sh    # from ai-kit clone
```

CI runs the same suite on push/PR (`.github/workflows/test.yml`).

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for the expanded list. Quick hits:

| Issue | First thing to try |
| ----- | ------------------ |
| `/setup` not found | Re-run `install-global.sh`; verify the two `setup` symlinks |
| ai-kit root unknown | Set `AI_KIT_ROOT` or run `install-global.sh` once |
| Skills missing in Cursor | Reload the window, check `.cursor/skills` resolves |
| Sandcastle placeholder leaked | Edit `.sandcastle/main.mts` install line manually |
| Re-configure project | `/setup` again (keep/change/skip per branch) or `rm .ai-kit-setup` |
| Brownfield rule "lost" | Use `--merge-skills` (default), not `--link-all` |
| Usage log empty | `export AI_KIT_USAGE=1` and open a new shell |

## What ai-kit logs locally (opt-in)

When `AI_KIT_USAGE=1` is set, each invocation of a skill writes one line to
`${XDG_STATE_HOME:-~/.local/state}/ai-kit/usage.jsonl`:

```
{"ts":"2026-05-20T17:14:03Z","skill":"diagnose","event":"start","project":"ai-kit","cwd_hash":"a1b2c3d4e5f6"}
```

Fields: `ts`, `skill`, `event` (`start|done|abort`), `project` (basename of the git root or cwd), `cwd_hash` (sha1 of the absolute path). **Never** the absolute path, prompt contents, file contents, branch names, or anything else. No network calls — CI greps for `curl|wget|/dev/tcp|nc` in the usage scripts to enforce this.

```bash
bin/usage-stats.sh --since=7d        # human report
bin/usage-stats.sh --json            # machine-readable
bin/usage-purge.sh                   # wipe the log
```

`retro` reads `usage-stats.sh` to ground the conversation in observed behaviour. See [SECURITY.md](SECURITY.md) for the full data contract.

## Eval harness

```bash
./tests/bin/eval-structure.sh        # 8 deterministic SKILL.md checks + fixture lint
./bin/eval-skill.sh diagnose         # dump prompt + SKILL.md + rating template for manual rating
```

Fixtures live in `tests/eval/prompts/<skill>/<scenario>.md`. Rating notes go to `tests/eval/results/` (gitignored). See [docs/eval.md](docs/eval.md).

## License & Provenance

ai-kit is licensed [MIT](LICENSE). It incorporates work from the following MIT-licensed upstreams:

| Upstream | What we took |
| -------- | ------------ |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Workflow skills |
| [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) | Book mini rules |
| [mattpocock/sandcastle](https://github.com/mattpocock/sandcastle) | Sandcastle templates |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Concepts → review, qa, ship |

## Where facts live

- Domain → `CONTEXT.md` · Decisions → `docs/adr/` · Agent config → `docs/agents/`
- Setup state → `.ai-kit-setup` · Commands → official docs via `dev-environment.md`
