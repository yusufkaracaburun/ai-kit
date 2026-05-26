# Promotion quorum — default-on threshold for `recommend-*` skills

Defines the evidence bar that a community rule / tool / pattern must clear
before `/ai:recommend-rules` and `/ai:recommend-tools` mark it as **default-on**
in their surfaced output. Sibling to `standards/external/VETTING.md`, which
governs catalog entries under `standards/external/`. The quorum here governs
what the recommend-* skills present to the user as a default — different
surface, same drift class.

## Rule

A community rule / tool / pattern reaches **default-on tier** in `recommend-*`
output only when **at least two independent sources** document the same usage.

- **Independent** = different author/org, different publication, different
  timeframe. Three blog posts citing each other do not satisfy the bar. A
  framework's own docs + a third-party guide that quotes them is borderline:
  the third-party must add concrete usage detail beyond what the official
  docs contain; pure rewording does not count.
- **Single-source items may still be surfaced** — they are labeled
  `single-source` in the output and **never** default-recommended. Users can
  still pick them; the skill must not pre-select them.
- **Source recency.** Sources older than 24 months without a recent
  re-publication or active maintenance count for half a vote — two such
  sources together still satisfy the quorum, but pair them with a freshness
  note in the output.

## What counts as a source

Eligible:

- Official framework / library documentation.
- Maintained third-party guides, books, or talks (last update ≤ 24 months,
  with the freshness rule above).
- Open-source repos using the pattern in production (≥ 50 stars OR a
  recognised author/org; star count alone is a weak signal).

Not eligible:

- Single blog post, tweet, or gist without independent corroboration.
- Three posts that cite one shared origin — that is one source with three
  amplifications.
- LLM-generated tutorials or "awesome lists" that do not show actual usage.

## Output annotation contract

Both `/ai:recommend-rules` and `/ai:recommend-tools` MUST surface the source
count in their user-visible output, using one of two annotations:

- `(sources: N/M verified)` for default-on items, where `N ≥ 2` independent
  sources are documented and `M ≥ N` is the total candidate-source count
  considered. Example: `(sources: 2/2 verified)`.
- `(sources: 1 — preview only)` for single-source items. The `preview only`
  qualifier is the user-facing signal that this entry is below the
  default-on bar.

The annotation appears inline with the candidate's name in the surfaced
list, e.g.:

```
laravel-pint-strict-rules  (sources: 2/2 verified)
  reason: laravel framework match; weight=high
nextjs-app-router-flat-routes  (sources: 1 — preview only)
  reason: nextjs framework match; weight=medium
```

The skill MUST NOT pre-select or auto-enable `preview only` items.

## Operational notes

- Skills enforce the quorum at the **surface** layer — the catalog itself
  may store single-source items as long as the skill output honours the
  annotation. Catalog provenance (source_url, pinned_sha) is the input;
  the quorum gate is the gate around what is recommended by default.
- This document changes nothing about `VETTING.md`'s threshold for landing
  in `standards/external/*` JSON catalogs. A catalog entry can exist with
  one source and still be surfaced by the skill — just never as default-on
  until a second independent source lands.
- Re-audit existing recommend-* output against this bar opportunistically;
  do not block on a one-shot sweep. The bar is forward-looking from the
  date this document landed.

## Sibling — feedback-rule promotion (manual)

Distinct from the recommend-* quorum above: when a project-local feedback
memory (`.agents/memory/feedback/*.md`) generalises across projects, it can
be promoted to a canonical feedback-rule under `standards/rules/feedback/`.
See [`docs/adr/0007-canonical-feedback-rules.md`](../docs/adr/0007-canonical-feedback-rules.md)
for the layer itself.

The promotion flow is currently manual:

1. **Observe**: an LLM session notices that a project's feedback memory
   describes an agent-/workflow-general pattern, not a stack/domain/product
   specific one.
2. **Capture**: append the lesson to `~/.claude/ai-kit-lessons.md` with the
   five-section template (context / what went wrong / root cause / local
   mitigation / ai-kit suggestion).
3. **File**: open a GH issue on `yusufkaracaburun/ai-kit` with the
   `primitive:rule` label, copy-pasting the lesson entry as the body.
4. **Curate**: during the next release, rewrite the rule in project-agnostic
   form and land it as `standards/rules/feedback/<slug>.mini.md` with
   `universal: true` and `default_mode: always-on`.

Promotion is not for every lesson — only for ones that hold across stacks,
domains, and product surfaces. The naschool harvest that produced #29 and
#30 dropped ~17 candidates of which 8 survived the agnostic-rewrite bar.

Automate (`/ai:promote-feedback` skill) only when promotion rate exceeds
~1 / month; below that threshold the manual flow is faster.
