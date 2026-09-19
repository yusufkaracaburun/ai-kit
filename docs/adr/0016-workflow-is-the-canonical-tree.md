# ADR-0016: workflow/ holds the canonical trees; root dirs are symlinks

**Status:** Accepted (2026-09-19)

## Context

The Claude Code plugin loader needs a self-contained directory, and the
marketplace pins a tag, so `workflow/` has to carry everything a slash command
invokes: `bin/`, `standards/`, `context/`, `orchestration/`, `CHANGELOG.md`.
Since v5.0.0 that was done by committing byte-identical copies of the root
trees under `workflow/` and policing them with four `sync-plugin-*.sh` scripts,
`lib/sync-mirror.sh`, thirteen structure asserts and a `cp` in `release.sh`.
The 2026-09-19 audit measured the cost: 1.84 MB of tracked duplicates, every
hook in three committed copies, every `bin/` change carrying a mirror diff of
equal size, and a forgotten sync caught only at release or in CI.

## Decision

The canonical trees move into `workflow/`. The repo-root `bin/`, `standards/`,
`context/`, `orchestration/` and `CHANGELOG.md` become symlinks into
`workflow/`. Every existing path keeps working: `resolve_ai_kit_root` uses a
logical `cd ..; pwd`, so `bin/foo.sh` still resolves the repo root, and the
plugin path (`workflow/` as root) is unchanged. `sync-plugin-rules.sh`
(a real transform), `sync-plugin-hooks.sh` (a hand-picked subset) and
`sync-plugin-version.sh` (a stamp) stay.

## Alternatives

- Generate `workflow/` on the release tag only, gitignored on master. No
  duplicate bytes either, but CI has to build and commit on tag and a local
  plugin install from a checkout stops working. Rejected for the complexity.
- Keep the mirror. Rejected: the audit's structure score was the lowest
  dimension and this was the largest single item in it.

## Consequences

- Four sync scripts, five structure asserts and the changelog copy are gone.
- CI shellcheck scans `./workflow/bin` (the action's `find` does not follow
  the root symlink).
- `workflow/hooks/` is still a five-file copy of `bin/hooks/` plus
  `log-skill.sh`; making those symlinks would depend on the plugin cache
  preserving symlinks, which is unverified. Left as is.
