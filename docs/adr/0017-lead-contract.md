# ADR-0017: Lead contract, enforced by a hook

## Status

Accepted. Extends decision 3 of ADR-0014 (one lead per repo).

## Context

ADR-0014 made one session per repo the lead, and its 2026-09-29 amendment
said the lead dispatches rather than executes. That stayed a prose rule. Two
emeq-mobile lead sessions on 2026-10-09/10, both on Opus, show what the rule
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
2. **Enforcement is a hook, not more prose.** `workflow/hooks/lead-guard.sh`
   (PreToolUse, plugin-bundled) denies Edit/Write on repo files, mutating or
   heavy Bash, `mcp__pencil__execute` and Chrome write tools. The switch is
   the claim role: only a session whose claim says `role=lead` is gated.
   `agent_id` in the payload separates subagents, which pass. Memo and scratch
   paths pass (`~/.claude/`, `.agents/memory/`, `.planning/`, `/tmp`,
   `$TMPDIR`). The override is the role itself: `ai-kit-claim.sh set
   role=build`.
3. **The model split lives in settings, not agent frontmatter.** Kit agents
   run on the consumer's default. A frontmatter `model:` pin is allowed only
   with a `<!-- model-pin: <reason> -->` line, which `eval-structure.sh`
   checks. `explore` is the one pin (`sonnet`, a bounded read-only role).
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
  the user the exact `!` command once and stops asking.
- The Bash patterns have known gaps and one false deny (#199).

**Consensus with the live leads.** On 2026-10-10 the three live lead sessions
agreed on the edges:

- system-07: a single production command runs through the user's `!`, or
  goes to an agent with a stop-on-failure brief.
- Heavy runs: the claim is the lock. The lead broadcasts until every peer
  writes it into its claim. A shared gate script is #200.
- Verification by the lead means a few targeted reads (a path, a stat line,
  an export), never a diff review.
- emeq-app-df: merge permission is allowed in `settings.local.json`.

**Unproven**

- That a Fable-led session behaves better than an Opus-led one. Compare
  after one full Fable-led day.

**Open**

- #195 device-runner agent for simulator and emulator E2E.
- #196 committer agent.
- #197 PreCompact memo so peer answers and decisions survive compaction.
- #198 `sync-plugin-rules.sh` root resolution.
- #199 lead-guard pattern gaps.
- #200 `ai-kit-heavy.sh`, one machine-load gate.

## Reversibility

Cheap. Delete the `PreToolUse` entry from `workflow/hooks/hooks.json` and
`workflow/hooks/lead-guard.sh`, or set `role=build` in a single session. The
rule text reverts with one commit. No state outside the claims file the
role already lives in.
