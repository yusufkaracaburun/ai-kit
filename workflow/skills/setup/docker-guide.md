# Docker setup guide (for /setup skill)

Use during **branch 3 — Docker**. One question at a time.

## Explore first

Look for:

- `compose.yaml`, `docker-compose.yml`, `docker-compose.yaml`
- `Dockerfile`, `Dockerfile.dev`
- Laravel Sail: `docker-compose.yml` + `vendor/laravel/sail`
- `.devcontainer/`

## Ask the user

> **Explainer:** Docker here means *how you run the app locally*. It is separate from Sandcastle, which uses Docker only to isolate AFK coding agents.

Three choices:

1. **None** — dev on the host. Run:
   ```bash
   $AI_KIT_ROOT/bin/apply-docker.sh "$(pwd)" none
   ```

2. **Existing** — repo already has Compose/Sail/Dockerfile. Do **not** overwrite files. Read them and write `docs/agents/docker.md` with start/stop/test commands from the actual config. Then:
   ```bash
   $AI_KIT_ROOT/bin/apply-docker.sh "$(pwd)" existing
   ```

3. **Minimal starter** — new project, no compose yet. Run:
   ```bash
   $AI_KIT_ROOT/bin/apply-docker.sh "$(pwd)" minimal
   ```

Test commands in `docker.md` should come from repo scripts or official docs — not hardcoded stack assumptions.

## Existing project example (document only)

```markdown
# Docker

Uses existing `docker-compose.yml` (Sail).

| Action | Command |
| ------ | ------- |
| Start | `./vendor/bin/sail up -d` |
| Test | `./vendor/bin/sail test` |

Agents: run PHP/Artisan commands via Sail, not on the host.
```

Derive commands from the repo's actual Docker setup and [Laravel Sail docs](https://laravel.com/docs/sail) — do not guess.
