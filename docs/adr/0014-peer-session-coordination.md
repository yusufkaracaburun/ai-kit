# ADR-0014: Peer-session coordination — claims registry, conditional messaging, lead per repo

## Status

Accepted.

## Context

Claude Code sessions on one machine can already see and message each other:
`ListAgents` lists peers by name (`planny-app-mobile-7c`, `planny-7f`,
`ai-kit-99`) and `SendMessage` reaches them. The user runs up to five
sessions at once across repos. Over 15–17 Sep 2026 those sessions exchanged
358 messages to coordinate — and nothing in ai-kit ever told a session that
peers existed, so every agreement was re-invented per session.

What the transcripts show the sessions actually negotiating:

- **Same repo** (planny-app-mobile, sessions 7c/36/64/86/92 in parallel on
  different emulators): file ownership ("the home-skeleton files belong to
  session 64", "next_lesson_hero.dart is mine since 4763201"); commit
  sequencing ("two commits within minutes — keep the index empty", agreed as
  "stage per path and read the staged diff before committing"); Pencil `.pen`
  frame slots ("silent until you give me the .pen slot", "frame Q501VT + the
  Boek-sheet column are yours until you report done"); a LEAD session
  designated by the user (7c) that owns push/merge order, with a lighter
  protocol for mechanical follow-ups ("spec + tests present → build session
  tests and commits, lead only checks live").
- **Cross repo** (planny backend ↔ planny-app-mobile ↔ cce-e2e-tests):
  contract questions ("does the field set we show still match what the
  backend returns"); deploy broadcasts ("prod deployed 6289cd0a..e7a6deca —
  relevant for the app: (1)… (2)…"); resource delegation ("7c needs a live
  booking-flow run on a device, no device there — whoever owns the emulator,
  run it and report"); and decision relay ("From Yusuf, via me: …", "Yusuf
  approved …" — the user decides in one session and that session relays it to
  the peer it affects).
- **Recurring waste**: "who owns X" broadcasts, re-negotiated push rules, and
  97 messages addressed to raw `uds:/tmp/cc-socks/*.sock` targets — sessions
  with no readable name.

Two facts found on the machine while building this shaped the mechanism:

1. Claude Code keeps its own live-session registry at
   `~/.claude/sessions/<pid>.json` — `sessionId`, `cwd`, `name`, `pid`,
   `status`, `updatedAt` — the data behind `ListAgents`. Liveness is therefore
   a `kill -0 <pid>`, not a transcript-mtime heuristic, and every peer has a
   readable name for free.
2. Hooks run under `/bin/bash` 3.2 on macOS; a `SessionEnd` event exists but
   also fires on `/clear`, which would drop a mid-work claim.

## Decision

1. **Scope is cross-repo.** Peers are all live Claude Code sessions on this
   machine, not only those in the same repo.
2. **Awareness is global; messaging is conditional.** A session may message a
   peer only on four triggers: (1) same repo with branch/file overlap; (2) its
   work touches something the peer claims as a dependency (kit release, API
   contract, deploy); (3) a shared-resource clash (emulator, device, port, DB,
   `.pen` frame); (4) relaying a user decision that affects the peer's claimed
   area. Anything else: read, don't send.
3. **One lead per repo, designated by the user.** The lead owns push/merge
   order; non-leads commit locally and report to the lead. No lead named → the
   first session on that repo is lead by default and says so in its claim.
4. **Claims registry**: one file per session,
   `~/.config/ai-kit/claims/<session_id>.md` (YAML frontmatter: name, repo,
   cwd, branch, role, owns, provides, depends_on, updated), managed by
   `bin/ai-kit-claim.sh set|show|release|prune`. "Who owns X" becomes a file
   read. A claim whose session is no longer in the live registry is stale:
   `show` marks it, the next hook run prunes it. Claims live under ai-kit's
   own `~/.config/ai-kit/`, not inside Claude Code's `~/.claude/sessions/`.
5. **SessionStart nudge only when peers exist.** `bin/hooks/peer-sessions-check.sh`
   (delivered machine-wide by the plugin's own `workflow/hooks/hooks.json`,
   because peers are machine-wide and a fresh `/plugin install` must be
   correct without `/ai:setup`) writes a skeleton claim for the current
   session, prunes stale claims, and — only if at least one other session is
   live — injects one `additionalContext`: the peers table, the
   `session-coordination` rule's bullets read from the rule file, and the
   instruction to call `ListAgents` once and register. Solo session: no
   output, zero context cost.
   No `SessionEnd` cleanup: liveness is exact, and releasing on `/clear` would
   lose role/owns mid-work.
6. **Ship-time deploy broadcast.** `/ai:ship` post-deploy runs
   `ai-kit-claim.sh show` and sends every live claim whose `depends_on` names
   this repo a deploy notice: commit range plus the consumer-relevant changes
   in ≤5 bullets.
7. **The rule** (`standards/rules/session-coordination.mini.md`) is universal
   but `on-demand`/`medium`, so `session-rules-inject.sh` never injects it
   unconditionally; the hook is the only pusher on Claude Code, and Cursor has
   no peer messaging to coordinate.

## Consequences

**Positive**

- The three recurring wastes get a mechanism each: ownership → claims file;
  push rules → lead-per-repo in the injected protocol; unnamed targets → the
  peers table carries the registry name every session already has.
- Zero cost when solo: the hook's only unconditional side effects are a
  40-byte claim file and a prune.
- Detection rides Claude Code's own registry, so when the messaging feature
  changes, the peer table changes with it instead of drifting on a heuristic.

**Negative**

- The registry format (`peerProtocol: 1`) is undocumented. A rename of its
  fields makes the hook silently see no peers — same failure mode as
  `ListAgents` itself going away, and silent by design (a hook must never
  break a session), so it will surface as "the nudge stopped" rather than an
  error.
- `kill -0` trusts the pid. After a reboot with a stale registry entry a reused
  pid could show a ghost peer; `procStart` in the registry is the upgrade
  path if that ever bites.
- The hook reads the rule file at fire time; a plugin cache without
  `standards/rules/` emits the peers table with no protocol block, silently.

## Reversibility

Cheap. Delete the `SessionStart` entry from `workflow/hooks/hooks.json` and
`bin/hooks/peer-sessions-check.sh`; remove `~/.config/ai-kit/claims/`. The
rule file is on-demand and inert without the hook. No state outside those
paths, nothing in `~/.claude/` is touched.
