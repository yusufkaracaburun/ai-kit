# ADR-0002: Two-layer skill eval, no LLM judge

## Status

Accepted (v1.1.0)

## Context

After v1.0.0 there was no way to tell whether a skill change improved behaviour or just changed it. Three obvious options:

1. **LLM-as-judge.** Run each skill against a corpus of prompts, score with another LLM call against a rubric. Industry-standard, slick.
2. **Pure structural checks.** Lint SKILL.md frontmatter, link integrity, length. Cheap, deterministic, but doesn't catch behaviour drift.
3. **Manual rubric ratings.** Dump prompt + skill to stdout, paste into Claude/Cursor, rate the output against a checklist by hand.

## Decision

Ship **structural + manual rubric**. Skip LLM-judge in v1.1.0.

The harness:

- `tests/bin/eval-structure.sh` runs 8 deterministic checks per SKILL.md and 3 per fixture. Hooked into CI. Catches *shape* drift (broken links, missing frontmatter, lost `## Process`).
- `bin/eval-skill.sh <skill> <scenario>` dumps a fixture + skill + rating template. The user pastes, runs in agent UI, scores. Results land in `tests/eval/results/` (gitignored — personal log).

## Consequences

**Positive**

- Zero API cost, zero non-determinism in CI.
- Trivial to add fixtures: one markdown file per scenario.
- The user sees the actual agent output, not a judge's verdict — surfaces drift the judge would miss.
- A new skill cannot land without passing structural checks.

**Negative**

- Behavioural eval is on the honour system. Nothing fails CI if the user never runs `eval-skill.sh`. Accepted: this is a solo kit; the discipline is on the user.
- No A/B comparison across skill versions.
- "Was the answer good?" requires reading the answer. We pay this cost on purpose — the LLM judge would skip it for us, badly.

**Revisit when**

- The kit gets a second active contributor (rubric scaling matters).
- 30+ fixtures exist and you need to diff a skill change across all of them.
- An LLM-judge model gets cheap and faithful enough that the trade is favourable. Today, it isn't.

## Revisited

**2026-07-26 (#119) — measuring the always-on `pre-write-discipline` rule. Reaffirmed: no.**

`ponytail` (DietrichGebert, Ignored — see `standards/external/plugins-excluded.json`) published an agentic benchmark showing the *same* discipline (an identical YAGNI ladder, safety guards preserved) cuts ~54% LOC on a real repo. That raised the question: should ai-kit measure its own `pre-write-discipline.mini.md` the same way? Two findings say no.

- **The deterministic harness cannot measure a behavioural rule's effect.** `eval-golden.sh` scores a response a human pastes in; it never runs the model. A rule-scoped golden with a `max_lines` rubric can document *one exemplar* of minimal output, but it cannot A/B rule-on vs rule-off, so it proves nothing about the rule's causal effect. Measuring that effect requires running the agent both ways — an LLM in the loop.
- **Running the agent A/B is exactly what this ADR declined**, one step worse than LLM-judge: real API cost *and* non-determinism *and* no CI gate. None of the three "Revisit when" triggers is met.

So the effect is measurable only by reversing this ADR, and the evidence for the rule's *direction* already exists externally (ponytail's controlled study of the identical ladder). Reproducing it on ai-kit's phrasing spends real money to re-derive a known result and still yields no CI regression gate (a one-time number can't run in CI). Declined — `pre-write-discipline`'s value rests on that external evidence plus review, not a native benchmark.

Revisit under the same trigger as LLM-judge: when agent-run A/B benchmarking becomes cheap and deterministic enough to gate CI. If a manual spot-check is ever wanted before then, it fits the existing manual-rubric layer (a fixture + `max_lines` golden) on the honour system, like every other `eval-skill.sh` rating — no new harness.

**2026-08-24 (#137) — `claude plugin eval` measured against the trigger. Half met: adopted as advisory layer, not a gate.**

First-party `claude plugin eval` (CLI 2.1.241, early access) was run against a 3-case suite in `workflow/evals/` (grill-me, phase, copywriter — fixtures reused from `tests/eval/prompts/`, one grader per fixture-`expects` line). Measured, five suite invocations (plus a zero-cost validation smoke run):

- **Cheap: yes.** ≈ $2.5 token value per full suite invocation (3 cases × 3 runs × with/without ablation, sonnet agent + haiku judge); $0 cash on a Max subscription. The cost objection this ADR was built on no longer holds at release-time frequency.
- **Deterministic enough for a hard gate: no.** Free graders (regex/`tool_used`) are fully deterministic given the output, and judge votes are near-unanimous — but agent-output variance puts case-score spread at 0.11–0.40 across identical invocations. Default `--threshold 1.0` never passes; a hard CI gate would flake. Early-access gating also blocks headless CI today.
- **Discriminates: yes.** Ablation delta +0.29…+0.52 on every case (skill-fired 24/24), and the first runs surfaced three real findings the deterministic layer cannot see (copywriter §-citation drift, a rule-of-three miss, phase's `CLAUDE_PLUGIN_ROOT` env-dependence).

Decision: the two-layer model stays — structural checks remain the only hard CI gate. `claude plugin eval` replaces the honour-system half of the manual layer as an **advisory behavioural pass at release time**: run the suite, read the report + ablation delta, treat regressions as review input. Hard-gating (per-case calibrated thresholds) is re-evaluated when the feature reaches GA. Full numbers: #137.
