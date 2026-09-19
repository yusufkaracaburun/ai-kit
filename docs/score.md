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

Before 2026-09-19 a "94/100" circulated in session memory. It had no rubric
in the repo and never moved across 65 releases; treat it as unmeasured.
