---
name: twelve-factor
description: 12-factor app discipline — config in env, stateless processes, ports binding, dev/prod parity
applies_to:
  frameworks: []
  languages: []
  architectures: ["backend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Twelve-factor app

Long-running services follow [12factor.net](https://12factor.net). Drift from
these factors is the most common cause of "works on my machine" and
non-portable deploys.

## The non-negotiable subset

1. **Codebase** — one repo per app, many deploys (dev, staging, prod) from
   the same commit. No per-env forks.
2. **Dependencies** — declared explicitly (lockfile committed), isolated from
   system packages.
3. **Config in env** — never in code. `DATABASE_URL`, `STRIPE_SECRET`, etc.
   come from environment, not `config.prod.yml`.
4. **Backing services** as attached resources — DB, cache, queue, S3 are
   swappable via URL. No hard-coded hosts.
5. **Build, release, run** — three distinct stages. The artifact built in CI
   is the artifact that runs in prod; never re-build per env.
6. **Stateless processes** — no on-disk session, no in-memory caches that
   matter for correctness. State goes to backing services.
7. **Port binding** — the app exposes HTTP itself; no Apache/nginx
   sidecar required to *run* it (load-balancing is separate).
8. **Concurrency via process model** — scale horizontally with more
   processes, not bigger threads.
9. **Disposability** — fast startup (< 10s), graceful shutdown
   (drain on SIGTERM), crash-only safe.
10. **Dev/prod parity** — same backing-service types (Postgres in dev =
    Postgres in prod, not SQLite). Same OS where possible.
11. **Logs as event streams** to stdout — the runtime aggregates and
    ships. Don't write log files.
12. **Admin tasks** as one-off processes — migrations, console, REPL run
    in the same release artifact, just a different entrypoint.

## Common violations (red flags)

- `if (env === 'production') ...` branching code paths
- Secrets committed in `.env.production`
- Cron written in app code instead of a scheduled process
- Sticky sessions to "make caching work"
- Re-building the Docker image per environment with different bake args

## See also

- [`secrets-hygiene.mini.md`](./secrets-hygiene.mini.md) — config-in-env
  enforcement details.
- [`observability.mini.md`](./observability.mini.md) — logs as event streams.
