# ADR-0011: Split `default_mode` per host instead of sharing one key

## Status

Proposed — awaiting the repo owner's call. Not implemented; no rule
frontmatter or emitter changes ship with this ADR (issue #144).

## Context

`standards/rules/*.mini.md` carry `default_mode: always-on | on-demand`. 30
rules set `always-on` (22 in `standards/rules/`, 8 in
`standards/rules/feedback/`), 21 of them also `universal: true`. One key,
read by two emitters, means two different things:

| Host | Emitter | Effect of `always-on` |
| --- | --- | --- |
| Cursor | `bin/lib/emitters/cursor.sh` | `alwaysApply: true` in the `.mdc` — real enforcement, every prompt. |
| Claude Code | `bin/lib/emitters/claude-code.sh` | A comment line in `.claude/rules/<name>.md` ("Mode: always-on"). No hook reads it. Inert. |

`workflow/.claude-plugin/plugin.json` ships one hook (`PostToolUse`, opt-in
usage logging) and no `SessionStart`/`UserPromptSubmit` of its own, so
nothing on Claude Code injects rule content on the strength of this key.

This nearly caused a regression, and that near-miss is the reason to act
rather than just document: `pre-write-discipline.mini.md` was flipped from
`always-on` to `on-demand` on the belief that the third-party `ponytail`
plugin now owned the always-on slot on Claude Code. Pre-release review
caught that the flip would also emit `alwaysApply: false` into every Cursor
project — ponytail is Claude-Code-only, and Cursor's real enforcement would
have been silently switched off with nothing replacing it. The flip was
reverted (`d811dc5`, `db742bc`).

The bug class is structural, not a one-off mistake: **one key drives a real
effect on one host and a no-op on the other, so a decision made with only
one host in mind can silently break the other.** Renaming the key does not
change that; only separating the two effects does.

## Options considered

1. **ai-kit `SessionStart` hook** injects `universal: true` + `always-on`
   rules on Claude Code, closing the gap in the direction of Cursor. The 13
   top-level universal rules run ~6.0k words ≈ 8k tokens — paid once per
   session, not per prompt, but still needs a size budget and a `weight`
   cut-off (`weight: high` only, say) that does not exist yet. Real fix for
   the *enforcement* gap; does nothing for the *shared-key* footgun — the
   frontmatter would still be one key read two ways, so the same class of
   mistake (flip a mode meaning to retarget one host, silently affect the
   other) survives even after Claude Code gets real injection.
2. **Emit into `CLAUDE.md`.** Cheaper than a hook (no new primitive), but
   `CLAUDE.md` / `AGENTS.md` already have a 200-line ceiling enforced by
   `/ai:hygiene`'s `context-lean` check (`workflow/commands/hygiene.md`
   section 6). 21 universal always-on rules would blow through that budget
   immediately. Rejected outright by the issue's own framing; not re-litigated
   here.
3. **Split the key per host** — e.g. `default_mode: {cursor: always-on,
   claude_code: on-demand}` — one migration across 30 rules, mechanical
   (every current `always-on` becomes `cursor: always-on, claude_code:
   on-demand`, preserving today's behavior exactly; nothing changes for a
   Cursor user or a Claude Code user on day one). The emitter contract
   (`bin/lib/emitters/README.md`) changes: `_emitter_extract_meta` needs a
   per-host lookup instead of a flat string, and `dispatch()` passes the
   value for the agent it's calling, not one shared value.
4. **Rename to `recommended`**, drop the implied enforcement. Zero migration
   cost. But it does not fix the near-miss's actual mechanism: Cursor's
   `alwaysApply` would still be driven by one shared value, so flipping it
   for a Claude-Code reason still silently flips Cursor's real enforcement.
   It only stops the value from *overclaiming* what Claude Code does — the
   asymmetric-effect trap that caused the near-miss stays exactly as sharp.

## Decision

**Recommend option 3: split the key per host.**

Reasoning:

- It is the only option that removes the actual failure mode. The near-miss
  was not "the docs didn't explain `always-on`" — it was "one field changed
  for a Claude-Code reason and silently changed Cursor too." Only making the
  two hosts separately addressable closes that. Option 4 relabels the
  symptom; option 3 removes the shared wire.
- It costs nothing at runtime. No new token tax, no weight-cutoff heuristic
  to invent, no interaction with `context-lean`. It is a one-time,
  mechanical frontmatter + emitter-contract migration, fully reversible.
- It does not foreclose option 1. Once rules carry an explicit
  `claude_code:` value, a future `SessionStart` hook (option 1) has exactly
  the input it needs — "which rules does this repo want enforced on Claude
  Code" — without having to reuse a Cursor-shaped value for a purpose it was
  never scoped for. Splitting first makes injecting later a smaller,
  better-specified change, not a second migration.

Honest cost:

- 30 rule files change frontmatter shape (mechanical, scriptable — not a
  per-rule editorial judgment call, since the migration preserves current
  behavior exactly: `always-on` → `{cursor: always-on, claude_code:
  on-demand}`, `on-demand` → `{cursor: on-demand, claude_code: on-demand}`).
- `_emitter_extract_meta`, `bin/emit-rules.sh`'s mode resolution, and all
  three emitters (`cursor.sh`, `claude-code.sh`, `generic.sh`) need their
  `mode` parameter to become host-scoped, plus the fixtures in
  `tests/bin/cases/bootstrap-emit.sh` that assert on `default_mode` output.
  Not free, but bounded and mechanical — no new abstraction, no speculative
  generality for hosts ai-kit doesn't have (ADR-0006 already ruled that out).
- **It does not close the enforcement gap on Claude Code.** After this
  migration, `claude_code: always-on` still does nothing until something
  reads it — today's inert `.claude/rules/<name>.md` comment stays inert,
  just now honestly scoped instead of borrowed from a Cursor-shaped key.
  Rules that genuinely need Claude Code enforcement still need option 1 (or
  an equivalent) as a separate, later decision — this ADR does not make
  that case for them, it only stops the wrong host from moving when the
  right one is meant to.

## Consequences

- `standards/rules/**/*.mini.md` frontmatter gains a documented two-value
  shape for `default_mode`; `bin/lib/emitters/README.md` becomes the source
  of truth for what each per-host value causes (already the deliverable of
  issue #144's DoD item 2, landed ahead of this ADR).
- The regression test added under #144
  (`tests/bin/cases/default-mode-semantics.sh`) pins today's single-key
  behavior; implementing this ADR means rewriting that test's fixtures
  around the split shape rather than the flat one.
- **Not done here:** the frontmatter migration, the emitter-contract change,
  and any Claude Code injection mechanism. This ADR proposes; the repo owner
  approves before any of it lands.
