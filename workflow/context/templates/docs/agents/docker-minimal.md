# Docker — minimal Compose starter

Customize service names and commands for your project.

## Commands

| Action | Command |
| ------ | ------- |
| Start | `docker compose up -d` |
| Stop | `docker compose down` |
| Logs | `docker compose logs -f app` |
| Shell | `docker compose exec app sh` |

## Running tests

Document your test command here after customizing compose. Derive it from repo scripts or the framework's official documentation.

## Services

See `compose.yaml` in the repo root. Default template includes `app` + `db` — adjust build context and ports as needed.
