# Contributing to ai-kit

Thanks for your interest. ai-kit is a personal agent kit; contributions stay small, focused, and review-friendly.

## Quick checklist

- [ ] Branch from `master`: `feat/<area>-<short-desc>` or `fix/<area>-<short-desc>`
- [ ] Commit style: imperative + scope (e.g. `feat(setup): add tier-A fast path`)
- [ ] `./tests/bin/run-tests.sh` passes locally
- [ ] If you touched any `workflow/skills/*/SKILL.md`: `./tests/bin/eval-structure.sh` passes
- [ ] If you touched a SKILL.md with a paired subagent (a generated region in `workflow/agents/*/AGENT.md`): re-run `./bin/emit-agents.sh`
- [ ] CHANGELOG.md updated under the unreleased section
- [ ] No secrets, no absolute user paths committed

## Local workflow

```bash
git clone git@github.com:yusufkaracaburun/ai-kit.git
cd ai-kit
./tests/bin/run-tests.sh
```

No build step. Pure Bash + Markdown. macOS and Linux supported (Bash 4+).

## Adding a new skill

Skills live in `workflow/skills/<name>/SKILL.md`. Each SKILL.md must:

1. Open with YAML frontmatter containing `name:` and `description:`.
2. Have `name` matching the directory name.
3. Have a single-line `description` between 30 and 500 characters, including a trigger phrase like "Use when …".
4. Contain at least one `## Process` or `## Phase` heading with the actual procedure.
5. Resolve every relative `.md` link on disk.
6. Use spaces, not tabs. LF line endings.

These rules are enforced by `tests/bin/eval-structure.sh`. If your skill warrants depth, add sibling `.md` files (e.g. `DEEPENING.md`) and link them from SKILL.md.

For high-signal skills, also add at least one fixture under `tests/eval/prompts/<skill>/<scenario>.md` with an `expects[]` rubric so future edits can be evaluated.

## Modifying bash scripts

- Run `shellcheck bin/**/*.sh tests/bin/*.sh` before pushing — CI enforces zero warnings.
- Source `bin/lib/ai-kit-root.sh` to resolve `AI_KIT_ROOT` portably; never hardcode paths.
- New tests go in `tests/bin/run-tests.sh` using the existing `assert "name" 'condition'` helper.

## Pull requests

Open against `master`. Use the PR template. Keep PRs ≤ 400 lines of diff where possible — split if larger.

**Approval policy**: solo maintainer project — author may self-merge once CI is green and `./tests/bin/run-tests.sh` + `shellcheck` pass locally. External contributors: one maintainer approval required before merge.

**Merge strategy**: **squash + merge**. The squash commit subject must follow Conventional Commits (`feat(scope): subject`). Avoid plain merge commits unless preserving multiple intentional commits is the explicit point of the PR.

The full set of branch/commit/PR conventions lives in [`standards/rules/git-hygiene.mini.md`](standards/rules/git-hygiene.mini.md) — that file is the source of truth used by `/ai:ship`, `/ai:to-issues`, and other agent skills.

## Releases

Maintainers only. `VERSION` + tag + GitHub release in one commit; CHANGELOG.md follows Keep a Changelog conventions.
