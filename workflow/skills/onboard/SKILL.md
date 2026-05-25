---
name: onboard
description: Generate an ONBOARDING.md for a new dev or agent arriving at this project, then publish it via the harness `ShareOnboardingGuide` tool so it can be shared with a short link. Use when a teammate joins the repo, when bootstrapping a fresh dev machine, or when an agent will pick up work without prior conversation history. Re-runs idempotently — refreshes the existing guide instead of creating a new one.
argument-hint: "Optional: arriving audience (e.g. 'backend dev', 'reviewer', 'cursor agent')."
---

Companion to `/ai:handoff`. **Handoff** leaves a machine; **onboard** arrives
at a project. Write a project-scoped `ONBOARDING.md` at the repo root, confirm
the contents with the user, then publish via the harness `ShareOnboardingGuide`
tool to get a sharable short-link.

## When to use

- New teammate or contractor joins the repo.
- Fresh machine — your own or someone else's.
- Agent (Claude Code / Cursor / Codex) will pick up the project with no
  conversation history.
- After a major structural change (new module, framework upgrade) — refresh
  the guide so newcomers don't start from a stale picture.

Skip when the project already has a current `ONBOARDING.md` and nothing
material has changed — re-running re-uploads the same content for no signal.

## Process

1. **Detect prior state.** If `./ONBOARDING.md` exists, read it first and treat
   the run as an update (Section "Re-runs" below).
2. **Survey the repo.** Pull from the sources that already exist; do NOT
   invent facts.
   - `CONTEXT.md` or `CONTEXT-MAP.md` (domain language)
   - `README.md` (one-line purpose, install steps)
   - `package.json` / `composer.json` / `pyproject.toml` / equivalent
     (commands, scripts, deps)
   - `.ai-kit-setup` (which Tier B branches the project opted into)
   - `docs/adr/` (load-bearing decisions)
   - `docs/architecture.md` if present
3. **Audience.** If the user passed an argument, scope the guide to it
   (e.g. "backend dev" → skip frontend tooling section). Default audience:
   generic full-stack contributor + agent.
4. **Draft the file.** Use the template below. Skip sections that don't apply
   rather than padding with "n/a".
5. **Confirm with the user.** Print a short summary of sections + word count;
   ask "publish via ShareOnboardingGuide?" before uploading. The tool sends
   the file to Anthropic infrastructure and returns a public short-code link —
   make sure the user wants that.
6. **Publish.** Call `ShareOnboardingGuide` with `mode='check'` (default).
   Behavior:
   - If `./ONBOARDING.md` exists locally → uploads to the most-recently-updated
     org guide (or creates one if none exist) and returns a fresh short-link.
   - If no local file → returns the existing link (status `has_existing`)
     without uploading.
   - Pass `mode='create'` only when the user explicitly wants a brand-new
     short-code (the old one keeps its content).
   - Pass `mode='update'` with `short_code=<code>` to target a specific
     existing guide.
   - Pass `mode='delete'` with `short_code=<code>` to remove one — confirm
     irreversibly with the user first.
7. **Print the short-link.** Hand the URL to the user. Suggest adding it to
   the repo README under a "## Onboarding" section so future newcomers find it
   without re-running the skill.

## Template

```markdown
# Onboarding — <project name>

**Audience:** <agent or human, generic full-stack unless scoped>
**Last refreshed:** <ISO date>

## 1. What this project is

<One paragraph from CONTEXT.md or README — the elevator pitch. No marketing.>

## 2. How to run it locally

```bash
# Exact commands. Order matters. Copy-paste must work on a fresh checkout.
<install>
<bootstrap (env, db migrations, seed data)>
<run dev server / tests>
```

> If the project uses Docker, `direnv`, or a specific Node/PHP/Python version,
> say so here — once, with the exact pin from the lockfile.

## 3. The shape of the codebase

<3–7 bullets: top-level dirs and what lives in each. Reference docs/architecture.md
if it exists rather than re-explaining it.>

## 4. Domain language (key terms)

<Glossary subset from CONTEXT.md — only the terms that newcomers trip over.
Link the full CONTEXT.md for the rest.>

## 5. How we work

- Branching: <trunk / GitFlow / direct-to-master>
- PR ceremony: <required / optional / none>
- Issue tracker: <GitHub / GitLab / Linear / local notes>
- Code review: <who, what depth, what skill (`/ai:review`)>
- Testing: <which suite, how to run, coverage expectations>
- Agents: <which skills are wired (`/ai:setup` ran which Tier B branches),
  which rules are active, which hooks fire on commit>

## 6. Load-bearing decisions

<Bullet list of ADR numbers + one-line why. Link `docs/adr/`. New contributors
should read these before proposing structural changes.>

## 7. Surface area for first contribution

<2–4 concrete starter tasks: "add a field to X model", "extend the Y skill",
"fix the open issue tagged good-first-issue". Each task names the file(s)
and the test that proves it works.>

## 8. Footguns

<Specific things that have burned previous contributors. "Don't run the seed
script — it drops the dev DB." "The `legacy/` folder is read-only; new code
goes in `src/`." One-line each.>

## 9. Where to ask

<Slack channel / GitHub Discussions / maintainer email. ai-kit defaults
assume a 2-dev minimum (per issue #52); when the project has only one
human contributor, document the response cadence explicitly (e.g. "human
reviewer within 48h" or "AI-as-reviewer with weekly human sweep") so
newcomers know what to expect.>

## 10. Suggested next skill

After reading this, run:

- `/ai:setup` — if the agent surface (`.claude/`, `AGENTS.md`) is missing
- `/ai:next` — to pick the first issue from the prioritised backlog
- `/ai:grill-me` — if anything in this guide is still ambiguous
```

## What NOT to put in an onboarding guide

- **Secrets, API keys, `.env` contents.** Reference `.env.example` instead.
- **Verbatim copies of ADRs or `docs/architecture.md`.** Link them — the
  guide ages, the canonical doc keeps moving.
- **Step-by-step rationale for every tool choice.** New contributors do not
  need the history; they need the current state. The history lives in
  ADRs / git log.
- **Full dependency lists.** Link the lockfile. Newcomers run `install`,
  they don't read it.
- **Aspirational state.** "We're moving to Y." Document what exists today;
  pending migrations belong in the roadmap, not onboarding.
- **Tribal trivia.** "Yusuf prefers tabs." Stack-level conventions live in
  `.editorconfig`; personal preferences don't belong in onboarding.

## Re-runs

`/ai:onboard` is idempotent. On a second run:

1. Read the existing `ONBOARDING.md`.
2. Diff its claims against current repo state — every command in section 2,
   every dir in section 3, every ADR in section 6.
3. Patch the stale lines, leave the rest. Surface the diff to the user
   before uploading.
4. Call `ShareOnboardingGuide` in default `mode='check'` — it overwrites
   the most-recent guide, so the same short-link keeps working.

Do not delete and recreate (that would break shared links).

## Coordination with `/ai:handoff`

- **Handoff:** "I'm leaving — here's the work-in-progress and what I'd do next."
  Project-internal, OS temp dir, never published.
- **Onboard:** "Welcome — here's how this project works, today."
  Project-scoped, repo-rooted, published via short-link.

They compose: a fresh agent rehydrates from `ONBOARDING.md` (the project
shape) and then a session-specific `handoff-<id>.md` (the in-flight work).

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" onboard start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" onboard done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
