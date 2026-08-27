# ADR-0011: Close the Claude Code enforcement gap with a SessionStart hook

## Status

Accepted (Unreleased). Implemented in the same change that revised this
ADR (issue #144).

This ADR was originally proposed as "split `default_mode` per host"
(kept below as option 3, and as the original recommendation). On
implementation the repo owner's call was option 1 instead — a `SessionStart`
hook that actually injects always-on rules into Claude Code, closing the
enforcement gap directly rather than only making the asymmetry easier to
see. See "Decision" below; the original reasoning for option 3 is kept
under "Options considered" since it remains a valid, un-taken alternative.

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
one host in mind can silently break the other.**

## Options considered

1. **ai-kit `SessionStart` hook** injects `universal: true` + `always-on`
   rules on Claude Code, closing the gap in the direction of Cursor. The 13
   top-level universal rules run ~6.0k words ≈ 8k tokens — paid once per
   session, not per prompt, but needs a size budget and a `weight` cut-off,
   neither of which existed when this option was first written up. Real fix
   for the *enforcement* gap; does nothing by itself for the *shared-key*
   footgun — the frontmatter is still one key read two ways, so flipping a
   mode meaning to retarget one host can still silently affect the other.
2. **Emit into `CLAUDE.md`.** Cheaper than a hook (no new primitive), but
   `CLAUDE.md` / `AGENTS.md` already have a 200-line ceiling enforced by
   `/ai:hygiene`'s `context-lean` check. 21 universal always-on rules would
   blow through that budget immediately. Rejected outright by the issue's
   own framing; not re-litigated here.
3. **Split the key per host** — e.g. `default_mode: {cursor: always-on,
   claude_code: on-demand}` — one migration across 30 rules, mechanical
   (every current `always-on` becomes `cursor: always-on, claude_code:
   on-demand`, preserving today's behavior exactly). The emitter contract
   (`bin/lib/emitters/README.md`) changes: `_emitter_extract_meta` needs a
   per-host lookup instead of a flat string, and `dispatch()` passes the
   value for the agent it's calling, not one shared value. Removes the
   shared-key footgun at the frontmatter level; **does not, by itself, close
   the enforcement gap** — `claude_code: always-on` still needs option 1 (or
   equivalent) to do anything.
4. **Rename to `recommended`**, drop the implied enforcement. Zero migration
   cost, but does not fix the near-miss's actual mechanism: Cursor's
   `alwaysApply` would still be driven by one shared value, so flipping it
   for a Claude-Code reason still silently flips Cursor's real enforcement.

## Decision

**Implement option 1: a `SessionStart` hook
(`bin/hooks/session-rules-inject.sh`) that injects a project's always-on
rules into Claude Code's context.** Option 3 (split the key) is not taken
now — see "Why not option 3" below — but stays a valid follow-up if the
shared-key footgun recurs in practice.

### What the hook actually injects, and the measured cost

Injecting all 21 universal always-on rules (~8.7k words stripped) was ruled
out at the outset as "almost certainly too much" per-session tax. Two gates
narrow that down before anything is measured against a budget:

- **Weight gate.** Only rules whose *source* frontmatter carries
  `weight: high` are candidates. Of the 13 top-level + 8 feedback universal
  always-on rules, 12 carry `weight: high` (9 top-level, 3 feedback) — total
  ~5.2k words stripped, still not a small tax.
- **Budget gate.** `MAX_WORDS=2000` (same order of magnitude as the
  200-line/~2k-word ceiling `bin/ai-kit-context-lean.sh` already applies to
  root `CLAUDE.md`/`AGENTS.md` — this hook does not open a second, bigger
  always-loaded budget). Candidates are added **smallest word-count first**:
  weight already ranks importance, so size is the only signal left to decide
  who fits inside a fixed budget without an arbitrary alphabetical cutoff.

Measured against this repo's own rule set (dogfeeding, see
`tests/bin/cases/session-rules-inject.sh`): of 12 high-weight candidates
(~5.2k words), 6 fit the 2000-word budget at a running total of **1,679
words**, ≈ **11.3k characters**. Estimated tokens: **~2,240** using the same
words × 1.333 conversion the issue used for its own 8k-token figure, or
~2,830 using a 4-chars/token estimate — both well under half of the
original "almost certainly too much" baseline. The remaining 6 high-weight
candidates, and every medium/low-weight universal rule, are **not deleted**
— they stay exactly where they were, readable on demand in
`.claude/rules/<name>.md`, same as before this change.

### Where injection reads from

The hook reads the **project's already-emitted** `.claude/rules/*.md`
(written by `bin/emit-rules.sh`), not `standards/rules/` directly. It uses
the source rule (resolved by name against the plugin/source
`standards/rules/`, wherever the hook script itself lives) only to look up
`weight` — the injected text is exactly the project's own emitted file body.
Two consequences, both intentional:

- A project that never ran `bin/emit-rules.sh` gets nothing injected — the
  hook cannot enforce a rule the project never opted into having on disk,
  matching what Cursor's `alwaysApply` requires too (a rule has to be
  emitted before it can apply).
