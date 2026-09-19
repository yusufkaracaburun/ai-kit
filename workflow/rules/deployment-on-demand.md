<!-- ai-kit global rule (ADR-0015): Never deploy without explicit user request; green CI is not authorisation to ship -->
<!-- Source: standards/rules/feedback/deployment-on-demand.mini.md — re-stamp with bin/sync-plugin-rules.sh -->

# Deployment on demand

Deploying to staging or production is irreversible and visible to others. Wait for an explicit "go", even when CI is green and the PR is merged: the user owns deploy timing for reasons the agent cannot see (manual QA, comms windows, on-call, freezes, another team's release). After a merge or release tag: stop, surface the deploy command(s) with "ready when you are", deploy only when asked; leave a build artifact built and uploaded only if that step is part of the routine PR flow. Schedule-driven deploys (cron, auto-promote) are user-owned infrastructure, not something the agent invents. Pre-authorisation in this conversation ("merge and ship this one") counts and does not carry across sessions; a local dev server is not a deploy. See `release-it.mini.md`, `project-lifecycle.mini.md`.
