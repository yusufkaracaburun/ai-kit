# Workflow audit 2026-11-13 (kit v2.15.2)

Three read-only explore agents (chain, delivery, evidence) plus lead spot-checks. Paths are relative to the ai-kit repo unless a repo is named. Window: 2026-10-01 to 2026-11-13. Busiest repo: the repo with the most commits in the window (emeq-reui). Downstream repos: emeq-reui, emeq/system, planny-app-mobile, theorieplek, emeq-hub.

## Key figures

| Measure | Value | Previous | Source |
| ------- | ----- | -------- | ------ |
| Lead-inline sessions | 89 of 214 sessions executed inline; 37 escapes via role=build | first run | kit checkpoint memo 2026-10-30 |
| Owner-found defects per week, busiest repo (emeq-reui) | at least 4 in 11-10..11-13, plus a 28-finding consistency audit on 11-13 | first run | emeq-reui memory `feedback/*`, `project/consistency-audit-2026-11-13.md` |
| Review gate in effect | no in every repo (no ai-kit gate; personal ponytail gate: time-based, not tree-bound). emeq/system upgraded its marker to 2.17.0 on 2026-11-13, after this audit, so its 2.17.0 in Per repo is not a contradiction | first run | `workflow/hooks/` at v2.15.2 |
| Gate skips logged (main git-dir only) | not measured (no gate-log before v2.17.0) | first run | `workflow/hooks/review-gate.sh:45` |
| Fix-ish commit ratio since 2026-10-01 (upper bound) | system 81/178 (46%), emeq-hub 36/114 (32%), planny-app-mobile 34/117 (29%), emeq-reui 64/262 (24%), theorieplek 30/230 (13%) | first run | `b=$(git symbolic-ref --short refs/remotes/origin/HEAD \|\| echo master)`; `git log "$b" --no-merges --since=2026-10-01 --format=%s \| grep -ciE '^(fix\|revert)\|hotfix\|regress'` over `git log "$b" --no-merges --since=2026-10-01 --format=%s \| wc -l`, per repo (all on origin/master) |
| Open re-measurements | 3: correction-loop (due 10-02), Sonnet flip (due ~11-06), designer Sonnet trial | first run | kit memory |
| Open kit issues | 107; roadmap reconcile stamp 2026-10-27 | first run | `gh issue list`, `docs/roadmap.md:10` |
| docs/score.md | 78 on 2026-09-21, no row since (sessions quoted 87 and 90) | first run | `docs/score.md:24` |

## Per repo

| Repo | Path | Marker version | Lifecycle | Fix ratio |
| ---- | ---- | -------------- | --------- | --------- |
| emeq/system | `~/Sites/localhost/emeq/system` | 2.17.0 | production | 81/178 (46%) |
| emeq-hub | `~/Sites/localhost/github.com/emeq-hub` | 2.15.2 | production | 36/114 (32%) |
| planny-app-mobile | `~/Sites/localhost/github.com/planny-app-mobile` | 2.15.1 | production | 34/117 (29%) |
| emeq-reui | `~/Sites/localhost/emeq/emeq-reui` | 2.15.1 | development | 64/262 (24%) |
| theorieplek | `~/Sites/localhost/github.com/theorieplek` | 2.15.1 | development | 30/230 (13%) |

Marker values from `jq -r '.ai_kit_version, (.branches.lifecycle // "production")' .ai-kit-setup`, read 2026-11-13.

## Claim versus reality

- "Every agent diff goes through a reviewer before commit" (session-coordination:22): no ai-kit hook. Only the user's personal ponytail gate, which is time-based (20 min), not tied to HEAD or the diff, set regardless of verdict, and not set by `/ai:review` or the reviewer.
- Reviewer checks "pre-write, aposd, SOLID/DRY/YAGNI, scope equal to brief" (session-coordination:22): `reviewer.md:36-42` and `review/SKILL.md:24-30` list none of them. aposd, code-audit and refactoring are on-demand rules no worker sees.
- "Decisions in force in every brief" (session-coordination:31): no skill produces them.
- Lead runs on Opus (ADR-0017:52-56): user settings selected Fable 5.1. Decided 2026-11-13: Opus lead, the docs are right.
- `CLAUDE_CODE_SUBAGENT_MODEL` sets a Sonnet default (ADR-0017:57): set only in user settings; the kit never sets or checks it.
- Lead contract on by default: role=lead is never set automatically; sessions without peers get no session-coordination injection and lead-guard never fires.
- Lead-guard Bash gaps: `perl -pi`, `python3 -c`, `node -e`, `touch`, `mkdir`, `ln`, `git switch/tag/revert/apply/am`, `wrangler deploy`, `gplay`, `pytest`, `cargo`, `go test`. Pencil pattern stale (ADR-0020).
- Pre-write four gates: no chain skill or agent references them.
- "Nothing under rules is in your context" (builder:37 and others): path-scoped global rules do get injected into subagents on file touch; pathless ones do not.
- Project-emitted rules carry no description line (`claude-code.sh:20-28`), so description-based rule picking works for global rules only. The Cursor emitter drops `paths:` (`cursor.sh:18-19`).
- Bootstrap emits every universal rule per repo by default, against ADR-0015 decision 2.
- The kit's own `.claude/settings.json` wires stale hook copies without the marker gate; ADR-0018 item 4 says `/ai:upgrade` removes them.
- `peer-sessions-check.sh:83` (`sed -n '/^- /p'`) drops the yaml status-block template from the injected protocol.
- build- and search-delegation hooks fire inside subagents although `agent_id` is in the payload (lead-guard:37 already uses it).

