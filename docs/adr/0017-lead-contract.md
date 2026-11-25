# ADR-0017: Lead contract, enforced by a hook

## Status

Accepted. Extends decision 3 of ADR-0014 (one lead per repo).

Lead-guard tool list superseded by [ADR-0020](0020-paper-replaces-pencil.md), 2026-10-29.

## Context

ADR-0014 made one session per repo the lead, and its 2026-09-29 amendment
said the lead dispatches rather than executes. That stayed a prose rule. Two
mobile app B lead sessions on 2026-10-09/10, both on Opus, show what the rule
did not prevent:

- The lead did 104 Pen edits, 71 Chrome actions and the log redaction inline,
  with the rule loaded.
- The user had to ask "advies?" six times; the lead listed choices without a
  recommendation.
- The open-questions list was re-pasted for about ten turns instead of being
  carried as a count.
- An agent's false claim ("password in review notes") reached the user as
  fact, with no evidence checked.
- 4 of 6 review passes were written by the lead itself as "Lean already.
  Ship." instead of going through a reviewer.
- 55 of 57 spawns made no model choice.

The rule existed and was skipped. More prose would be skipped the same way.

## Decision

1. **The lead contract**, in `standards/rules/session-coordination.mini.md`,
   eight rules from the user:
   1. The lead never executes. Code, tests, builds, e2e, commits, design
      edits, browser and store-console flows, CLI release ops and log
      redaction go to a subagent.
   2. Every reply opens with a status block: Doing, Where, Needs-you, Advice.
   3. No claim travels without evidence: a path, a diff stat, exact output or
      a screenshot, or a few targeted reads by the lead. Otherwise it is
      marked unverified.
   4. The lead guards quality, it does not produce it: every agent diff goes
      through a reviewer subagent, checked against the project's design
      principles.
   5. The lead guards scope and picks the simpler design. Work past the brief
      becomes a follow-up issue.
   6. Every question carries advice.
   7. When an instruction would make the product worse, push back once with
      reasons, then execute the user's decision.
   8. The lead runs on the strongest model. Subagents default to Opus through
      `CLAUDE_CODE_SUBAGENT_MODEL`; a spawn names a different model only when
      the task fits it better.
      Amended 2026-10-11: the lead runs on the session default (Opus), not
      Fable. Fable runs inside `grill-with-docs`, `grill-me`, `to-issues`,
      `to-prd` and `diagnose` through their `model: fable` frontmatter. That
      key holds for the turn the skill loads; a multi-turn grill falls back to
      the session model from the next user prompt on.
      Amended 2026-10-30: `CLAUDE_CODE_SUBAGENT_MODEL` sets the default for
      general-purpose spawns (Sonnet). `builder`, `reviewer`, `designer`,
      `judge` and `verifier` pin Opus and `explore` pins Sonnet in their `model:`
      frontmatter, which beats the env var (Claude Code v2.1.251 and later).
      This supersedes the Opus-default sentence of item 8.
      Amended 2026-11-13: the lead runs on Opus, confirmed. The user sets
      the session default with `/model`; the kit never sets it. `qa-runner`
      pins Sonnet like `explore`. A subagent's model resolves in this order:
      the per-call `model`, then the agent's `model:` frontmatter, then
      `CLAUDE_CODE_SUBAGENT_MODEL`, then the main session's model (source:
      https://code.claude.com/docs/en/sub-agents.md). A plugin
      cannot set env, so `/ai:setup` writes `CLAUDE_CODE_SUBAGENT_MODEL` into
      the project's `.claude/settings.json` and `ai-kit-doctor.sh` warns when
      it is unset.
      Skill `model:` frontmatter (#270) is weaker than it looked. It applies
      for the current turn only, and Claude Code skips it without a message
      in auto mode when auto mode does not support that model, and when the
      model is outside an org `availableModels` allowlist (source:
      https://code.claude.com/docs/en/skills.md). That is the likely
      reason `npx ccusage@latest session` showed 0 Fable requests since
      2026-10-14; likely, untested. Until a run shows Fable requests there,
      treat every prep-skill turn as Opus. A Fable measurement needs the user
      to switch the session with `/model` for the run.
2. **Enforcement is a hook, not more prose.** `workflow/hooks/lead-guard.sh`
   (PreToolUse, plugin-bundled) denies Edit/Write on repo files, mutating or
   heavy Bash, `mcp__pencil__execute` and Chrome write tools. The switch is
   the claim role: only a session whose claim says `role=lead` is gated.
   `agent_id` in the payload separates subagents, which pass. Memo and scratch
   paths pass (`~/.claude/`, `.agents/memory/`, `.planning/`, `/tmp`,
   `$TMPDIR`). Amended 2026-11-23 (#336): Claude Code settings files
   (`.claude/settings.json`, `.claude/settings.local.json`) pass too, so the
   lead can apply a settings change the user asked for via `/update-config`.
   The override is the role itself: `ai-kit-claim.sh set role=build`.
3. **The model split lives in settings, not agent frontmatter.** Kit agents
   run on the consumer's default. A frontmatter `model:` pin is allowed only
   with a `<!-- model-pin: <reason> -->` line, which `eval-structure.sh`
   checks. `explore` is the one pin (`sonnet`, a bounded read-only role).
   Amended 2026-10-30: the env default is Sonnet for general-purpose spawns,
   so `builder`, `reviewer`, `designer` and `verifier` pin `opus`, each with a
   `model-pin` reason. `explore` keeps its `sonnet` pin; `qa-runner` has none.
   Amended 2026-11-13: `qa-runner` pins `sonnet` too, a read-only runner
   like `explore`. `structure.sh` asserts both pins.
4. **The rule body stays within its 14-line budget.** The contract replaced
   and merged bullets rather than adding a section.

## Consequences

**Positive**

- The lead's inline work is blocked at the tool call, where the prose rule
  was only read.
- The status block and evidence rule give the user one place to look and
  mark unverified claims as such.

**Negative**

- The lead cannot commit itself. A commit goes to an agent as a brief that
  names the paths and requires reading `git diff --staged` first. A
  dedicated committer agent is #196.
- No inline exceptions, not even `gh issue comment`. Small writes are batched
  into an agent that is already running.
- A classifier or permission denial is final for the session: the lead hands
  the user the exact `!` command once and stops asking. The command fits on
  one terminal line: a script is copied to a short `/tmp/ak-<name>.sh` first.
- The Bash patterns have known gaps and one false deny (#199).

**Consensus with the live leads.** On 2026-10-10 the three live lead sessions
agreed on the edges:

- system-07: a single production command runs through the user's `!`, or
  goes to an agent with a stop-on-failure brief.
- Heavy runs: the claim is the lock. The lead broadcasts until every peer
  writes it into its claim. A shared gate script is #200.
- Verification by the lead means a few targeted reads (a path, a stat line,
  an export), never a diff review.
- an app: merge permission is allowed in `settings.local.json`.

**Unproven**

- That a Fable-led session behaves better than an Opus-led one. Compare
  after one full Fable-led day.
  Amended 2026-10-11: the Fable-lead hypothesis was dropped untested. The
  open question is now whether Fable on the prep and debug skills beats Opus
  there, measured by the user on 2026-10-15.

**Open**

- #195 device-runner agent for simulator and emulator E2E.
- #196 committer agent.
- #197 PreCompact memo so peer answers and decisions survive compaction.
- #198 `sync-plugin-rules.sh` root resolution.
- #199 lead-guard pattern gaps.
- #200 `ai-kit-heavy.sh`, one machine-load gate.

## Amendment 2026-11-25 (grill lead rights)

The lead does coordination itself; execution stays denied. A replay of real
denied commands showed that most were memo writes, staging and issue comments,
and each one cost a subagent spawn. The Bash patterns also misread heredoc
bodies and `gh api -X GET`.

The lead may now:

- write through Bash (`>`, `>>`, sed -i, mkdir, touch, cp, rm) when every path
  is literal and inside the dirs Write already allows; `$HOME`, `$TMPDIR` and
  `~` resolve. A `cp` source may be outside. Recursive rm works in temp dirs
  only, and never on the temp dir itself.
- edit `CONTEXT.md`, `docs/decisions.md` and `docs/roadmap.md` at the root of
  its own repo or a worktree of it.
- `git add` existing literal files (no option, directory, glob or variable), run
  `git worktree remove` and `git branch -d` without force.
- `gh issue create`, `edit` and `comment`, without `--delete-last`.
- take Chrome screenshots and zooms.
- run `gh api` with method GET. A heredoc body is data unless a shell or an
  interpreter may read it.

Still denied: commit, push and every other git write, `gh pr` writes, closing,
deleting, reopening, transferring or locking an issue, releases, code, skills,
rules, ADRs, tests, builds, installs, process kills, Paper writes and every
other Chrome action. Commit and push stay with the ship brief until #346.

Every segment of a compound command is judged, and one denied segment denies
the call. `lib/lead-allow.pl` takes out only what it can prove, on top of the
shared shell mask. A segment it cannot prove, and a call it cannot read, falls
back to the old patterns. This ends "No inline exceptions, not even
`gh issue comment`" under Consequences.

Known limits: `gh api -f` or `-F` without `-X` posts and passes. A script
written to a temp dir can be run from it. The patterns still miss
`{ git push; }`, if/then and do bodies, `!`, time, env and eval prefixes, a
quoted `git`, xargs and `find -delete`.

## Reversibility

Cheap. Delete the `PreToolUse` entry from `workflow/hooks/hooks.json` and
`workflow/hooks/lead-guard.sh`, or set `role=build` in a single session. The
rule text reverts with one commit. No state outside the claims file the
role already lives in.
