---
name: validate-idea
description: Test a new product idea before anything is built. Sourced market research, an adversarial check of the numbers the verdict leans on, and one recorded exit (no-go, demand test, interview test, or go). Use when the user asks "toets dit idee", "heeft dit potentie", "marktonderzoek", "is this idea worth building", or wants a go/no-go on a product or clone idea. Not for features inside an existing product.
---

# validate-idea

Decide whether a new product idea deserves a build, using sourced numbers
instead of enthusiasm. Most ideas end in no-go. That is a cheap, good outcome.

Scope is new products only. A feature idea inside an existing app goes to
`/ai:grill-with-docs` or `/ai:to-prd`; say so and stop.

## Input

An idea description, optionally a competitor URL. If the target customer or
the country is unclear, ask one question before research starts.

## Process

### 1. Research

Spawn one research subagent (Claude Code: Task tool, `general-purpose`, it
needs web access). Hand it this brief, unchanged:

1. **Market size and trend.** Is the pain growing or shrinking? Last two
   years of data.
2. **Competitors.** Each with pricing and traction signals (reviews,
   traffic, team size, funding).
3. **The incumbent.** If the idea clones a product, research that product
   itself: pricing, reach, weak spots.
4. **Adjacent market.** The nearest neighbour segment and whether it changes
   the picture.
5. **International.** Is supply fragmented or concentrated per country, and
   who already serves each market?
6. **Legal risk.** Scraping, data protection, consumer law, licences.
7. **TAM / SAM / SOM.** Rough, with the arithmetic shown.

Rules for the subagent: every number carries a source URL; anything without
one is marked **(estimate)**; list what it could not verify.

Hosts without subagents: run the brief in the main thread.

### 2. Verify

Pick the 5 numbers the verdict leans on. Spawn one `verifier` per number, in
parallel (Task tool, `subagent_type=ai:verifier`). Claim: "<number> per
<source URL>"; evidence: the research excerpt. The verifier can fetch the URL
with `curl`. Add to the claim: "If curl cannot load the source (403, paywall,
JS-only page), answer UNTESTABLE, not REFUTED."

Map the verdict into the report: CONFIRMED → confirmed, REFUTED → refuted,
UNTESTABLE → unconfirmed. A refuted number leaves the verdict basis; re-derive
the exit without it.

### 3. Exit

End in exactly one exit:

| Exit | When | Must carry |
| ---- | ---- | ---------- |
| **No-go** | Saturated market, shrinking pain, legal block, or no wedge | The reason and its key number |
| **Demand test** | Pain is real, willingness to pay unknown | Budget, duration, stop threshold (e.g. "under 2% sign-up on EUR 300 ads in 14 days → no-go") |
| **Interview test** | Pain itself is unclear | Who, how many, the question that decides, stop threshold |
| **Go** | Confirmed numbers support a wedge | Hand-off to `/ai:grill-with-docs` in the target repo, plus a stop rule for the first release |

Every exit except no-go has a measurable stop rule. A stop rule without a
number is not a stop rule.

### 4. Competitor inventory (go only)

On go, inventory the main competitor's site as build input: sitemap, page
types, sections per page type. Skip it for every other exit.

### 5. Record

Ideas dir: `$IDEAS_DIR`, default `~/Sites/localhost/ideas/`. Create it if
missing.

- Write the report to `<slug>.md`: verdict first, then the research sections,
  the verifier table (number, source, status), the exit with its stop rule,
  and what could not be verified. If `<slug>.md` exists, write
  `<slug>-<YYYY-MM-DD>.md` instead.
- Append one row to `ideas.md` in the same dir. Create it with this header
  if missing:

```markdown
| Idea | Date | Verdict | Key number |
| ---- | ---- | ------- | ---------- |
```

Verdict is one of `no-go`, `demand test`, `interview test`, `go`. Key number
is the one figure that decided it, with its source.

## Output discipline

- Lead with the exit, then the evidence.
- No number without a URL or an **(estimate)** mark.
- Building the demand-test landing page is out of scope; name it as the next
  step and stop.
