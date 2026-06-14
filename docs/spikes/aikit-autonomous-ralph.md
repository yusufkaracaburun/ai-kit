# Spike — `autonomous` (Ralph pattern)

> **Status:** PROMOTED 2026-05-26. Skill is stable after multiple
> real-queue drains in `ai-kit` + `naschool`. Document preserved as
> historical research record; see `workflow/skills/autonomous/SKILL.md`
> for the live contract. Tracks
> [#17](https://github.com/yusufkaracaburun/ai-kit/issues/17).
> Original date: 2026-05-23.

## Question

Does the Geoffrey-Huntley / `snarktank/ralph` autonomous-loop mechanic
(fresh-instance-per-story + persistent `progress.txt` + git-log-as-memory)
fit ai-kit's deliberate-HITL lifecycle, and if so, how should it ship?

## Mechanic, recapped

Ralph's invariants:

1. **One issue per agent context.** Long-running contexts drift; fresh
   contexts don't accumulate cruft.
2. **State lives on disk, not in-context.** `progress.txt` + git log are
   the durable memory. The next iteration reads them cold.
3. **Loop until queue empty or gate.** No interactive prompts mid-loop;
   any uncertainty short-circuits to a human gate (uncommitted PR, open
   question, failing test).

## Mapping to ai-kit primitives

| Ralph element | ai-kit mapping |
| ------------- | -------------- |
| Story queue | `gh issue list --label ready-for-agent` (already produced by `triage`) |
| Per-story spec | Agent Brief comment (already structured per `triage/AGENT-BRIEF.md`) |
| Implement | `tdd` invocation |
| Verify | `review` invocation |
| Commit + close | `ship` invocation (PR + merge per project policy) |
| Persistent log | `.ai-kit/autonomous/progress.txt` |
| Fresh instance | `Task` tool with a dedicated `autonomous-runner` subagent, OR `/loop` scheduling fresh top-level invocations |

The queue + per-story spec already exist as first-class ai-kit
concepts. Ralph's contribution is the **discipline of cold-start
iteration** — not new primitives.

## Three open design questions from the issue

### Q1. Sibling skill, flag on existing skill, or separate plugin?

**Verdict: sibling skill.**

- *Flag on existing skill* — fragile. Which skill carries the flag?
  `tdd --autonomous` is wrong (TDD is the inner loop, not the
  orchestrator). A standalone skill is the natural fit because the
  unit of work is "drain the queue", not "implement one feature".
- *Separate plugin* — overkill for one skill. Plugin distribution
  exists for cross-cutting bundles. Revisit only if the autonomous
  layer grows to ≥3 skills (e.g., `autonomous-status`,
  `autonomous-resume`, `autonomous-cancel`).
- *Sibling skill* — matches the existing pattern. Lives at
  `workflow/skills/autonomous/SKILL.md`. Logs via
  `bin/log-skill.sh` like every other skill.

### Q2. Conflict with `/loop`?

**Verdict: complementary, not competing.**

- `/loop` is a **scheduler** — repeats a single prompt or slash command
  on an interval (or self-paced) with cache-aware wakeups.
- `autonomous` is a **worker** — picks one issue, runs the full
  TDD → review → ship sequence, commits state to `progress.txt`,
  exits.

Two valid composition patterns:

1. **Manual driver:** user invokes `/ai:autonomous` once per
   iteration. Skill exits after one issue; user re-invokes when ready.
2. **Scheduled driver:** user invokes
   `/loop 600s /ai:autonomous` — `/loop` handles the scheduling +
   cache-warm wakeups; the skill handles one issue per fire and exits
   cleanly. The fresh-instance invariant is preserved because each
   `/loop` fire is a fresh slash-command invocation.

The skill **must not** internally call `ScheduleWakeup` or chain
itself — that would tangle scheduler/worker concerns and break the
fresh-context invariant.

### Q3. Does the mechanic work on a real ai-kit issue queue?

**Smoke-tested:** `gh issue list --label ready-for-agent --json number,title`
on this repo returns 0 results today (open issues are `#15` brainstorm
and `#17` this spike — neither is `ready-for-agent`). The queue
mechanic works; the queue is just empty. Real validation requires
`triage`'ing a small issue to `ready-for-agent` and watching the
loop drain it. Defer that to the first production-use spike, not this
design spike.

## Stop conditions (must be explicit)

The skill exits — never silently continues — on any of:

| Trigger | Reason |
| ------- | ------ |
| Queue empty | Normal termination |
| Agent Brief missing or thin | Cannot proceed cold without a contract |
| `tdd` cycle introduces a failing test that won't go green in ≤3 attempts | Tighter than human TDD because there is no human to ask "is this the right test?" |
| `review` returns `REQUEST CHANGES` with any **Blocker** | Hand back to human |
| Security finding at `high` or above | Hand back to human |
| Push/merge would require force-push or conflict resolution | Hand back to human |
| `max_iterations` reached (config, default 5) | Safety cap; user re-invokes |

Every exit writes a one-line entry to `progress.txt` with the reason.

## `progress.txt` schema

Append-only, one event per line. Format:

```
<ISO-8601 timestamp>\t<issue#>\t<event>\t<detail>
```

Events: `pick`, `brief-ok`, `tdd-green`, `review-pass`, `ship-ok`,
`exit-empty`, `exit-gate`, `exit-error`. Trivially `grep`-able for
the next iteration to learn what already happened.

`git log` carries the *code* memory; `progress.txt` carries the
*orchestration* memory.

## Trust model

Same posture as `/ai:recommend-rules` and `/ai:recommend-tools`:
**never auto-merge to `main`/`master`.** The skill opens a PR; the
project's existing merge policy (CI green, human approval, branch
protection) is the actual safety net. ai-kit does not bypass it.

