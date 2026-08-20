# Roadmap

Forward-looking work only. Shipped history lives in [CHANGELOG.md](../CHANGELOG.md)
and the git tag log; the full prior roadmap (completed-epic narratives + design
rationale) is frozen in [roadmap-archive.md](roadmap-archive.md).

Every open GitHub issue has a row here (roadmap ↔ issues sync rule) — reconcile
drift before planning. Priorities mirror the issue labels.

_Last reconciled: 2026-08-20 against 19 open issues (#121 and #122 shipped the same day via
`/ai:autonomous`, PRs #125 and #126, unreleased — the next bump carries them. Both runs' reviews
caught a blocker each: a failed scan reporting "no findings", and a husky-configured project being
told it had no pre-commit mechanism. #123 is unblocked and queued; #124 stays human-driven. Prior
the same day: #120 added — the catalogued `gitleaks-scan`
recipe guards the wrong moment; surfaced by `/ai:should-i-use` on kakashi (Ignore), which prompted
a gitleaks sweep over six real projects. Design settled the same day via `/ai:grill-me`, then split
into #121–#124 via `/ai:to-issues`; #120 keeps its row as the parent and no longer carries
`ready-for-agent`. Remediation for the one repo with real findings is `emeq-system#209`. Note:
#120 was auto-closed and reopened the same day — the commit subject carried the literal string
`fix #120`, which GitHub reads as a closing keyword.) Prior:
2026-07-26 against 17 open issues (#119 opened + closed same session — spike:
measure `pre-write-discipline` effectiveness, surfaced by `/ai:should-i-use` on ponytail (Ignore);
declined — measuring a behavioural rule needs A/B agent runs that reverse ADR-0002, whose Revisited
note now records the decision). Prior:
2026-07-11 against 17 open issues (#118 added — `graph-fresh` cannot check umbrella
repos like emeq, whose root is not a git repo; #117 added — surface `graph-fresh` in the
search-delegation hook, where a stale graph actually misleads the agent. Both deferred from the
v1.47.0/v1.47.1 `graph-fresh` session.) Prior: 2026-07-09 against 15 open issues (#116 added — plugin skill shadows same-named
project skill, shares bootstrap root with #114; #115 opened + closed same day — GitHub Copilot
rejected as a third host, ADR-0010 kept as Rejected; #114 added — bootstrap pins the versioned
plugin-cache path, bricked emeq's 114 skill symlinks, naschool primed to follow; #113 added — marker ↔ hook-wiring
cross-check gap, surfaced by a hook inventory; #112 added — OpenSpec: Ignore for catalog, spike on whether `to-issues` should emit an in-repo spec-delta; #108 was untracked + unlabelled, now P2; #111 SkillSpector skill-security scanner spike; #110 headroom tool-output-compression companion spike; #109 codebase-memory-mcp graphify-replacement spike; #101/#102/#103/#107 shipped in v1.42.0; #105 in v1.41.1)._

## P1 — broken in the wild

- **#120** `enhancement · primitive:hook` — `hooks-patterns.json` recommends
  `gitleaks-scan` as a PreToolUse `Edit|Write` guard, which only inspects what the
  agent writes next. A `gitleaks detect` sweep over six real projects returned 104
  hits, **every one already in history** — the recipe would have caught nothing.
  Only `emeq-system` holds real findings (a live Ibanity PSD2 private key, a Mailgun
  signing key, WordPress DB dumps); the other five are dominated by false positives,
  and both public repos are clean. Fix = repo-**entry** scan in `/ai:setup` +
  `/ai:hygiene` (redacted to paths + rule ids, since findings enter agent context),
  emitted pre-commit + CI for prevention, and keep `block-env-edits` as PreToolUse
  where the shape is right. Compounding: every recipe is advisory metadata with no
  `command` field — though that is deliberate, not a gap: `recommend-tools` generates
  the script at approval time, so the defect is a wrong spec rather than a missing one.
  **Design settled** via `/ai:grill-me` across five branches: a one-time discovery scan
  at `/ai:setup` plus a re-runnable `bin/ai-kit-secrets-scan.sh`, never per-hygiene-run
  (44s over 2578 commits); hygiene grades only whether a gate is wired, at `warn`/`-5` —
  never `-20`, which would drop all six repos under the 94 floor at once; findings
  acknowledgement-gate setup rather than blocking it, since ai-kit cannot rotate the key
  it found; rank and collapse, never filter, and **no baseline ever** (baselining would
  have accepted the Ibanity key as known on first run); CI workflow always, pre-commit
  only appended to a mechanism that already exists — the six projects run four different
  ones and none uses the `pre-commit` framework. Scope is the one row: drop it, keep
  `block-env-edits`, no verification pass over the other 26. Remediation for the affected
  repo is tracked outside ai-kit as `emeq-system#209`. Now a parent only — split into
  four tracer-bullet slices, `ready-for-agent` dropped here so the picker cannot choose
  the parent over its own children. #121 (scanner + recipe drop) and #122 (CI emit +
  pre-commit append) shipped unreleased in PRs #125 and #126; both are awaiting the next
  version bump. Remaining:
  - **#123** `AFK`, unblocked by #122, queued — hygiene section grading gate wiring at
    `warn`/`-5`, which never invokes the scanner. It recognises what #122 emits: the
    workflow file, and the guard line in whichever pre-commit mechanism the project runs.
  - **#124** `HITL` — `/ai:setup` wiring, `branches.secrets_scan`, and the
    acknowledgement gate. Human-driven: it adds the first stop-point to a skill that has
    none, and the wording of a pause in an onboarding flow wants human judgement.
