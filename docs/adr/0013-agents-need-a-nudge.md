# ADR-0013: Agents need a nudge — a subagent ships skill-paired and hook-nudged, or not at all

## Status

Accepted (2026-09-17). Implemented across the `epic/agents-promotion`
slices; the structure check and the `build-delegation-check` hook land in
sibling commits.

## Context

Six personal subagents lived in `~/.claude/agents/` — builder, verifier,
debugger, designer, planner, architect — added to enable swarm-style
delegation, then forgotten. Nothing in a session ever nudged their use.

Transcript counts over one month (2026-08-17 → 2026-09-17, 1517 sessions):

| Agent | Invocations |
| --------- | ----------- |
| builder | 101 |
| designer | 16 |
| debugger | 10 |
| verifier | 9 |
| planner | 5 |
| architect | 3 |

Against that: Explore + `ai:explore` were invoked **195** times. The
difference is not capability — every agent was listed and reachable in
every session. The difference is `bin/hooks/search-delegation-check.sh`,
which fires deterministically at the moment the agent reaches for a
repo-wide search and says "delegate this". A rule is prose the agent skips
under pressure; a hook is the instruction placed where it cannot be missed.

The lesson generalises: **a listed agent is capability, not habit.** An
agent with no skill naming the phase it fires in, and no hook at the moment
of reaching, will be forgotten no matter how good its prompt is.

## Decision

1. **Pairing rule.** An ai-kit subagent exists only if at least one skill
   names it and the phase it fires in. `tests/bin/eval-structure.sh`
   enforces this: an `AGENT.md` no `SKILL.md` references fails the build.
2. **Nudge principle.** Wherever a "moment of reaching" exists for a paired
   agent, a `PreToolUse` hook nudges it — same pattern as
   `search-delegation-check.sh`: deterministic, advisory-only, emits
   `additionalContext`, never blocks.
3. **`builder`** is promoted, wired into `tdd` and `autonomous`, with a new
   `build-delegation-check` hook that fires on the 3rd distinct file edited
   inline in a session.
4. **`verifier`** is promoted, wired into `review` (per finding, in
   parallel) and `autonomous` (pre-ship).
5. **`designer`** is promoted, paired with a new `design-to-code` skill
   (#106) — designer is the build worker, verifier the prove worker. The
   Pencil MCP stays an optional companion surfaced via `recommend-tools`.
6. **`planner` and `architect` are not ported.** Claude Code's built-in
   Plan agent covers the first; `/ai:audit-architecture` covers the second.
7. **`debugger` is not ported.** `diagnose` keeps its loop inline by design
   (its SKILL.md says so); debugger's three unique rules — never fix a
   flake with a retry, never "fix" with a try/catch/null-guard/sleep, and
   measure before and after under the same conditions — are folded into
   `diagnose`, along with "the expectation was wrong" as a valid outcome.
8. **`doctor` gains a hooks-wired check** (#113), so an upgrade that ships
   a new hook is reported as missing until the project registers it — not
   only fresh installs stay correct.

## Consequences

**Positive**

- A fresh install gets paired agents *and* their hooks through the plugin
  and `/ai:setup`; nothing is left to be remembered.
- Upgrades get the doctor's warning instead of silently missing the hook.
- The pairing rule is a structural test, not a convention — a future
  orphan agent fails CI the same day it is added.

**Negative**

- Two personal agents (planner, architect) retire with no ai-kit
  replacement; their prompts are gone once `~/.claude/agents/` is cleaned.
- One skill grows: `diagnose` absorbs four rules from `debugger`.
- Every future agent costs a skill edit and, usually, a hook — cheaper than
  an agent nobody calls, but not free.

## Reversibility

Agents are files. Removing one is `git rm workflow/agents/<name>`, deleting
the skill lines that name it, and unwiring its hook. The structure test is
the only coupling, and it fails loudly rather than leaving a dangling
reference behind.
