# Roadmap

Forward-looking work only. Shipped history lives in [CHANGELOG.md](../CHANGELOG.md)
and the git tag log; the full prior roadmap (completed-epic narratives + design
rationale) is frozen in [roadmap-archive.md](roadmap-archive.md).

Every open GitHub issue has a row here (roadmap ↔ issues sync rule) — reconcile
drift before planning. Priorities mirror the issue labels.

_Last reconciled: 2026-06-23 against 9 open issues (#110 added — headroom tool-output-compression companion spike; #109 codebase-memory-mcp graphify-replacement spike; #101/#102/#103/#107 shipped in v1.42.0; #105 in v1.41.1)._

## P2 — next up

- **#104** `enhancement` — brownfield first-install friction: 15 points / 6 themes
  across setup · doctor · dedupe · status · plugin. Cluster, not one fix →
  decompose via `/ai:to-issues` before scheduling.

## P3 — backlog

- **#110** `enhancement · catalog-candidate` — spike: evaluate `headroom`
  (headroomlabs-ai) as a proxy-level **tool-output compression** companion.
  should-i-use verdict was Ignore for the catalog (logged in
  `plugins-excluded.json`); in-category + popular (~47k stars) but blocked on
  footprint (ADR-0006), trust surface (proxy MITMs all prompts + auto-edits
  CLAUDE.md), and overlap (output-shaper vs caveman, memory vs llm-wiki). Only
  its tool-output compression is genuinely new vs graphify. No pain today.
- **#109** `enhancement · catalog-candidate` — spike: evaluate
  `codebase-memory-mcp` (DeusData) as a graphify *replacement*. should-i-use
  verdict was Ignore for the catalog (alternative, not complementary; logged in
  `plugins-excluded.json`); only open question is whether its type-aware /
  semantic / Cypher engine beats graphify enough to migrate, against the MCP
  footprint cost (ADR-0006). No pain with graphify today.
- **#106** `enhancement · catalog-candidate` — fold the Pencil design→code→verify
  skill into ai-kit. Adopt-candidate → routes through `/ai:should-i-use` + the
  `plugins-excluded.json` / catalog ledger before any fold.
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
