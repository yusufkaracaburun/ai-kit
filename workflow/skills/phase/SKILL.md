---
name: phase
description: Read or flip the project lifecycle phase (development | production) without re-running /ai:setup. Use when the user wants to switch a project from dev to prod (or back), check the current phase, or asks "what lifecycle is this project in", "set this to production", "we're greenfield now", or invokes `/ai:phase`.
allowed-tools:
  - Bash
  - Read
---

# Phase

Lightweight flipper for the `branches.lifecycle` key in `.ai-kit-setup`. Lives separate from `/ai:setup` so the user can change phase without walking the whole setup tree.

## When to use

- User says "set this to production" / "we shipped, flip to prod" / "back to dev mode for the rewrite"
- User asks "what phase are we in" / "is this dev or prod"
- After a project gains real users (greenfield → mature transition)
- Before a major rewrite that needs reset-friendly defaults

For a full re-setup walkthrough use [`/ai:setup`](../setup/SKILL.md). For background on why this signal exists see [`standards/rules/project-lifecycle.mini.md`](../../../standards/rules/project-lifecycle.mini.md).

## Run

```bash
bash "${AI_KIT_ROOT:-${CLAUDE_PLUGIN_ROOT}}/bin/ai-kit-phase.sh" [development|production]
```

- No arg → prints current phase (default `production` when key missing).
- `development` or `production` → writes the key and reminds the user to restart the session so the canonical rule re-emits.
- Anything else → script exits non-zero with a clear error; marker is not touched.

## Output contract

Read the script output back to the user:

- If they asked for current phase, surface the single-word line.
- If they flipped, surface the `lifecycle: <old> → <new>` line **and** the restart reminder. Do not skip the reminder — the rule is loaded once per session and the user's current context still reflects the old phase.

## Side effects

- Writes one key (`branches.lifecycle`) in `.ai-kit-setup`. All other marker keys are untouched.
- Does not re-run `bin/emit-rules.sh`. The canonical rule re-evaluates the marker on next session.
- Does not modify `CLAUDE.md`, `AGENTS.md`, or `.claude/rules/*` directly.

## Errors

- `.ai-kit-setup missing` → tell the user to run `/ai:setup` first.
- Invalid phase value → echo the script's error verbatim; do not retry with a guess.
