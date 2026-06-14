# Roadmap

Forward-looking work only. Shipped history lives in [CHANGELOG.md](../CHANGELOG.md)
and the git tag log; the full prior roadmap (completed-epic narratives + design
rationale) is frozen in [roadmap-archive.md](roadmap-archive.md).

Every open GitHub issue has a row here (roadmap ↔ issues sync rule) — reconcile
drift before planning. Priorities mirror the issue labels.

_Last reconciled: 2026-06-14 against 11 open issues (#105 shipped in v1.41.1)._

## P2 — next up

- **#101** `enhancement · primitive:rule` — CLAUDE.md hard-rules not gated
  pre-implementation. The pre-write 4-principle checklist is documented but not
  *enforced* before edits (agent over-engineered a one-boolean toggle with no
  skill active). Wants a gating hook/rule that fires at implementation time.
- **#102** `enhancement` — `/ai:recommend-tools` misses shadcn MCP coverage.
  Add a `components.json` signal → shadcn MCP entry in `mcp-servers.json`. Small,
  deterministic; adjacent to v1.41.0 (uupm carries shadcn MCP, but recommend-tools
  should surface the server itself on detect).
- **#104** `enhancement` — brownfield first-install friction: 15 points / 6 themes
  across setup · doctor · dedupe · status · plugin. Cluster, not one fix →
  decompose via `/ai:to-issues` before scheduling.

## P3 — backlog

- **#103** `enhancement` — `/ai:checkpoint` should auto-run + auto-fix
  `/ai:hygiene` + `/ai:docs-sync` to close the session loop (works, just clunky).
- **#106** `enhancement · catalog-candidate` — fold the Pencil design→code→verify
  skill into ai-kit. Adopt-candidate → routes through `/ai:should-i-use` + the
  `plugins-excluded.json` / catalog ledger before any fold.
- **#107** `enhancement` — cite Osmani "Loop Engineering" as external validation
  in the Ralph spike (`docs/spikes/aikit-autonomous-ralph.md`). Pure docs polish;
  batch with #21's OpenHands research pass (same doc).
- **#83** `enhancement` — `audit-architecture-flutter`: 8 Flutter 3.27 / Dart 3.6
  heuristics + helper-script, mirroring the existing per-stack audit extensions.
- **#47** `enhancement · needs-info` — optional Tier-B EOD-email branch for AFK
  autonomous runs. Sequence after #19's setup-mode opt-in pattern stabilises.
- **#31** `enhancement · primitive:* · needs-info` — structured per-claim validation
  as a cheap tech-debt surfacer; proposes 3 primitives. Stays needs-info till scoped.
- **#25** `enhancement · needs-info` — re-evaluate book-to-skill as a catalog
  candidate now that VETTING criteria (#22) have landed.
- **#15** `enhancement · ready-for-human` — brainstorm a second plugin under
  `yusufkaracaburun/marketplace`. Marketplace shape only pays off at N ≥ 2.