For the spike, the skill draft documents `dry-run` as the default
mode — surfaces what *would* happen across the queue without
touching git.

## Decision matrix vs. just shipping `tdd` in a loop

| Concern | `/loop /ai:tdd` (status quo) | `autonomous` |
| ------- | ------------------------------- | ------------------- |
| Picks next issue automatically | No | Yes |
| Persists cross-iteration state | No (context drift) | Yes (`progress.txt`) |
| Explicit human-gate triggers | No | Yes |
| Fresh-context invariant | Only if user `/clear`s between fires | Built in |
| Integrates with `triage` queue | No | Yes |

The status quo *can't* drain a backlog unsupervised; the spike
artifact can.

## Recommendation

Ship a **draft** of `workflow/skills/autonomous/SKILL.md` with:

- `dry-run` as default mode (logs what it would do, touches nothing)
- explicit stop conditions
- `progress.txt` schema documented
- complementary-not-competing note re `/loop`

Do **not** wire it into the plugin or `setup` until the first
real-queue drain succeeds end-to-end. Treat as opt-in, hand-installed
during the validation period.

## Validation walkthrough (2026-05-23)

Walked the contract by triaging issue #18 (`Add bin/autonomous-queue.sh`)
to `ready-for-agent`, drafting the agent brief inline, then building the
helper end-to-end. Findings:

### Worked

- **Queue read** — `gh issue list --label ready-for-agent --json ...`
  returned #18 cleanly; `bin/autonomous-queue.sh next` printed
  `18<TAB>Add bin/autonomous-queue.sh: read ready-for-agent queue (validation for spike #17)`
  on first invocation.
- **Empty-queue contract** — empty stdout + exit 0 (plain) and `null`
  + exit 0 (`--json`) both work; callers can detect with `[ -z "$out" ]`
  or `[ "$out" = "null" ]`.
- **`gh` stub via `PATH` override** — turned out to be the right test
  isolation pattern. Nine regression tests in `tests/bin/run-tests.sh`
  cover empty/populated/bad-JSON/missing-gh/bad-arg.

### Surprised

1. **Repo lacked the `ready-for-agent` label entirely.** Had to
   `gh label create ready-for-agent --color 0e8a16` before triaging.
   The autonomous skill must document this precondition, and ideally
   `triage` (or `setup`) should idempotently ensure the
   triage label set exists.
2. **Skill auto-distributes via bootstrap.** Anything in
   `workflow/skills/*/SKILL.md` gets symlinked by
   `bootstrap-project.sh:merge_skills`. A spike-status skill currently
   has no opt-out — users who pull `master` get `autonomous`
   listed even though the contract says "do not use until validated".
   Either move spike skills to `experiments/` (and skip the symlink
   sweep), or add a `status: spike` frontmatter field + bootstrap
   exclusion. **Tracked separately as a follow-up.**
3. **`resolve_ai_kit_root` resolves to the *global* install** when
   `AI_KIT_ROOT` is unset and `~/.config/ai-kit/root` points at
   `~/.local/share/ai-kit/`. Tests that invoke `bin/*.sh` from the
   working repo needed an explicit `export AI_KIT_ROOT="$AIKIT"`
   to pin the resolver to the local tree. The autonomous loop must
   do the same per-project — otherwise it would drain *the global
   install's* queue, not the project the user is sitting in.