## Chain breaks

1. to-prd (:160) and to-issues (:94) label ready-for-agent without the `## Agent Brief` comment triage requires (:86, :103) and autonomous reads (:134-147). Result: brief-thin exits.
2. triage treats the issue body as context, not spec (:22-23); to-issues puts the criteria in the body (:109).
3. autonomous hardcodes the label ready-for-agent (:92, :133); triage maps labels in `docs/agents/triage-labels.md` (:52).
4. Who reviews: session-coordination says the reviewer subagent; tdd:115-120 and autonomous:310 say a human.
5. Verifier scope: review verifies per blocker, autonomous only "criteria met", manual tdd then review never verifies criteria.
6. autonomous security exit tag (:214) is never emitted by its process (:167-168).
7. Builder brief drops Out of scope and Key interfaces (autonomous:155-157, builder:28-30, tdd:14).
8. grill-first phase table omits grill-me, validate-idea and design-to-code, and names deployment-on-demand at a wrong path (grill-first:33).
9. design-leads:29-30 "fix the frame first" versus design-to-code:56, :90, :92 "fix the code".
10. design-leads:84 one screen at a time versus design-to-code:129 batch in parallel.
11. No reviewer on designer diffs (design-to-code:60, :120).
12. Lead does the work itself: review Fix step (review:32), qa fix loop (qa:14, :23), diagnose phases 5-6 (diagnose:15, :107-127), triage reproduce (:81), to-prd Defer commit (:88-121), harvest (:60, :85-99), design-to-code evidence, masking and measuring (:46, :60, :83, :86), autonomous `git switch` and `gh pr create` (:152, :174).
13. tdd delegates only at three or more files (tdd:14).
14. Chat-only state: grill-me summary (:36), review verdict (:56), qa report (:56), retro (:42), tdd criteria "agreed in Planning", to-prd input is the conversation (:7), design-to-code round count (:90).
15. No release skill; `release-it.mini.md` is Nygard stability and `bin/release.sh` is kit-only.
16. "Tests green" is never re-checked after the builder (reviewer:106 must not run tests).
17. CONTEXT drift is checked for naming only (review:28); ADR and `architecture.md` drift go unchecked.
18. QA "Ship readiness" is consumed by nothing; DoR and DoD are unused by the chain; docs-sync and hygiene only nudge.
19. Dangling references: retro:10 `docs/agents/workflow.md` (only a template exists), builder.md:77 `refactoring.md`, session-coordination:20 `lead-guard.sh` without a path.
20. Stale text: autonomous "stable" (:8-9) and "spike-stage" (:328-335); "gstack" in review:8 and qa:8; "Commit directly to master (ai-kit policy)" in to-prd:121; "ai-kit issue #52" in tdd:117, autonomous:314, to-issues:26, triage:25; design-to-code:14 legacy tool, :55 Paper quota, :124 "Mobile is not designed in Paper yet"; ADR-0015 counts 23 rules (actual 21: 12 pathless, 9 path-scoped); ADR-0014:89-90 names `session-rules-inject.sh`, deleted by ADR-0015:56.

## Models

