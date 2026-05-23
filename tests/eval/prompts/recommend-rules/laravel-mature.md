---
id: laravel-mature
skill: recommend-rules
expects:
  - runs bin/recommend-rules.sh and surfaces scored canonical rules from the JSON output (never invents scores)
  - groups results by tier (strong fit / moderate fit / filtered) with the reason field shown verbatim per rule
  - for a mature Laravel repo, flags legacy-code (age threshold) and ddd-distilled / release-it (framework match) explicitly
  - offers Phase 2 web-search only if the user wants stack-specific community rules — never auto-fetches
  - if web search runs, returns ≤5 candidates with name, URL, last-updated, license, source reputation, one-line summary
  - never silently writes external rules — always preview-then-confirm with provenance frontmatter (source_url, license, pinned_sha, vendored_at)
  - ends with explicit "enabled / deferred / filtered" breakdown
  - does NOT claim a rule is active without an emit-rules.sh call confirming it landed on disk
---

# Prompt

I'm on a Laravel 11 monorepo we've maintained for ~5 years. We already ran
`/ai:setup` and bootstrap dropped the universal rules into `.cursor/rules/` and
`.claude/rules/`. Which rules *specifically* apply to a project like this,
and are there any community-curated rule packs I should consider on top?
