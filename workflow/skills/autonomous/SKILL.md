---
name: autonomous
description: SPIKE / opt-in. Autonomous backlog grinder — drains issues labeled `ready-for-agent` one at a time, fresh agent context per issue, persistent progress log. Wraps tdd → review → ship. Use when the user wants an AFK queue-drain run, references "Ralph pattern", or invokes `/ai:autonomous`. Spike status — see docs/spikes/ai:autonomous-ralph.md before relying on it.
---

# Autonomous backlog grinder

> **Status:** spike draft (2026-05-23). Tracks
> [#17](https://github.com/yusufkaracaburun/ai-kit/issues/17). Do not
> wire into `setup` until first real-queue drain succeeds. See
> [docs/spikes/ai:autonomous-ralph.md](../../../docs/spikes/ai:autonomous-ralph.md).

Drains a `ready-for-agent` queue by running ai-kit's existing
TDD → review → ship loop, one issue at a time, with cold-start
context per iteration. Pattern is adapted from Geoffrey Huntley's
"Ralph" and `snarktank/ralph` — fresh-instance-per-story, persistent
`progress.txt`, git-log-as-memory.

## Relationship to other ai-kit skills

| Skill | Role in this loop |
| ----- | ----------------- |
| `triage` | Produces the queue (`ready-for-agent` label) |
| `tdd` | Inner loop per issue |
| `review` | Pre-merge verification per issue |
| `ship` | PR open + (project-policy) merge |
| `autonomous` | **This skill** — orchestrates the above across N issues |

## Relationship to `/loop`

`/loop` is a scheduler, this skill is a worker. Use either:

- **Manual:** `/ai:autonomous` — drains one issue, exits.
- **Scheduled:** `/loop 600s /ai:autonomous` — `/loop` schedules
  fresh fires; each fire processes one issue and exits. Fresh-context
  invariant preserved because `/loop` re-invokes the slash command
  cleanly.

This skill MUST NOT call `ScheduleWakeup` or recurse — that would
tangle scheduler/worker concerns and break cold-start iteration.

## Modes

| Mode | Behavior |
| ---- | -------- |
| `dry-run` *(default)* | Pick next issue, print plan, exit. No git, no PR, no log mutation. |
| `one` | Drain exactly one issue end-to-end, then exit. |
| `drain` | Drain until queue empty or stop condition hit. |

Invocation: `/ai:autonomous` (= `dry-run`), `/ai:autonomous one`,
`/ai:autonomous drain`.

## Process (one iteration)

0. **Cwd + branch precondition.** Before *any* git or gh operation:
   - Determine `target_worktree` from the brief. Heuristic: parse the
     `## Agent Brief` comment for `worktree (...)`, `branch (...)`,
     `Werk in (git )?worktree`, or an explicit `target_worktree:`
     key. If the brief does not name a worktree, default to the
     current cwd (single-worktree project).
   - **Recommended worktree layout** (when a brief specifies one):
     `<repo-root>/.agents/worktrees/<branch-slug>`. Inside-project
     placement keeps cwd-confusion impossible when the user starts CC
     from the repo root, keeps worktree state under one `.gitignore`
     entry, and centralises cleanup. Sibling-directory layouts (e.g.
     `~/Sites/<project>-refactor` next to `~/Sites/<project>`) are
     legacy — they trigger the cwd-mismatch path more often because
     CC's session-primary cwd is usually the main repo.
   - Compare `$(pwd)` against `target_worktree`. Mismatch → write
     `exit-gate cwd-mismatch <expected-vs-actual>` and stop. No pick,
     no log mutation beyond the exit-gate line, no git operation.
     Surface remediation: `cd <target_worktree> && /ai:autonomous one`.
   - Determine `target_branch` from the brief (same parsing). Compare
     against `git rev-parse --abbrev-ref HEAD`. Mismatch → write
     `exit-gate branch-mismatch <expected-vs-actual>` and stop.
   - **Pin `AI_KIT_ROOT` per-conversation** (P4 from
     [`docs/spikes/aikit-autonomous-ralph.md`](../../../docs/spikes/aikit-autonomous-ralph.md)).
     Parse the brief for an `ai_kit_root:` key. If present, `export
     AI_KIT_ROOT=<that>` for the rest of the run; if absent, leave the
     existing resolver alone (`${HOME}/.config/ai-kit/root` fallback).
     Log `preflight-ai-kit-root-pinned <path>`.
   - **Triage labels exist** (P6 preflight). Verify the project tracker
     carries the labels the queue depends on:
     ```bash
     gh label list --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" --json name --jq '.[].name' \
       | grep -qx ready-for-agent || { echo 'exit-gate triage-labels-missing ready-for-agent' >> .ai-kit/autonomous/progress.txt; exit 1; }
     ```
     Log `preflight-triage-labels-ok` on success.
   - **Detect merge policy** (P5 modification). Resolve in this order
     and write `preflight-merge-policy-detected:<pr|direct>`:
     1. Brief carries `merge_policy: pr|direct` key → use it.
     2. `.ai-kit-setup` `branches.merge_policy` → use it.
     3. `git config --get ai-kit.merge-policy` → use it.
     4. Default `pr`.
     If the brief asks for one mode and the project config says another
     (steps 1 vs 2/3 disagree), write `exit-gate merge-policy-mismatch
     <brief-vs-project>` and stop — never silently widen authority.
   - Start the heartbeat helper:
     ```bash
     "$AI_KIT_ROOT/bin/autonomous-heartbeat.sh" <issue#> \
       .ai-kit/autonomous/progress.txt &
     HEARTBEAT_PID=$!
     trap 'kill "$HEARTBEAT_PID" 2>/dev/null' EXIT
     ```
1. **Read state.** `cat .ai-kit/autonomous/progress.txt` (cold). Note
   the last `pick` line that has no matching `exit-*` — that's an
   abandoned iteration; surface it and stop.
2. **Pick next issue.** `gh issue list --label ready-for-agent --json number,title,updatedAt --jq 'sort_by(.updatedAt) | .[0]'`. Oldest first. Queue empty → write `exit-empty`, stop.
3. **Read Agent Brief.** `gh issue view <n> --comments` — find the
   comment whose header is the literal `## Agent Brief`. If missing or
   thin (no acceptance criteria inline), write `exit-gate brief-thin`
   with one of these diagnostic detail strings, then stop:
   - `header-mismatch` — a comment with a different header is present
     (e.g. `## Triage outcome`). The triage skill produced a comment
     but used the wrong header; recommend `/ai:triage <n>` to re-emit.
   - `body-not-promoted` — no brief comment, but the issue body looks
     promotable (contains the word "acceptance" or a checkbox list).
     Recommend `/ai:triage <n>` to formalise the body into a brief.
   - `no-brief` — neither a brief comment nor a promotable body. The
     issue needs human triage before any agent can pick it up.
   Never read linked file paths from the comment; the brief is a
   cold-start contract.
4. **Branch.** If step 0 confirmed the cwd is already on the brief's
   `target_branch` inside a worktree, **skip `git switch -c`** — the
   work happens on the existing feature branch (per the brief's
   "Eén commit-bundle on `<branch>`" or equivalent). Otherwise,
   `git switch -c agent/issue-<n>-<slug>` from the project's default
   branch. Fail-fast if dirty working tree.
5. **TDD.** Invoke `tdd` against the Agent Brief's acceptance
   criteria. Hard cap: each red→green cycle gets ≤3 attempts. Cap
   hit → `exit-gate tdd-stuck`, leave branch for human. Emit one
   `cycle-attempt <C-id> attempt=<n> result=<pass|fail>` line per
   attempt and one `cycle-done <C-id> result=<pass|fail>` line per
   cycle boundary, so the cold-read log shows real-time progress
   instead of a 20-minute silent gap.
6. **Review.** Invoke `review` in `comprehensive` mode with
   security depth `deep`. Any **Blocker** or security finding ≥ `high`
   → `exit-gate review-blocked`, leave branch for human.
7. **Ship.** Invoke `ship` to open a PR. **Never auto-merge.**
   The project's merge policy (CI, approval, branch protection) is
   the safety net.
8. **Log.** Append `ship-ok` line to `progress.txt`. Loop continues
   (mode `drain`) or exits (mode `one`).

### Per-Bash discipline (defense in depth)

Every Bash invocation MUST prefix `cd <target_worktree> &&` (absolute
path, no shell expansion). If a command must run from elsewhere, use
absolute paths for every argument and never assume the post-command
cwd — the CC harness resets cwd to the session's primary working
directory after every command, so a `cd X && cmd` does not stick.

### Real-time view (backup observability)

`progress.txt` cadence is best-effort (LLM-emitted). For an
authoritative live-view independent of LLM discipline, tail the CC
session transcript:

```bash
ls -lt ~/.claude/projects/*<repo-slug>*/sessions/*.jsonl | head -1
tail -F <that-path>
```

The transcript records every tool call with timestamp, so a stuck
process is mechanically detectable (no new entries for >N seconds).

## Stop conditions

Always exit with a one-line `exit-*` entry in `progress.txt`:

| Trigger | Event tag | Action |
| ------- | --------- | ------ |
| Queue empty | `exit-empty` | Normal termination |
| Cwd ≠ brief's target_worktree | `exit-gate cwd-mismatch <detail>` | `cd <target_worktree> && /ai:autonomous one` |
| HEAD branch ≠ brief's target_branch | `exit-gate branch-mismatch <detail>` | `git switch <target_branch> && /ai:autonomous one` |
| Brief missing / thin | `exit-gate brief-thin <detail>` | Human re-triage (`detail` ∈ `header-mismatch`, `body-not-promoted`, `no-brief`) |
| TDD cap (≤3 attempts per cycle) | `exit-gate tdd-stuck` | Human implementation |
| Review blockers | `exit-gate review-blocked` | Human review |
| Security ≥ high | `exit-gate security` | Human review |
| Triage labels missing on tracker | `exit-gate triage-labels-missing <label>` | `gh label create <label>`; re-run |
| Merge policy disagreement (brief vs project config) | `exit-gate merge-policy-mismatch <detail>` | Align brief or project config; re-run |
| Push needs force / conflict resolution | `exit-gate git-conflict` | Human resolution |
| User explicit stop OR harness instability skill cannot remediate | `exit-handoff <reason>` | Human drives remaining gates (see Handoff protocol) |
| `max_iterations` reached | `exit-cap` | User re-invokes |
| Unexpected error | `exit-error <reason>` | Inspect log |

Default `max_iterations` = 5.

## Handoff protocol

`exit-handoff` is a first-class, non-error termination. It is **not**
the same as `exit-error` (skill malfunction) or `exit-gate` (blocker
the skill detected). It is a deliberate handover from skill to human.

**Trigger conditions:**
- User issues an explicit stop instruction mid-run.
- Skill detects harness instability it cannot self-remediate
  (repeated truncated Bash paths, cwd resets it cannot work around,
  context-window degradation manifesting as lower-quality tool calls).

**Required side-effects:**
- Append `exit-handoff <reason-detail>` to `progress.txt`.
  Reason-detail must name the trigger and a short state-summary, e.g.
  `user-takeover; 225 files staged in worktree; verification gates not run`.
- Leave worktree changes **uncommitted** — the user inspects diff and
  commits per their own judgment.
- Never push, never open PR, never `git reset` the worktree.
- Produce a chat-output recipe for the user to drive the remaining
  gates, structured as:
  - Per-cycle (or per-logical-unit) commit-split with concrete
    `git add <pattern>` patterns.
  - Risk-check commands to run before commit (linter, targeted
    tests, vendor-contract sanity-greps if the run did bulk-rewrites).
  - End-gate commands (full test suite, smoke test, baseline diff).

## `progress.txt` schema

Path: `.ai-kit/autonomous/progress.txt`. Append-only, one event per line:

```
<ISO-8601 ts>\t<issue#>\t<event>\t<detail>
```

Events:
- **Preflight (P6 — pattern adopted from OpenHands status state
  machine):** `preflight-cwd-ok`, `preflight-triage-labels-ok`,
  `preflight-merge-policy-detected:<pr|direct>`,
  `preflight-ai-kit-root-pinned <path>`. Emitted by step 0 before any
  pick. Cold-readable proof the run started clean. Absence of a
  `preflight-*` line on a fresh run = step 0 was skipped — refuse to
  consume that progress.txt and start over.
- **Lifecycle:** `pick`, `brief-ok`, `cycle-attempt`, `cycle-done`,
  `tdd-green`, `review-pass`, `ship-ok`.
- **Liveness:** `heartbeat` — one per 60s wall-clock while the skill
  is alive (emitted by `bin/autonomous-heartbeat.sh`, not the LLM).
  Absence of `heartbeat` for >120s = process gone or runner crashed.
- **Termination:** `exit-empty`, `exit-gate <reason>`, `exit-handoff
  <reason>`, `exit-cap`, `exit-error <reason>`.

Example trace (columns separated by literal `\t`):

```
2026-05-23T09:59:50Z \t -  \t preflight-cwd-ok                  \t /…/.agents/worktrees/feat-foo
2026-05-23T09:59:51Z \t -  \t preflight-triage-labels-ok        \t ready-for-agent
2026-05-23T09:59:52Z \t -  \t preflight-merge-policy-detected   \t pr
2026-05-23T09:59:53Z \t -  \t preflight-ai-kit-root-pinned      \t /…/ai-kit
2026-05-23T10:00:00Z \t 42 \t pick           \t feat: foo
2026-05-23T10:00:05Z \t 42 \t brief-ok       \t 5 criteria
2026-05-23T10:01:00Z \t 42 \t heartbeat      \t brewing
2026-05-23T10:01:30Z \t 42 \t cycle-attempt  \t C1 attempt=1 result=pass
2026-05-23T10:01:35Z \t 42 \t cycle-done     \t C1 result=pass
2026-05-23T10:02:00Z \t 42 \t heartbeat      \t brewing
2026-05-23T10:02:30Z \t 42 \t tdd-green      \t cycles=4
2026-05-23T10:03:10Z \t 42 \t review-pass    \t mode=comprehensive
2026-05-23T10:03:45Z \t 42 \t ship-ok        \t pr=#101
2026-05-23T10:03:46Z \t 43 \t pick           \t fix: bar
2026-05-23T10:04:00Z \t 43 \t exit-gate      \t brief-thin header-mismatch
2026-05-23T23:00:02Z \t 42 \t exit-handoff   \t user-takeover; 225 files staged; gates not run
```

The next iteration reads this cold — no in-context memory required.

## Trust model

- **Never operate outside the brief's declared worktree.** Master /
  main / any branch other than the brief's `target_branch` is
  read-only from the skill's perspective. Any tool call that would
  mutate state outside the target worktree (or its parent dir) MUST
  be refused with `exit-gate cwd-mismatch` or `exit-gate
  branch-mismatch`. This is the safety guarantee step 0 exists to
  enforce.
- **Agent is the writer; the reviewer is human.** This skill produces
  code on behalf of dev #1; dev #2 (human) must read the diff before
  merge. The rule holds even when the project has only one human
  contributor — solo-human-with-autonomous still reads every PR. ai-kit
  defaults assume ≥2 devs per ai-kit issue #52; the writer/reviewer
  split is the load-bearing invariant, not a CI/branch-protection
  consequence. See also the triage ↔ autonomous Agent Brief contract
  for how the writer's input arrives cold.
- **Never auto-merge.** Open PRs only. Project merge policy enforces
  the gate.
- **Never bypass CI / branch protection.** No `--no-verify`, no
  `--force` pushes.
- **Never silently widen scope.** If TDD or review reveals adjacent
  bugs, write a note in the PR description and stop — do not fix
  unrelated issues in the same PR.
- **Never escalate `exit-handoff` to `exit-error`.** A user-initiated
  stop is a deliberate handover, not a failure. See Handoff protocol.

## Limitations (spike-stage)

- No parallel iteration (out of scope per #17).
- No automatic queue re-triage when `exit-gate` fires.
- No resume-from-last-pick on stale `progress.txt` (manual cleanup).
- Not yet wired into `setup`. Hand-install only.
- Not yet validated on a real `ready-for-agent` issue. First production
  drain unblocks promotion from spike → released.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can
spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" autonomous start
bash "$AI_KIT_ROOT/bin/log-skill.sh" autonomous done   # or `abort` if you bail
```

Silent no-op when the env var is unset. See
[SECURITY.md](../../../SECURITY.md) for what is logged and where.
