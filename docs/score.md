# Quality score

One number for "how healthy is the kit", measured against a fixed rubric so it
can move. Re-measure after a structural change or a release batch, not per
commit. The floor is the last measured score: a change that would lower it
needs an explicit decision.

## Rubric

| Dimension | Weight | What counts |
| --- | --- | --- |
| Works | 30 | Suite green on both CI legs, behavioural cases over structural greps, release path exercised, no silent misreports of install state. |
| Structure | 20 | No committed mirrors of source, shared helpers used where three or more scripts need the same read, no wrapper families that are one parameterised script. |
| Catalog | 20 | Skills a user can pick between by description alone, no skill+command doubles, no boilerplate the hooks already do, per-session context load justified. |
| Docs honesty | 15 | README names only skills that exist, counts match the JSON they cite, roadmap stamp current, ADR status reflects what shipped. |
| Process | 15 | Release cadence per CONTRIBUTING, every open issue carries a P-label, nothing `needs-info` on the maintainer for more than a month. |

## Measurements

| Date | Score | Works | Structure | Catalog | Docs | Process | Basis |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-09-19 | 63 | 24 | 11 | 12 | 8 | 8 | Four read-only audits (bin, skills, tests, docs) plus a suite run at v1.94.2. Open findings: committed `workflow/` mirror, 25 inline marker reads, 6 audit extensions in the skill index, README stale in 4 places, 62 releases in 30 days. |
| 2026-09-19 (b) | 75 | 25 | 14 | 15 | 11 | 10 | After a085629 (detect bug), 30eca2f (11 zero-use skills + logging blocks gone), 5d3b44b (mirror collapsed, ADR-0016). Structure: 25 inline marker reads, wrapper families, detect-lib remain (#184, #188). Catalog: extensions in the index, grill/docs-sync/next doubles, setup 659 lines (#186). Works: release path untested (#189), gh failures read as absence (#187). Process: cadence rule written today, not yet observed. |
| 2026-09-21 | 78 | 26 | 16 | 15 | 11 | 10 | After 6bea36c (#184): the three silent marker misreports gone, one shared reader for the 12 marker sites. Structure still carries wrapper families and detect-lib (#188). Cadence observed for one release (2.0.1, two days after 2.0.0, after theorieplek ran the minor); too short to score. |

Before 2026-09-19 a "94/100" circulated in session memory. It had no rubric
in the repo and never moved across 65 releases; treat it as unmeasured.
