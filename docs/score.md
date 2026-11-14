# Quality score

One number for "how healthy is the kit", measured against a fixed rubric so it
can move. Re-measure after a structural change or a release batch, not per
commit. The floor is the last measured score: a change that would lower it
needs an explicit decision.

## Rubric

| Dimension | Weight | What counts |
| --- | --- | --- |
| Works | 26 | Suite green on both CI legs, behavioural cases over structural greps, release path exercised, no silent misreports of install state. |
| Structure | 17 | No committed mirrors of source, shared helpers used where three or more scripts need the same read, no wrapper families that are one parameterised script. |
| Catalog | 17 | Skills a user can pick between by description alone, no skill+command doubles, no boilerplate the hooks already do, per-session context load justified. |
| Docs honesty | 13 | README names only skills that exist, counts match the JSON they cite, roadmap stamp current, ADR status reflects what shipped. |
| Process | 12 | Release cadence per CONTRIBUTING, every open issue carries a P-label, nothing `needs-info` on the maintainer for more than a month. |
| Downstream outcomes | 15 | What the kit does to the apps that use it: owner-found defects per week in the busiest app repo (target at most 1), corrections per 100 prompts, review gate in effect in every downstream repo with no logged skips. |

The weights changed on 2026-11-14, when Downstream outcomes took 15 points from
the other five. Rows before that date use the old weights (30, 20, 20, 15, 15).

## Downstream outcomes baseline

| Measure | Baseline | Source |
| --- | --- | --- |
| Owner-found defects per week, busiest repo | emeq-reui: at least 4 in 2026-11-10..11-13 (11-10, 11-11, 11-12, 11-13), plus a 28-finding consistency audit on 11-13 | `docs/audits/workflow-audit-2026-11-13.md` Key figures and Pattern 2; emeq-reui memory `feedback/*`, `project/consistency-audit-2026-11-13.md` |
| Corrections per 100 prompts | not measured: the correction-loop re-check due 2026-10-02 never ran | `docs/audits/workflow-audit-2026-11-13.md` Key figures, open re-measurements |
| Review gate in effect, per repo | wired in all five (plugin ≥2.17.0, `review_gate_hook` at default), not yet observed: 0 approvals and 0 skips recorded; emeq-reui made 8 commits after the install with no `review-ok`, likely from a session started before the plugin update | read 2026-11-14: installed plugin 2.17.0 wires `review-gate`; every marker leaves `branches.review_gate_hook` at its default (wired); no `ai-kit/review-ok` or `ai-kit/gate-log` in any main git-dir; emeq-reui `git log` |

The gate only logs skips, so there is no count of reviewed commits and no
share to report. The gate shipped in 2.17.0 (2026-11-13); before that no
repo had one. No score row uses this dimension yet: the score needs all three
measures, and corrections per 100 prompts has no value.

## Measurements

| Date | Score | Works | Structure | Catalog | Docs | Process | Basis |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-09-19 | 63 | 24 | 11 | 12 | 8 | 8 | Four read-only audits (bin, skills, tests, docs) plus a suite run at v1.94.2. Open findings: committed `workflow/` mirror, 25 inline marker reads, 6 audit extensions in the skill index, README stale in 4 places, 62 releases in 30 days. |
| 2026-09-19 (b) | 75 | 25 | 14 | 15 | 11 | 10 | After a085629 (detect bug), 30eca2f (11 zero-use skills + logging blocks gone), 5d3b44b (mirror collapsed, ADR-0016). Structure: 25 inline marker reads, wrapper families, detect-lib remain (#184, #188). Catalog: extensions in the index, grill/docs-sync/next doubles, setup 659 lines (#186). Works: release path untested (#189), gh failures read as absence (#187). Process: cadence rule written today, not yet observed. |
| 2026-09-21 | 78 | 26 | 16 | 15 | 11 | 10 | After 6bea36c (#184): the three silent marker misreports gone, one shared reader for the 12 marker sites. Structure still carries wrapper families and detect-lib (#188). Cadence observed for one release (2.0.1, two days after 2.0.0, after theorieplek ran the minor); too short to score. |

Before 2026-09-19 a "94/100" circulated in session memory. It had no rubric
in the repo and never moved across 65 releases; treat it as unmeasured.
