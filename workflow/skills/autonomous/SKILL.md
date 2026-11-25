---
name: autonomous
description: Autonomous backlog grinder — drains issues labeled `ready-for-agent` one at a time, fresh agent context per issue, persistent progress log. Wraps tdd → review → PR. Use when the user wants an AFK queue-drain run, references "Ralph pattern", or invokes `/ai:autonomous`.
---

# Autonomous backlog grinder

> **Status:** stable (promoted 2026-05-26 after multiple real-queue drains
> in `ai-kit` and the portal app). Original spike research preserved at
> [docs/spikes/aikit-autonomous-ralph.md](../../../docs/spikes/aikit-autonomous-ralph.md).
> Tracks [#17](https://github.com/yusufkaracaburun/ai-kit/issues/17).

Drains a `ready-for-agent` queue by running ai-kit's existing
TDD → review → PR loop, one issue at a time, with cold-start
context per iteration. Pattern is adapted from Geoffrey Huntley's
"Ralph" and `snarktank/ralph` — fresh-instance-per-story, persistent
`progress.txt`, git-log-as-memory.

## Relationship to other ai-kit skills

| Skill | Role in this loop |
| ----- | ----------------- |
| `triage` | Produces the queue (`ready-for-agent` label) |
| `tdd` | Inner loop per issue |
| `review` | Pre-merge verification per issue |
| [ship brief](../triage/SHIP-BRIEF.md) | Branch, commit and PR open in one subagent |
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

> **Operator tip (macOS):** a long `drain` run keeps burning tokens with
> no keyboard/mouse input, which macOS treats as idle — the machine can
> sleep mid-run and kill the session. Prefix the terminal command with
> `caffeinate -s --` (or wrap the whole session: `caffeinate -s -- claude`)
> to prevent it. Linux equivalent: `systemd-inhibit --what=idle`.

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
   - **Triage labels exist** (P6 preflight). Read the label string the
     project maps to the `ready-for-agent` role from
     `docs/agents/triage-labels.md` (written by `/ai:setup`), then verify
     the project tracker carries it:
     ```bash
     READY_LABEL=$(awk -F'|' '$2 ~ /`ready-for-agent`/ {gsub(/^ +| +$|`/, "", $3); print $3}' docs/agents/triage-labels.md 2>/dev/null)
     [ -n "$READY_LABEL" ] || { echo 'exit-gate triage-labels-missing docs/agents/triage-labels.md' >> .ai-kit/autonomous/progress.txt; exit 1; }
     gh label list --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" --json name --jq '.[].name' \
       | grep -qxF "$READY_LABEL" || { echo "exit-gate triage-labels-missing $READY_LABEL" >> .ai-kit/autonomous/progress.txt; exit 1; }
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
1a. **Usage guard (opt-in).** Runs every iteration — `one`, each lap
    of `drain`, and each fresh `/loop`-fired invocation — since usage
    accumulates across issues, not just at run start. No-op unless
    `AI_KIT_AUTONOMOUS_USAGE_GUARD_USD` is set:
    ```bash
    if [ -n "$AI_KIT_AUTONOMOUS_USAGE_GUARD_USD" ]; then
      projected=$(npx -y ccusage@latest blocks --active --json 2>/dev/null \
        | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8")||"{}");console.log(d.blocks?.at(-1)?.projection?.totalCost ?? 0)' 2>/dev/null)
      awk -v p="${projected:-0}" -v g="$AI_KIT_AUTONOMOUS_USAGE_GUARD_USD" 'BEGIN{exit !(p+0>=g+0)}' && {
        printf '%s\t-\texit-gate usage-cap\tprojected=$%s guard=$%s\n' \
          "$(date -u +%FT%TZ)" "$projected" "$AI_KIT_AUTONOMOUS_USAGE_GUARD_USD" >> .ai-kit/autonomous/progress.txt
        exit 0
      }
    fi
    ```
    `projection.totalCost` is ccusage's projected spend for the *active*
    5-hour block by its end, not a hard Anthropic-reported limit — ccusage
    has no API for the account's real cap, so the guard is a user-chosen
    dollar ceiling, not a universal threshold. Silent no-op when unset.