4. **Drift tests left the working tree tampered.** Pre-existing
   `sync-plugin-version` / `sync-plugin-hooks` drift tests append
   `# tampered` lines and set `version=0.0.0-drift`, but cleanup did
   not always run, so back-to-back test invocations dirty the tree.
   Not autonomous-related, but a real friction for any AFK loop that
   runs the test suite — surface as its own bug.
5. **No PR step on ai-kit-the-repo.** The contract says "open PR,
   never auto-merge", but ai-kit's local policy is direct-to-master
   (per `feedback_no_pr_ceremony`). Both flows are valid; the contract
   needs a per-project switch (read merge policy from project config /
   memory rather than hard-coding PR).

### Verdict on promotion

The **mechanic is sound** — fresh-context iteration via stable disk
state (`progress.txt` + `gh` queue) produced working code on the
first try. The **contract needs three additions** before promotion:

- precondition check that the triage labels exist
- explicit `AI_KIT_ROOT` resolution per project
- per-project merge-policy detection (PR vs direct)

Status remains **spike** until those three land. Then it can be wired
into `setup` as opt-in.

### Artifact produced

- `bin/autonomous-queue.sh` — the queue-read helper (77 lines bash +
  inline python).
- `tests/bin/run-tests.sh` — 9 regression tests under a new
  `=== bin/autonomous-queue.sh ===` section, stubbed `gh` via
  `PATH` override (no live network).
- This findings section.

## Research input: OpenHands patterns (2026-05-26)

Targeted reading of `All-Hands-AI/OpenHands` `main` branch focused on
the three spike contract gaps (triage-labels precondition, per-project
`AI_KIT_ROOT` pinning, per-project merge-policy detection). Source files
inspected via the GitHub Contents API + raw blob fetches; quoted code is
verbatim from the upstream paths listed.

| # | Pattern | Source path | Spike gap addressed | Adoption decision | Reasoning |
| - | ------- | ----------- | ------------------- | ----------------- | --------- |
| P1 | **Sandbox-per-session** — one Docker container per sandbox, identified by `SESSION_API_KEY_VARIABLE` env var; `pause_old_sandboxes()` evicts above `max_num_sandboxes` | `openhands/app_server/sandbox/docker_sandbox_service.py` | None (cross-cuts cwd isolation) | **Reject** | ADR-0006 scopes ai-kit to Claude Code + Cursor — ai-kit does not own a runtime. Our fresh-context invariant is already enforced via `/loop` scheduling and per-issue cwd discipline in step 0. Bringing a Docker sandbox layer in would violate ADR-0006's host-scope decision. |
| P2 | **Conversation status state machine** — `WORKING → WAITING_FOR_SANDBOX → PREPARING_REPOSITORY → RUNNING_SETUP_SCRIPT → SETTING_UP_GIT_HOOKS → SETTING_UP_SKILLS → STARTING_CONVERSATION → READY`, async-generator yields status updates until terminal `READY|ERROR` | `openhands/app_server/app_conversation/app_conversation_service.py` | **Gap #1** (triage labels precondition) — generalises to "pre-flight phases gate the run" | **Adopt-as-pattern** | Formalise the existing `progress.txt` event vocabulary into a Ralph-flavoured status enum: `preflight → pick → brief-ok → cycle-attempt → cycle-done → tdd-green → review-pass → ship-ok | exit-*`. The preflight phase carries the triage-labels-exist + `AI_KIT_ROOT`-pinned + merge-policy-detected checks. Keep flat — no async-generator framework. |
| P3 | **Filesystem-backed event store keyed by conversation id** — `FilesystemEventService` is the default; multi-backend (filesystem/database) interface; event-filtering + streaming endpoints | `openhands/app_server/event/...` (README + module) | Gap #3 (state persistence between iterations) — already covered | **Reject** | `progress.txt` is the deliberate Ralph-style minimal-state surface. Adding an event-store abstraction would invert the design (state-as-text vs. state-as-DB) for no win — Ralph's whole point is that cold-readable text is good enough. Re-evaluate only if `progress.txt` proves insufficient (tracked under Follow-ups). |
| P4 | **Workspace-volume per sandbox** — `openhands-workspace-{sandbox_id}` named Docker volume holds the per-conversation working tree; survives container restart | `openhands/app_server/sandbox/docker_sandbox_service.py` | Gap #2 (per-project `AI_KIT_ROOT` pinning) — analogous problem | **Adopt-with-modification** | We don't ship volumes — but the principle (per-conversation working-state has its own root, pinned at creation) maps to **per-conversation `target_worktree`**. The skill already takes this from the Agent Brief; the modification is to make `AI_KIT_ROOT` the brief's `ai_kit_root:` key when present, falling back to `${HOME}/.config/ai-kit/root` only when omitted. Matches existing trust-model "never operate outside the brief's declared worktree". |
| P5 | **No autonomous picker in core** — `app_conversation_start_task_service.py` is search/save/delete only; "no built-in queue or automatic work-picking mechanism"; the caller orchestrates | `openhands/app_server/app_conversation/app_conversation_start_task_service.py` | Gap #3 (merge policy detection) — confirms approach | **Adopt-with-modification** | OpenHands deliberately leaves picker + merge logic to the caller; ai-kit does the same. Our picker (`gh issue list --label ready-for-agent`) is the caller-side. Per-project merge policy detection lands as a preflight step that reads project config (e.g. `.ai-kit-setup` `branches.merge_policy` or `git config ai-kit.merge-policy`) and refuses to run a `ship` step whose mode (PR vs. direct-to-master) doesn't match. Default `pr`; ai-kit-the-repo + similar solo projects override to `direct`. |
| P6 | **Pre-flight phases as first-class** — `SETTING_UP_GIT_HOOKS` + `SETTING_UP_SKILLS` are explicit status states, not implicit setup inside `STARTING_CONVERSATION` | `openhands/app_server/app_conversation/app_conversation_service.py` | Gap #1 (precondition gates) — formalisation | **Adopt-as-pattern** | The autonomous skill already runs step-0 checks (cwd + branch + heartbeat); P6 says **name them as events**. Promote step-0's checks to explicit `preflight-*` events in `progress.txt` (`preflight-cwd-ok`, `preflight-triage-labels-ok`, `preflight-merge-policy-detected:<pr|direct>`, `preflight-ai-kit-root-pinned:<path>`) — same cost as the silent checks, big cold-read win for the next iteration. |