- Pins: builder, designer, judge, reviewer and verifier pin opus; explore pins sonnet; qa-runner is unpinned (`workflow/agents/*.md`).
- Fable: 0 of 58999 requests since 2026-10-14 went to Fable although the prep skills announce `model: fable` (#270, roadmap:166).
- Lead model: user settings selected Fable 5.1 while ADR-0017 says Opus; decided Opus.
- Model defaults changed in four releases since 2.4.0 (2.4.0 Opus, 2.5.1 Sonnet nudge, 2.6.0 Fable prep never effective, 2.14.0 Sonnet default plus Opus pins).
- Three model experiments without a closing measurement (see Key figures, open re-measurements).

## Test coverage gaps

- No test for the explore Sonnet pin, the qa-runner pin, agent prompt content or bare-name agent mentions.
- Skills without any test: audit-architecture-shadcn, audit-fix, clone-website, copywriter, doc-to-skill, exploratory-test, feedback, harvest, recommend-rules, retro, setup-gh-workflow, should-i-use.
- Hooks without a dedicated test: context-drift, post-skill-log, rename-detector.

## Patterns

1. Green gate or self-score while defects ship: planny-app-mobile screens scored 100/100 while bugs shipped (09-12, 09-16, 09-29 gate never ran); emeq-reui old judge rounds 64-79 against a bar of 90.
2. Owner finds the defect before the lead or a reviewer: emeq-reui 11-10, 11-11 ("erg slordig"), 11-12, 11-13; emeq/system three correction rounds on one PR (memo 2026-08-09).
3. Drift between sibling screens or modules: emeq-reui Productiebonnen lacked the Facturen conventions (11-11); 28-finding consistency audit (11-13); route restarted 10-31 over "drifts en gaps".
4. Reviewers check code, not rendered UI or behaviour: emeq-reui had 3 should-fix findings refuted by measurement; `reviewer.md:106` forbids running tests.
5. Lead executes inline or escapes via role=build: 89 of 214 sessions inline, 37 role=build escapes; emeq-hub feedback "do it yourself, lead" conflicts with never-execute.
6. Done claims without evidence: planny-app-mobile lead relayed agent scores 91/92 where its own pass gave about 78 (09-26, 10-02); emeq/system RED test that passed on base (2026-08-09).
7. Model experiments unmeasurable or unfinished: Fable 0 requests (#270); Sonnet flip and designer Sonnet trial without a result.
8. Planned re-checks never closed: correction-loop due 10-02, Sonnet flip due ~11-06, score.md without a row since 09-21.
9. Kit fix churn on the same surface: lead-guard 2.4.0, 2.4.1, 2.4.2 with #199 still open; Cursor skill links 2.10.1, 2.11.0, 2.12.0 on one day; Pencil detection fixed in 2.9.0 and removed in 2.13.0; lead-contract text changed in 8 releases.
10. Health checks that report OK while wrong: #149, #178, #187, #116, #263, #276.
11. Worktree or agent isolation sends builds to the wrong base: #269, #266, #267.

## Delta since previous audit

First run, no previous report. This file is the base the next run compares against.

### New
- Everything above.

### Resolved
- none (first run)

### Worse
- none (first run)

### Stable
- none (first run)

### Not measured
- Gate skips logged: no gate-log existed before v2.17.0.

## Recommended slices

Decisions 2026-11-13: hard gate on commit and push only, advisory elsewhere; Opus lead, Fable only in prep skills, fix #270 first; reviewer mandatory on design principles, spec conformance and sibling parity, rendered-UI gate deferred; seven separate PRs straight to master, tag per release. Rejected for now: automatic role=lead in sessions without peers, a release skill, Cursor hooks, a status-block hook.

Note added 2026-11-13 after the baseline: #278 shipped in def6b6c and #277 in 3da0654.

1. #276 fix(hooks): ponytail-review gate only reads the marker from the cwd repo. Why: the only gate checked the wrong repo. Evidence: Claim versus reality, first bullet.
2. #277 feat(hooks): review-gate denies commit/push without an APPROVE for the staged tree. Why: no repo has a review gate in effect. Evidence: Key figures, Patterns 1 and 2.
3. #278 feat(review): reviewer checks design principles, spec conformance and sibling parity; full Agent Brief to every worker. Why: reviewer checklist misses what the rules promise. Evidence: Claim versus reality, Chain breaks 1 and 7, Pattern 3.
4. #280 fix(models): honour model pins, pin qa-runner, ship the subagent default. Why: model choices are announced but not in effect. Evidence: Models, #270.
5. #281 fix(hooks): close lead-guard Bash gaps and fix rule delivery to workers and Cursor. Why: the lead contract leaks and workers miss rules. Evidence: Claim versus reality, Pattern 5.
6. #282 fix(workflow): close the chain breaks between to-issues, triage, autonomous, review, qa, diagnose and design-to-code. Why: hand-offs drop briefs and state. Evidence: Chain breaks 1 to 14.
7. #283 docs(quality): downstream-outcome score dimension, roadmap reconcile, stale docs sweep. Why: score and roadmap no longer reflect reality. Evidence: Key figures (score.md, roadmap), Chain breaks 19 and 20.
