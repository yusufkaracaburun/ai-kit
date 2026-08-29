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

- **Repo / tool** — resolve the default branch first
  (`gh api repos/<owner>/<repo> --jq .default_branch`), then fetch the README
  from it. Never assume `main`: a repo whose default branch is a working branch
  will serve you a stale `main`, and you will assess a version nobody installs.
  Record the HEAD SHA; every later claim is about that commit. Note language,
  runtime, dependencies, licence.
  If the tool is already installed locally, diff the install against that SHA
  before assessing. They drift.
- **URL / article** — fetch it. Extract what the thing *is*, not the author's enthusiasm.
- **Pasted text** — read it as given.
- **Image** — read it visually; identify the tool, architecture, or screenshot shown.

If the candidate is ambiguous, ask one clarifying question before assessing —
never guess what it is.

**Check for a missing half.** If the candidate delegates part of its job to a
companion ("apply the X skill", "requires Y"), you were handed a system and
shown one piece. Ask for the rest before judging: a verdict on half a system is
a verdict on the wrong thing.

## Two tracks — check both when the candidate is tooling-shaped

Every candidate gets **Track B**. Only candidates whose value is "helps
AI-assisted coding" — a skill, plugin, MCP server, hook recipe, rule pack, or
companion tool — also get **Track A**. A business-logic dependency (an ORM, a
date library, a payment SDK) never gets Track A; ai-kit does not catalog those
— go straight to Track B for those.

**Track A — does ai-kit's own catalog have a gap?** ai-kit is not "wherever
this skill happens to be running" — it is a fixed, separate project, reachable
via `$AI_KIT_ROOT` from any repo (`bin/lib/ai-kit-root.sh` resolves it: env var
→ script location → `~/.config/ai-kit/root`). Its job is to equip *every other
project* at setup time, so a gap in its own catalogs
(`$AI_KIT_ROOT/standards/external/companions.json`, `plugins.json`,
`mcp-servers.json`, `hooks-patterns.json`, `subagents.json`) is worth fixing
even when the repo you're evaluating from doesn't personally need the
candidate. Run this **before** writing any "wrong repo, Ignore" verdict — grep
those files for the candidate's category, don't assume from memory. Two
independent questions, always both:

1. Is the *specific candidate* worth ai-kit adopting (licence, pricing,
   maturity — the six-part verdict below, applied to ai-kit as the project)?
2. Does ai-kit's catalog have a **gap** in that category that a *different*,
   better-fitting tool could fill — regardless of (1)'s answer? A candidate can
   fail (1) and still surface a real (2).

If `$AI_KIT_ROOT` cannot be resolved (a pure plugin-cache install with no
global clone), say so explicitly and skip Track A rather than silently
omitting it.

**Track B — does the current project (or you, personally) have the problem?**
Answer this before anything else on this track. If the project does not have
the problem, the candidate's licence, maturity and cohesion cost do not
matter, and the work you do on them is wasted.

Four questions, in order. Stop at the first one you cannot answer.

1. **Where does it hurt here?** Name the pain in this repo, not in general. If
   you cannot, the answer is Ignore and you are done.
2. **Where would it fire?** Give paths and counts from this repo, never
   categories. "This is a Laravel project so a Laravel tool fits" is true of
   every Laravel project. "21 Mail classes and 153 Blade templates carry
   customer-facing text" is true of this one.
3. **Who would run it?** A role that exists here. If the honest answer is "the
   person, in any repo", the scope is personal and the project should not carry
   it.
4. **What does it cost here?** Always-on context budget, install footprint,
   maintenance, and what it adds to the number of things a newcomer must learn.

**No verdict without a path or a count from this project.** A verdict built
only from the candidate's own README is a verdict about the candidate, not
about whether you should use it.

Read the repo to answer these: stack, size, brownfield versus greenfield, and
the tooling already in place (`package.json`, configs, `AGENTS.md` /
`CLAUDE.md`, installed skills). A candidate that fits a 300-file brownfield
repo can be pure noise in a 5-file greenfield one.

## The six-part verdict

When only Track B applies, produce one verdict. When both tracks apply, produce
**two** — labelled `Track A (ai-kit)` and `Track B (<this project>)` — they are
allowed to differ, and often should: Track A can Ignore while Track B Wires, or
the reverse.

Produce exactly these, as a compact structured block — tables over prose:

1. **What it is** — one paragraph. Problem it solves, runtime / dependencies,
   licence. Follow the licence to its source rather than stopping at the
   `LICENSE` file: packaged work often carries terms the wrapper does not
   restate, and a permissive header on copyleft-derived text is the failure you
   are looking for. Say which parts of the thing each licence covers.
2. **Status** — already present in this project? Overlaps with something already
   installed? Name the overlap explicitly.

   Check overlap by **derivation**, not only by name. Two things with different
   names can be the same material: grep the candidate's most distinctive
   artefacts (its word lists, its examples, its rule numbering) against the
   repo. A tool already inside under another name is the strongest Ignore there
   is, and the easiest to miss.

   Name the **scope** the value hangs on:

   | Scope | Value hangs on | Belongs |
   | ----- | -------------- | ------- |
   | project | this repo's stack or shape | per-project wiring, signal-gated |
   | person | whoever is working, in any repo | their own global install |
   | one-off | a task that ends | run it, wire nothing |

   Scope decides the verdict as often as category does. A great tool at the
   wrong scope is noise in every repo that did not ask for it.
3. **Added value** — the evidence from Track B's four questions (or Track A's
   gap-check), carried into the verdict: the paths, the counts, the role. If you cannot
   restate the value using something found in this repo, the value is generic
   marketing copy and you should say that instead.
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

## Record the verdict

A verdict that lives only in a chat transcript gets re-litigated. Before you
finish, write it where this project keeps decisions, and say where you put it.

- **Adopt** (vendor, wire, or pattern) — run the project's vetting bar first if
  it has one, and record the result. In ai-kit that is
  `standards/external/VETTING.md`, whose criteria include a licence check, a
  marketing-versus-code parity check, a maturity check, a pinned provenance
  SHA, and a security scan.
- **Ignore** — record the reason next to the candidate's name, not just the
  verdict. Six months on, "we looked at this and said no" is worth nothing;
  "this is `unslop` under another name, already in two of our files" stops the
  next person re-adopting it. In ai-kit that is
  `standards/external/plugins-excluded.json`.

When the project has no such place, say so and propose one rather than
inventing a file nobody will read.

**Track A verdicts are recorded in ai-kit's repo, not the current one.** If
you were invoked from a different project (via `$AI_KIT_ROOT`), a Track A
finding means editing files in a separate git repo with its own commit/push
lifecycle — confirm with the user before writing or committing there; do not
assume the same trust or push rights the current project's session has.

## Output discipline

- Lead with the verdict, then the evidence. The user wants the call, not a tour.
- Wrong-category candidates: say so plainly, even if the thing is excellent on
  its own terms.
- If you genuinely cannot decide without the user choosing scope (e.g. greenfield
  vs brownfield intent), ask one question — do not hedge the whole verdict.
