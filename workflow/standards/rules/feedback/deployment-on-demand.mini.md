---
name: deployment-on-demand
description: Never deploy without explicit user request; green CI is not authorisation to ship
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Deployment on demand

Deploying to staging or production is an irreversible, blast-radius
action visible to other people. Always wait for explicit "go" from the
user, even when CI is green and the PR is merged.

## Why

The user owns deploy timing for reasons the agent does not see: pending
manual QA, comms windows, on-call rotation, freeze periods, dependency
on another team's release, customer notice. A "helpful" auto-deploy
breaks the user's coordination work and is never undoable without
visible incident.

This rule is one specific case of the broader "irreversible actions
require confirmation" pattern, called out separately because deploy
intent is easy to infer from a green merge.

## How to apply

1. **After a merge or release tag, stop.** Do not run deploy commands.
2. **Surface the deploy command(s)** the user would run, with a short
   "ready when you are" hand-off.
3. **If a deploy is requested**, do it. Otherwise, leave the artifact
   built and uploaded only if that step is part of the routine PR flow.
4. **Schedule-driven deploys** (cron, auto-promote) are user-owned
   infrastructure — the agent does not invent them.

## When to skip

- The user explicitly pre-authorised the deploy in this conversation
  ("merge and ship this one"). Authorisation does not carry across
  sessions.
- Local dev environment with no external surface (e.g. `npm run dev`).
  That's not a deploy.

## See also

- [`release-it.mini.md`](../release-it.mini.md) — release-step
  ordering.
- [`project-lifecycle.mini.md`](../project-lifecycle.mini.md) — extra
  caution in production phase.
