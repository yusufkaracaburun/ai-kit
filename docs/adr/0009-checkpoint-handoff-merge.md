# ADR 0009 — Merge `/ai:handoff` into `/ai:checkpoint`

**Status:** Accepted · **Date:** 2026-05-27 · **Issue:** #91

## Context

Two ai-kit skills compacted a session for resumption:

- `/ai:checkpoint` — writes to project auto-memory (`~/.claude/projects/<slug>/memory/project/session-checkpoint-*.md`); same-project, same-machine resume; pairs with `/ai:resume`. Carries the maturity features: stale-flag detection in `MEMORY.md`, self-check before confirming, docs-sync cross-cue, GSD-project routing.
- `/ai:handoff` — writes to `$TMPDIR/handoff-XXXXXX.md`; for cross-machine / cross-agent / cross-teammate transfer; includes redaction; has a `mid-session` mode.

Both triggered on the same language ("context getting full, before `/clear`, wrapping up"). Users had to remember which slash for which axis. The #88 grilling settled "checkpoint as docs-sync nudge carrier" by gut, not rule — a tell that the skills weren't separating cleanly.

## Decision

**Merge `/ai:handoff` into `/ai:checkpoint`.** One skill, one trigger, destination as an argument.

```
/ai:checkpoint [slug] [--to memory|tmp] [--mid-session]
```

- `--to memory` (default) — current checkpoint behaviour (resume-snapshot template, MEMORY.md index, stale-flag, self-check, docs-sync nudge, GSD-routing).
- `--to tmp` — current handoff behaviour (briefing template, `$TMPDIR/handoff-XXXXXX.md`, redaction always-on, skips MEMORY.md/nudge/GSD since the receiving context is not local).
- `--mid-session` — works with either target; prune in-place without `/clear`.

`/ai:handoff` becomes a deprecation stub for one release cycle, then is removed.

## Alternatives considered

- **Keep both, sharpen descriptions.** Solves trigger overlap by half. Leaves two skills, two mental models, ongoing user confusion. Rejected: trigger overlap is the actual pain.
- **Extract shared core helper, keep two thin wrappers.** Code-overlap turned out to be ~30 LOC (template scaffolds differ substantially). Extraction yields a maintenance cost > saving. Rejected.

## Consequences

**+**
- One slash, one mental model for "compact session".
- Maturity features (stale-flag, self-check, nudge, GSD-routing) profit both targets where applicable.
- Eliminates the trigger-overlap source named in #91.
- ~150 LOC removed (deprecation cycle complete).

**−**
- Existing `/ai:handoff` users learn a new slash. Mitigated by one-release deprecation alias with redirect message.
- Slightly larger checkpoint SKILL.md (one switch-block).

## Migration

- v1.35.0 — merge lands; `/ai:handoff` slash forwards to `/ai:checkpoint --to tmp`, prints deprecation notice.
- v1.36.0 — remove `/ai:handoff` entirely. Update `workflow/skills/onboard/`, `workflow/skills/resume/`, `standards/rules/context-discipline.mini.md` to drop the alias.
