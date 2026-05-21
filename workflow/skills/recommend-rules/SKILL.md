---
name: recommend-rules
description: Recommend canonical ai-kit rules + stack-specific community rules for the current project. Use when user asks "which rules should we enable", "set up rules for this repo", or after /setup to refine the default rule set. Combines deterministic scoring against detected stack with optional web search for community-curated rules.
---

Recommend a tailored rule set for this project. Two-layer process: deterministic scoring of canonical rules (`bin/recommend-rules.sh`), then optional web search for stack-specific community rules.

## When to invoke

- After `/setup` on a brownfield repo where the default universal rule set feels incomplete.
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

For each rule, include the `reason` field — it explains *why* this rule fits (universal vs. framework match vs. age threshold). Never invent reasons.

### Phase 2 — Stack-specific web search (optional)

If the user wants more than canonical rules, do a focused web search for community-curated rules matching the detected stack. Use the **frameworks** from detect-tooling as the seed query.

Examples of useful queries:

- `"laravel cursor rules" OR "laravel agents.md"` for a Laravel repo
- `"nextjs app-router rules" OR "react server components rules"` for Next.js
- `"rails .clinerules" OR "rails cursor mdc"` for Rails

Filter results by:

- Active maintenance (commits in last ~6 months)
- License (MIT/Apache/BSD preferred; flag unclear/no-license)
- GitHub stars as a weak signal (>50 stars worth surfacing; not a hard cut-off)
- Source reputation (framework's own team > community > random gist)

**Do not auto-install.** Surface ≤5 candidates with: name, URL, last-updated, license, one-line summary, "why it might apply here". The user picks.

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