- A rule re-emitted with `--mode on-demand` drops out of injection on its
  own, without the hook needing to change — the emitted file's own "Mode:"
  header is what the hook checks, not the source frontmatter's
  `default_mode` in isolation.

### Opt-out

Machine-wide, no uninstall required: `bin/ai-kit-no-rule-injection.sh on`
(marker at `~/.config/ai-kit/no-rule-injection`, checked first, before any
other work — same pattern as `bin/ai-kit-no-globals.sh` /
`bin/ai-kit-prefer-plugin.sh`).

### `context-lean` reconciliation

`bin/ai-kit-context-lean.sh` (the check behind `/ai:hygiene`'s always-loaded
CLAUDE.md/AGENTS.md warning) now also runs the hook in `--report` mode
against the project and warns if the injected word count exceeds its own
`MAX_INJECT_WORDS=2000` ceiling — the same number the hook defaults to, but
independently stated, so a future bump to the hook's own budget without a
matching bump here still shows up as a regression instead of silently
raising the always-loaded tax. See
`tests/bin/cases/context-lean.sh` (`SessionStart rule injection budget`
section).

### Why not option 3

The near-miss that motivated this ADR was specifically about *enforcement*
going silently missing on one host while a frontmatter edit targeted the
other — and shipping option 1 removes the actual harm (Claude Code no
longer silently drops enforcement for the rules that matter most) without
waiting on a 30-file migration first. Option 3 remains real: it would make
the two hosts' values independently addressable at the frontmatter level,
which option 1 does not — the key is still one value read two ways, and a
future edit could still misjudge the effect on the other host. That risk is
judged acceptable for now because `tests/bin/cases/default-mode-semantics.sh`
already pins today's per-host behavior (it fails if an emitter's handling of
`$mode` narrows or a new emitter ignores it), giving a mechanical check
against the exact regression class that caused the original near-miss.

## Consequences

- `bin/hooks/session-rules-inject.sh` ships via
  `workflow/hooks/hooks.json` (`SessionStart`), mirrored to
  `workflow/hooks/` and `workflow/bin/hooks/` by the existing sync scripts.
- `bin/ai-kit-no-rule-injection.sh` is the new machine-wide opt-out toggle.
- `bin/ai-kit-context-lean.sh` gained the reconciliation section above;
  `/ai:hygiene` scoring is unchanged in shape (still one pass/fail section),
  just now also covers the injected-rule budget.
- `bin/lib/emitters/README.md`'s "not yet implemented" note is stale as of
  this ADR — updated to point at this hook instead of claiming no fix
  exists.
- Medium/low-weight universal always-on rules, and every rule a project
  never emitted, are **not** injected — they are unaffected by this change
  and remain exactly as inert on Claude Code as before. Cursor's
  `alwaysApply` is untouched either way; this ADR only changes Claude Code.
- Option 3 (split the key) is not implemented. Reopen this ADR (or file a
  new one) if the shared-key footgun recurs in a way the regression test
  above does not catch.
