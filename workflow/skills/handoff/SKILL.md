---
name: handoff
description: "DEPRECATED in v1.35.0 — merged into /ai:checkpoint. Run `/ai:checkpoint --to tmp` for a transfer briefing in $TMPDIR (cross-machine, cross-agent, cross-teammate). Pass `--mid-session` to compact without /clear. This stub redirects and will be removed in v1.36.0."
argument-hint: "(deprecated — use /ai:checkpoint --to tmp)"
---

# DEPRECATED — use `/ai:checkpoint --to tmp`

`/ai:handoff` was merged into `/ai:checkpoint` in v1.35.0 (ADR-0009, #91).

## Redirect

| Old | New |
|-----|-----|
| `/ai:handoff` | `/ai:checkpoint --to tmp` |
| `/ai:handoff mid-session` | `/ai:checkpoint --to tmp --mid-session` |
| `/ai:handoff <focus>` | `/ai:checkpoint <focus-slug> --to tmp` |

The `--to tmp` path in `/ai:checkpoint` does everything the old handoff
did: writes a transfer briefing to `$TMPDIR/handoff-XXXXXX.md`, redacts
secrets/abs-paths/PII always-on, supports `--mid-session`.

The default `/ai:checkpoint --to memory` is the same-machine, same-project
resume path that pairs with `/ai:resume`.

See `docs/adr/0009-checkpoint-handoff-merge.md` for context.

## When this skill fires

Tell the user: "`/ai:handoff` is deprecated. Running `/ai:checkpoint --to
tmp` instead." Then invoke `/ai:checkpoint` with `--to tmp` and any
forwarded arguments.

This stub is removed in v1.36.0.
