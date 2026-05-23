---
name: should-i-use
description: Assess whether a tool, library, repo, URL, article, pasted text, or image is worth adopting in the current project. Produces a structured verdict — vendor, wire, adopt-as-pattern, or ignore — with status check, value, cohesion impact, and a recommendation. Use when the user shares a tool / repo / link / screenshot and asks "should I use this", "beoordeel dit", "wat vind je hiervan", "is dit iets voor ons", or whether something belongs in the project.
---

# should-i-use

Evaluate a candidate — a tool, library, repo, URL, article, pasted text, or image —
for adoption in the **current project**. Produce one structured verdict. Be a
critical advisor, not a hype amplifier: most candidates do not belong.

## Input

The candidate arrives in any form. Normalise it first:

- **Repo / tool** — fetch the README (`raw.githubusercontent.com/<owner>/<repo>/<branch>/README.md`);
  fall back to the repo page. Note language, runtime, dependencies, license.
- **URL / article** — fetch it. Extract what the thing *is*, not the author's enthusiasm.
- **Pasted text** — read it as given.
- **Image** — read it visually; identify the tool, architecture, or screenshot shown.

If the candidate is ambiguous, ask one clarifying question before assessing —
never guess what it is.

## Project context

Assess against *this* project, not in the abstract. Before judging:

- Read the repo — stack, size, brownfield vs greenfield, and what tooling already
  exists (`package.json`, configs, `AGENTS.md` / `CLAUDE.md`, installed skills).
- A candidate that fits a 300-file brownfield repo can be pure noise in a
  5-file greenfield one.

## The six-part verdict

Produce exactly these, as a compact structured block — tables over prose:

1. **What it is** — one paragraph. Problem it solves, runtime / dependencies, license.
2. **Status** — already present in this project? Overlaps with something already
   installed? Name the overlap explicitly.
3. **Added value** — concrete, tied to this project. If the value is generic
   marketing copy, say so.
4. **Decision** — pick one:

   | Verdict | When |
   | ------- | ---- |
   | **Vendor** | Rare. Only if the thing is small, license-clean, and must live in-repo. Carries maintenance + drift cost. |
   | **Wire** | Install from upstream; the project keeps only integration glue. Default for real external tools. |
   | **Adopt as pattern** | It is an idea or template, not a package — reimplement it natively and credit the source. |
   | **Ignore** | Wrong category, redundant with existing tooling, or value < cost. |

5. **Cohesion impact** — honest. More tools ≠ higher quality. A good tool in the
   wrong category *lowers* coherence. Flag scope-creep and accumulation.
6. **Recommendation** — one clear call, the next concrete step, and a question
   back to the user.

## Two reframes to apply

- **"Wire, don't vendor."** Owning someone else's source = licence + maintenance +
  version drift. Prefer integration glue that points at the upstream.
- **"Score" is not completeness.** Adding things does not raise a project's
  quality score. The score that matters: does *this* project get measurably
  better. Separate that from any imagined "more = better" metric.

## Output discipline

- Lead with the verdict, then the evidence. The user wants the call, not a tour.
- Wrong-category candidates: say so plainly, even if the thing is excellent on
  its own terms.
- If you genuinely cannot decide without the user choosing scope (e.g. greenfield
  vs brownfield intent), ask one question — do not hedge the whole verdict.
