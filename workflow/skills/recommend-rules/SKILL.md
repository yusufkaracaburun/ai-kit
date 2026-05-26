---
name: recommend-rules
description: Recommend canonical ai-kit rules + stack-specific community rules for the current project. Use when user asks "which rules should we enable", "set up rules for this repo", or after /ai:setup to refine the default rule set. Combines deterministic scoring against detected stack with optional web search for community-curated rules.
---

Recommend a tailored rule set for this project. Two-layer process: deterministic scoring of canonical rules (`bin/recommend-rules.sh`), then optional web search for stack-specific community rules.

## When to invoke

- After `/ai:setup` on a brownfield repo where the default universal rule set feels incomplete.
- When the user asks "which rules apply here", "find rules for this stack", "is there a Laravel rule pack?", etc.
- When a previous emit was generic and the user wants to layer specificity.

If the user wants only the deterministic ranking and no web step, run the CLI directly and stop after Phase 1.

## Process

### Phase 1 — Canonical scoring

Run the deterministic scorer:

```bash
$AI_KIT_ROOT/bin/recommend-rules.sh "$PWD" --json
```

It scores every rule in `$AI_KIT_ROOT/standards/rules/` against:

- **Frameworks** (from `detect-tooling.sh`) — match against rule's `applies_to.frameworks`.
- **Architectures** (frontend/backend detected) — match against `applies_to.architectures`.
- **Repo age** (years since first commit) — must meet `repo_age_min_years`.
- **Weight** (`high|medium|low`) — base score for universal rules.

Present the result as a table to the user. Group by relevance tier:

- **Strong fit** (score ≥ 3) — recommend enabling.
- **Moderate fit** (score 1–2) — propose, but let the user opt out.
- **Filtered out** (score 0) — show only if user asks "why isn't X here".

Within each tier, surface the **feedback bucket** (rules whose source path is `standards/rules/feedback/`) under its own subheading — these are cross-project workflow / style / tool-gotcha defaults shipped via ADR-0007, not stack-tied. Keeping them grouped helps the user see why they showed up.

For each rule, include the `reason` field — it explains *why* this rule fits (universal vs. framework match vs. age threshold). Never invent reasons.

### Phase 2 — Stack-specific web search (optional)

If the user wants more than canonical rules, do a focused web search for community-curated rules matching the detected stack. Use the **frameworks** from detect-tooling as the seed query.

**Check the cache first.** Web searches are slow and re-fetch the same packs every invocation. Before searching, ask the cache helper whether we already have a fresh result for this exact stack:

```bash
KEY="$($AI_KIT_ROOT/bin/recommend-rules-cache.sh key "$PWD")"
if CACHED="$($AI_KIT_ROOT/bin/recommend-rules-cache.sh read "$KEY" 2>/dev/null)"; then
  # Cache hit (≤7 days old). Parse $CACHED as the candidate JSON and skip the
  # search. Tell the user the list was cached and offer `--refresh` to bypass.
  :
else
  # Cache miss or stale. Do the live search below, then write the result.
  :
fi
```

If the user asks to refresh (says "re-search", "refresh", or passes `--refresh`), bypass the read with `--no-cache` and re-run the live search.

Examples of useful queries:

- `"laravel cursor rules" OR "laravel agents.md"` for a Laravel repo
- `"nextjs app-router rules" OR "react server components rules"` for Next.js
- `"rails cursor rules" OR "rails agents.md"` for Rails

Filter results by:

- Active maintenance (commits in last ~6 months)
- License (MIT/Apache/BSD preferred; flag unclear/no-license)
- GitHub stars as a weak signal (>50 stars worth surfacing; not a hard cut-off)
- Source reputation (framework's own team > community > random gist)

**Apply the promotion quorum.** Per [`standards/promotion-quorum.md`](../../../standards/promotion-quorum.md),
a community rule reaches default-on tier only when ≥2 independent sources
document the same usage. Annotate every surfaced candidate inline:

- `(sources: N/M verified)` when at least 2 independent sources documented it.
- `(sources: 1 — preview only)` for single-source candidates. **Never
  default-recommend a `preview only` entry** — the user can still pick it,
  but the skill must not pre-select it.

Worked example output:

```
laravel-pint-strict-rules        (sources: 2/2 verified)
  reason: laravel framework match; weight=high
nextjs-app-router-flat-routes    (sources: 1 — preview only)
  reason: nextjs framework match; weight=medium  (not default-recommended)
```

**Do not auto-install.** Surface ≤5 candidates with: name, URL, last-updated, license, one-line summary, source-count annotation, "why it might apply here". The user picks.

After surfacing live results, persist them so the next invocation on the same stack skips the search:

```bash
echo "$CANDIDATES_JSON" | $AI_KIT_ROOT/bin/recommend-rules-cache.sh write "$KEY"
```

Use a JSON shape the next invocation can re-render directly, e.g.:

```json
{
  "stack_fingerprint": "<key>",
  "generated_at": "2026-05-23T12:34:56Z",
  "queries": ["laravel cursor rules", "laravel agents.md"],
  "candidates": [
    {
      "name": "PatrickJS/awesome-cursorrules",
      "url": "https://github.com/PatrickJS/awesome-cursorrules",
      "last_updated": "2026-04-18",
      "license": "CC0-1.0",
      "summary": "Curated Cursor rule packs by framework.",
      "why_applies": "Laravel detected; ships a Laravel PHP 8.3 rule pack."
    }
  ]
}
```

Cache lives at `${XDG_CACHE_HOME:-~/.cache}/ai-kit/recommend-rules/<key>.json`, TTL 7 days, keyed by the sorted detected frameworks + frontend/backend architecture. The user can clear it with `bin/recommend-rules-cache.sh clear [<key>]`.

### Phase 3 — Emit chosen rules

For canonical rules the user agreed to:

```bash
$AI_KIT_ROOT/bin/emit-rules.sh "$PWD" --rules <comma-separated-names>
```

For external rules the user picked, vendor them first:

1. Download to `$AI_KIT_ROOT/standards/rules/external/<slug>.mini.md` (or fetch + write to the project if user prefers project-local — ask once).
2. Add provenance frontmatter:
   ```yaml
   ---
   name: <slug>
   description: <one-liner from source>
   applies_to:
     frameworks: [<detected>]
   universal: false
   default_mode: on-demand
   weight: medium
   source_url: <https://github.com/...>
   source_license: <e.g. MIT>
   pinned_sha: <commit-sha-at-vendoring>
   vendored_at: <YYYY-MM-DD>
   ---
   ```
3. Run `emit-rules.sh --rules external/<slug>` to emit per-agent.

## Output contract

End by reporting:

- **Enabled (canonical):** list of rule names emitted, with format per detected agent.
- **Enabled (external):** list with source URL + vendoring path.
- **Deferred:** rules the user said "later" to.
- **Filtered:** zero-score canonical rules (one-liner each — be concise).

If anything failed (web search timed out, emit script erred), say so explicitly. Never claim a rule is active when it isn't on disk.

## Trust model

- Web fetches surface candidates only — no silent write.
- External rule content must be reviewed by the user before vendoring (show diff vs. nothing).
- Pin to a commit SHA on vendor; don't track a moving branch.
- Re-vendoring requires explicit user confirmation — silent drift kills trust.