### Adopted-pattern landings (this PR)

- **P2 status enum.** `workflow/skills/autonomous/SKILL.md` `progress.txt schema` section names a `preflight` event lifecycle alongside the existing pick/brief-ok/cycle/exit events.
- **P4 modification — brief carries `ai_kit_root`.** SKILL.md step 0 parsing now looks for `ai_kit_root:` in the Agent Brief and pins `AI_KIT_ROOT` to it for the run; falls back to `${HOME}/.config/ai-kit/root` when absent (current behaviour).
- **P5 modification — merge policy.** SKILL.md step 0 detects merge policy from `.ai-kit-setup` `branches.merge_policy` (when present), else from `git config --get ai-kit.merge-policy`, else default `pr`. New `exit-gate merge-policy-mismatch` for when the brief asks for one mode and project config says another.
- **P6 preflight events.** SKILL.md `progress.txt schema` section adds the `preflight-*` event family with the four explicit checks.

### Rejected-pattern notes

- **P1 sandbox.** Out of host scope per ADR-0006; revisit only if ai-kit ever expands beyond Claude Code + Cursor.
- **P3 event store.** Reconsider if `progress.txt` ever needs multi-reader / streaming consumption; today's single-cold-reader contract makes text-on-disk the right minimum.

### What this leaves open

- **Actual contract-gap closure in code** (the four preflight events implemented as bash + the merge-policy detection wired into step 0) lands in subsequent issues; this research arc + SKILL.md draft is the **doc-only** scope of #21. Promotion of `autonomous` from spike → released still requires those three implementation issues to close per the original spike verdict (above).

## External validation

Addy Osmani, *Loop Engineering* (https://addyosmani.com/blog/loop-engineering/,
2026) — independent confirmation that this design is now mainstream practice, not
a solo bet. The essay's six primitives map 1:1 onto the surfaces above:
automations, worktrees, skills, MCP connectors, ideate≠verify sub-agents, and
external state — every one already shipped in ai-kit or the Claude Code harness
(see the [primitives mapping](#mapping-to-ai-kit-primitives)). It also names the
core risk this spike's [trust model](#trust-model) guards against: **comprehension
debt** / **cognitive surrender** — the loop runs faster than a human can verify,
so the verification burden must stay explicitly human. `/ai:should-i-use` verdict
on the article was **Ignore** (essay, not a tool — nothing to wire); this cite is
the salvage.

## Follow-ups (out of scope for spike)

- `bin/autonomous.sh` helper (queue read, progress-log append) once
  the skill stabilises.
- Parallel iteration (Ralph's `--parallel` flag) — explicitly out of
  scope per #17.
- `autonomous-resume` companion skill — only if `progress.txt`
  proves insufficient for context recovery after long pauses.
- **Implement the preflight events** named in the P6 row above as
  follow-up issues — one per check (triage labels exist, merge policy
  detected, AI_KIT_ROOT pinned, cwd ok).