- **#114** `bug` — `bootstrap-project.sh` symlinks skills to the **version-numbered
  plugin-cache path** (`~/.claude/plugins/cache/…/ai/<VERSION>/skills/`), so every
  `/plugin update` orphans every project symlink. Bricked `emeq` (114 dead links,
  score 80/100 → 95 after removal); `naschool` is pinned to `1.43.1` with `1.43.2`
  already installed and reproduces on the next cache GC. Doctor compounds it:
  `ai-kit-doctor.sh:276` blames "ai-kit moved?" and prescribes the very command that
  recreates the bug, then warns when the dirs are absent — penalising the healthy
  plugin-only config that `emeq-hub` runs at 95/100. Fix = stable indirection
  (`~/.config/ai-kit/plugin-current`) + plugin-aware doctor checks. Open question:
  Cursor has no plugin channel, so `.cursor/skills` removal must key off actual
  Cursor usage.

## P2 — next up

- **#117** `enhancement · primitive:hook` — surface `graph-fresh` in the
  search-delegation hook, where the damage actually happens. `/ai:docs-sync`
  catches a stale graphify graph once per session; the hook fires on *every* Bash
  call and routes the agent to `graphify query` — pointing it at a map of code
  that has already moved. Open question is cost (a `git diff` per Bash call) →
  cache the verdict per HEAD, or warn once per session. Must reuse
  `ai-kit-docs-sync-graph-fresh.sh`'s "candidate, not proof" semantics, not
  re-derive them.
- **#118** `enhancement` — `graph-fresh` cannot check umbrella repos. emeq's root
  is not a git repo; it holds `admin/`, `system/`, `emeq-app/` as separate repos
  with graphify indexing across all three, so there is no single HEAD to compare.
  The check skips cleanly — but that leaves the project *most* likely to drift
  (three repos moving independently) with no drift signal at all. Cheapest fix
  needs nothing upstream: record a composite `{repo: HEAD}` stamp in
  `graphify-out/.ai-kit-graph-verified`.
- **#116** `bug · primitive:plugin` — a plugin skill silently shadows a same-named
  project skill: `bootstrap-project.sh` merges ai-kit skills with `ln -sfn`, which
  overwrites on name collision while the echo claims "custom entries preserved".
  naschool's own 379-line `docs-sync` was invisible in Claude Code for weeks —
  and the collision was self-inflicted, since #26 promoted that very skill into
  the catalog under the same name. Shares a root with **#114**: both come from
  bootstrap materialising ai-kit skills into project dirs. If #114 lands the
  plugin-only target state, this evaporates for global mode; `project-only`
  installs still need collision detection before overwrite.
- **#108** `enhancement` — auto-memory `MEMORY.md` grows unbounded: `/ai:checkpoint`
  appends one index line per session, and the index loads into context *every*
  session. Observed at ~25KB / 40+ lines before manual trimming. The only open
  issue that costs tokens in every project on every run. Fix shape: checkpoint
  overwrites a single "latest" pointer (append-then-prune); older checkpoint files
  stay on disk un-indexed; `/ai:resume` picks newest by date. No extra archive file.
- **#104** `enhancement` — brownfield first-install friction: 15 points / 6 themes
  across setup · doctor · dedupe · status · plugin. Cluster, not one fix →
  decompose via `/ai:to-issues` before scheduling.

## P3 — backlog

- **#113** `enhancement` — nothing cross-checks a project's `.ai-kit-setup` marker
  against the real wiring in `.claude/settings.json`: `ai-kit-upgrade.sh` re-stamps
  two keys, `audit-setup-symmetry.sh` only greps ai-kit's own source, and
  `verify-setup.sh` never mentions `hook` or `settings.json`. Found in the wild —
  `emeq/.ai-kit-setup` claims 9 `hooks_wired`, three of which fire nowhere. Decided
  2026-07-09: the marker is **advisory** — `verify-setup.sh` derives truth from
  `settings.json` alone (dangling commands + orphan scripts), no `hooks_wired` key.
  Unblocked; ready to scope. Surfaced via `/ai:hygiene`.
- **#112** `enhancement` — spike: should `to-issues` emit an in-repo **spec-delta**
  reviewable in the same PR as the code? Surfaced by `/ai:should-i-use` on
  OpenSpec (Fission-AI), whose verdict was Ignore for the catalog — alternative
  lifecycle, not a companion; every stage duplicates an ai-kit skill, and
  `openspec init` forks both the command namespace and the contract surface
  (logged in `plugins-excluded.json`). Its one novel idea survives the rejection:
  requirement deltas live in the diff, whereas ai-kit's contract surface is the GH
  issue body — deliberately outside it. First across five Ignores where ai-kit has
  no answer, same shape as #111 exposing VETTING.md's missing security criterion.
  Tension to resolve before building: a second contract surface is the exact
  cohesion failure OpenSpec was rejected for. No pain today.
- **#111** `enhancement · catalog-candidate` — spike: wire `SkillSpector` (NVIDIA,
  Apache-2.0) skill-security scanner into ai-kit's **own** CI + should-i-use
  vetting. should-i-use verdict was Ignore for the catalog (one-shot scanner, not
  a compounding companion; Python+LLM+MCP footprint vs ADR-0006; logged in
  `plugins-excluded.json`) — but UNLIKE the other Ignores it plugs a real gap:
  VETTING.md's seven criteria have no automated security/malicious-pattern
  dimension, yet ai-kit emits 27 skills + recommends 12 plugins under an implicit
  "safe to wire" endorsement. First slice: `skillspector scan --no-llm` (static,
  zero-API) as an advisory SARIF gate on emitted skills + a should-i-use probe for
  community skills. Arguably more actionable than #109/#110 — closes a hole rather
  than re-litigating an existing companion.
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
