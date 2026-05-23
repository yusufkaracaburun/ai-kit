# Propose-but-defer pattern

How ai-kit surfaces external plugins without coupling to them.

## What it is

ai-kit is **standalone** — no runtime dependency on external Claude Code plugins, Cursor extensions, or MCP servers. But sometimes an external thing genuinely complements the workflow (e.g. `claude-code-setup`'s `claude-automation-recommender`). The pattern: **mention once, record the user's choice, never invoke**.

Currently used by:

- `branches.automation_recommender` in `.ai-kit-setup` — proposes `claude-automation-recommender` from the `claude-code-setup` plugin.

## When to apply

Add a new propose-but-defer entry only when **all** of the following hold:

1. The external thing solves a problem ai-kit's own skills don't cover.
2. The thing is **opt-in** — the user must consciously choose it.
3. ai-kit can fully complete `/ai:setup` without ever running the thing.
4. The user's decision (`skipped` / `deferred` / `completed`) is worth remembering across sessions.

If only #1 holds: just write a comment in the relevant SKILL.md pointing at the thing. No marker key needed.

## The recipe

1. **Pick a marker-branch key.** Snake-case, descriptive. Example: `automation_recommender`.
2. **Add a CLI flag to `bin/write-setup-marker.sh`**: `--<kebab-case>=skipped|deferred|completed`. Follow the existing parsing + Python-write pattern in that script.
3. **Add a branch row to `workflow/skills/setup/SKILL.md`** Tier B table.
4. **Add a propose-but-defer block** under the table — three options, three values. Use the existing `automation-recommender` block as a template.
5. **Update `context/prompts/setup-project.md`** Tier B opsomming.
6. **Update `bin/ai-kit-status.sh`** branch-order list so the new choice surfaces in `ai-kit status`.
7. **Tests**: round-trip the three enum values + backward-compat (marker without the key still passes strict verify).

## What NOT to do

- **Don't generalise to a plugin registry.** A YAML/JSON list of "known plugins" turns ai-kit from a self-contained kit into a directory of external tools — opposite of the standalone goal. If you find yourself adding the third entry, *that's* when to design a registry — not earlier.
- **Don't invoke the external thing**, ever. Not via shell-out, not via a subprocess, not via an HTTP call. The pattern is "remember the choice", not "act on it".
- **Don't hard-fail when the plugin is absent.** If the user picked `completed` but doesn't have the plugin installed, that's their problem — `/ai:setup` still exits clean.

## See also

- `bin/write-setup-marker.sh` — the canonical flag-parsing + JSON-key pattern.
- `workflow/skills/setup/SKILL.md` branch 10 — the user-facing prose.
- `CHANGELOG.md` entry `1.2.0` — the first application of the pattern.