2. **Pick next issue.** `"$AI_KIT_ROOT/bin/autonomous-queue.sh" next --log .ai-kit/autonomous/progress.txt`. Oldest first. The script skips an issue that already has an open PR (logs `skip <n> open-pr=<PR#>`) and an idea card (logs `skip <n> idea-card`), then takes the next one. An idea is never built: at the end name each skipped one and recommend `/ai:triage <n>` to rewrite it to its new type. Non-zero exit → write `exit-gate queue-error`, stop. Queue empty → write `exit-empty`, stop.
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
4. **Branch.** Fail fast on a dirty working tree (`git status
   --porcelain` non-empty → `exit-error dirty-tree`). Name the branch:
   the brief's `target_branch` when step 0 confirmed the cwd is already
   on it inside a worktree, otherwise `agent/issue-<n>-<slug>` from the
   project's default branch. The skill does not create it; the ship
   brief in step 7 does, and builder's uncommitted work carries over.
   Clean tree → move the card to `Doing`:
   `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" <n> --status Doing`.
   A failure or "no board" note does not stop the run.
5. **TDD.** Invoke `tdd` against the Agent Brief's acceptance
   criteria. The per-issue worker is the `builder` subagent
   (`subagent_type=ai:builder`, fed the full Agent Brief in the shape
   of `triage/AGENT-BRIEF.md`: summary, key interfaces, acceptance
   criteria, Out of scope, test command and Decisions in force) — that
   is the fresh context per issue. The brief passes the hard cap (≤3 attempts per red→green
   cycle) to builder and fills the brief's run budget (under Test command)
   with the nearest test file per cycle and one full-suite run at the end (idea from mattpocock/skills abeeaf9). Builder's report carries a `## Cycles` block
   (`<C-id> attempts=<n> result=<pass|fail>` per cycle); after it
   returns, write from that block one
   `cycle-attempt <C-id> attempt=<n> result=<pass|fail>` line per
   attempt and one `cycle-done <C-id> result=<pass|fail>` line per
   cycle. A cycle at the cap or under builder's `## Blocked /
   unverified` → `exit-gate tdd-stuck`, leave branch for human.
6. **Review.** Invoke `review` in `comprehensive` mode with
   security depth `deep`. Any **Blocker** or security finding ≥ `high`
   → `exit-gate review-blocked`, leave branch for human. Review's QA pass
   runs here too when the project switched it on, against the uncommitted
   work. Its blockers are not `review-blocked`: they get that pass's one
   fix round (a builder brief with step 5's cap and logging; a cycle at
   the cap counts as red). Still red, a re-run that cannot run, or a tree
   changed by QA in any run → `exit-gate qa-blocked <first blocker or
   path>`, leave branch for human; never ask. QA passed → log `qa-pass`;
   first run skipped → log `qa-skip <reason>` and continue. No `QA:` line
   (off, or `UI: no`) → log neither.
6a. **Verify.** Spawn `verifier` (Task tool, `subagent_type=ai:verifier`)
    on the claim "the acceptance criteria in the Agent Brief are met by
    this branch"; pass the brief, `git diff <default-branch>`, and from
    `git status --porcelain` the builder's new files, staged (`A`) or
    untracked (`??`), both lists, with the instruction to read each of
    them. Step 4 left the tree clean and step 6 stops on a tree QA
    changed, so every new file is builder's work. In the same call
    ask for its card check: pass the card number and its body verbatim
    (`gh issue view <n> --json body -q .body`), the test output, the
    review report from step 6 and the run budget.
    Read the result in this order:
    - Any NOT PROVEN box → no commit, no PR, no merge. Post one comment on
      the card with every box, its status and its evidence or reason, then
      hand the card over (below) with `--status Blocked` and write
      `exit-gate dod-unproven <number of boxes>: <first box and reason>`.
      There is no fix round after this step; the cap of step 5 and the
      one QA fix round of step 6 are the only ones. A human who opens the
      PR from this branch writes `Refs #<n>`, never a closing keyword,
      while a box is open.
    - REFUTED → `exit-gate verify-refuted <counter-evidence line>`, leave
      branch for human.
    - CONFIRMED or UNTESTABLE → `verify-pass`, continue. POST-MERGE boxes
      do not block; step 7 ships them with `Refs`.

    **Hand the card over.** The picker only sees the label and closing
    PRs, so an issue that keeps its label would be picked again. In one
    call, since shell variables do not outlive it, swap the label for the
    one that maps to `ready-for-human`:
    ```bash
    READY_LABEL=$(awk -F'|' '$2 ~ /`ready-for-agent`/ {gsub(/^ +| +$|`/, "", $3); print $3}' docs/agents/triage-labels.md)
    HUMAN_LABEL=$(awk -F'|' '$2 ~ /`ready-for-human`/ {gsub(/^ +| +$|`/, "", $3); print $3}' docs/agents/triage-labels.md)
    [ -n "$READY_LABEL" ] && [ -n "$HUMAN_LABEL" ] &&
      gh issue edit <n> --remove-label "$READY_LABEL" --add-label "$HUMAN_LABEL"
    ```
    A failed swap stops the run: `exit-error label-swap-failed <n>`, after
    the exit-gate line if there is one. Then set the status, if one is
    named, with `ai-kit-issue-meta.sh` as in step 4.
7. **Ship.** Spawn one ship brief ([`triage/SHIP-BRIEF.md`](../triage/SHIP-BRIEF.md)):
   branch from step 4, the paths builder changed, a Conventional
   Commits title, the verifier's `## Boxes` entries and the review verdict
   under **Boxes** (the ship brief ticks the proven ones before the push
   and posts the one evidence comment), PR body summary + test plan +
   the review's `QA:` and `Untested:` lines verbatim when there are any +
   `Fixes #<n>`, or `Refs #<n>` when a POST-MERGE box stays open, merge
   `none`, deploy `none`, and after: the default branch (or `stay` on a
   pinned `target_branch`), so the next lap starts clean. Merge policy
   `direct` sets PR `none` and branch `none`. **Never auto-merge.**
   The project's merge policy (CI, approval, branch protection) is
   the safety net. The ship brief reports a stop → `exit-gate
   git-conflict <stop line>`, leave the tree for human. Shipped with the
   card still open: hand it over as in 6a, without a status change, so
   whoever merges proves the last boxes and closes it.
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
| Review blockers or security ≥ high | `exit-gate review-blocked` | Human review |
| QA still red or unable to re-run after its one fix round, or QA changed the tree | `exit-gate qa-blocked <first blocker or path>` | Human reads the repro or the changed paths, fixes on the branch |
| Verifier refutes "acceptance criteria met" | `exit-gate verify-refuted <counter-evidence>` | Human review |
| A box on the card is NOT PROVEN | `exit-gate dod-unproven <count and first box>` | Read the card's comment, prove or rewrite the box, then relabel |
| Triage labels missing on tracker | `exit-gate triage-labels-missing <label>` | `gh label create <label>`; re-run |
| Merge policy disagreement (brief vs project config) | `exit-gate merge-policy-mismatch <detail>` | Align brief or project config; re-run |
| Projected 5-hour cost ≥ `AI_KIT_AUTONOMOUS_USAGE_GUARD_USD` (opt-in) | `exit-gate usage-cap <projected-vs-guard>` | Wait for the block to roll (`ccusage blocks --active` shows `remainingMinutes`), then re-invoke |
| Ship brief stopped (red check, push needs force, conflict, tick refused) | `exit-gate git-conflict` | Human resolution |
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
  `tdd-green`, `review-pass`, `qa-pass` (detail: the `QA:` line), `qa-skip`
  (detail: the reason), `verify-pass`, `ship-ok`, `skip`
  (detail `open-pr=<PR#>` or `idea-card`; the picker passed over an issue
  that already has an open PR, or an idea card).
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
2026-05-23T10:03:30Z \t 42 \t verify-pass    \t verdict=confirmed
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
  contributor — solo-human-with-autonomous still reads every PR. The
  defaults assume ≥2 devs; the writer/reviewer
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

## Limitations

- No parallel iteration (out of scope per #17).
- No automatic queue re-triage when `exit-gate` fires.
- No resume-from-last-pick on stale `progress.txt` (manual cleanup).

## Usage guard (opt-in)

Set `AI_KIT_AUTONOMOUS_USAGE_GUARD_USD` (e.g. `140`) to pause a `drain`
run — or a `/loop`-scheduled sequence of `one` runs — once the active
5-hour block's *projected* spend reaches that dollar figure. See step
1a above for the check and the `usage-cap` stop condition for the
resume path. Requires `npx` (ccusage runs unpinned via
`npx -y ccusage@latest`) and Node, both already implied by `npx`
itself. Silent no-op when the env var is unset; adapted from
[agent-native/skills' `stay-within-limits`](https://github.com/BuilderIO/skills/blob/main/skills/stay-within-limits/SKILL.md)
(should-i-use verdict: Ignore the bundle, adopt this one pattern — see
`standards/external/plugins-excluded.json`).
