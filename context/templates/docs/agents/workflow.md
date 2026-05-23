# Agile workflow

Configured via `/ai:setup`. Framework preference for this repo.

## Framework

<!-- scrum | kanban | informal — filled by /ai:setup -->

## Scrum

- Sprint length: <!-- e.g. 2 weeks -->
- Planning: `to-issues` → `triage` → `ready-for-agent`
- Close increment: `/ai:ship`
- Retrospective: `/ai:retro`

## Kanban

- Board columns map to triage labels: `needs-triage` → `ready-for-agent` → done (issue closed)
- WIP limit: <!-- optional -->
- Continuous flow — run `/ai:retro` on a schedule you choose

## Informal

- No fixed ceremonies — use skills ad hoc
- Full lifecycle still available: ideation → dev → test → ship → retro
