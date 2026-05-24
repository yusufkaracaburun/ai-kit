# standards/external/ — Vetting Criteria

Bar a candidate must clear before being added to any `standards/external/` catalog
(`mcp-servers.json`, `hooks-patterns.json`, future tables). Cross-cutting prereq
for roadmap items #19 (broaden signal tables) and #20 (PaaS advisory).

Surfaced by `/should-i-use` MemPalace 2026-05-23 — verdict on the tool was
**Ignore**, but the evaluation finding (three documented false README claims)
was reusable as the codification trigger.

## Why this exists

ai-kit emits recommendations to downstream user projects. Each catalog entry is
an implicit endorsement: *"this is safe to wire into your repo."* That trust
chain breaks the moment a catalog entry turns out to be marketing fiction, a
license trap, or category-confused with something already shipped.

Catalogs grow by addition. Without a bar, drift accumulates. With a bar,
additions stay deliberate.

## The seven criteria

A candidate **must clear all seven** before it lands in any
`standards/external/*.json` table.

### 1. Storage / data-shape parity with marketing

Claims in the README, landing page, or pitch deck must match what the code
actually does on disk / over the wire.

- **Probe:** read the source. If the README says "stores summaries", confirm
  the code does not actually verbatim-store raw text.
- **Probe:** if the README says "vector search", confirm an actual ANN index
  exists (HNSW / IVF / etc.), not a linear scan dressed up.
- **Probe:** schema versioning — does the on-disk format have a documented
  version field + migration plan, or is it "we'll figure it out"?

**Fail mode:** README ≠ code. Even one undisclosed gap disqualifies. Mark in
audit as `MARKETING-PARITY: fail (<specific claim>)`.

### 2. Benchmark integrity

Any numeric claim ("3× faster", "99% recall", "200ms p95") must be
reproducible and not over-fit.

- **Probe:** is the benchmark suite checked in? Can a third party re-run it?
- **Probe:** does the benchmark use the same data shape the tool encourages
  users to feed it? (No "teaching to the test" — synthetic uniform data when
  the tool ships for real-world skewed data.)
- **Probe:** are baselines named? "Faster than X" with X unnamed = noise.

**Fail mode:** opaque benchmarks, missing baselines, or test data the tool
was trained/tuned on. Mark as `BENCHMARK: fail (<reason>)`.

### 3. Marketing-vs-code parity audit

A stricter sibling of #1: skim the project's own marketing surface (README,
landing page, blog posts) for any feature claim, then confirm each one in
the code.

- **Probe:** list 5–10 concrete feature claims. Spot-check 3 against source.
- **Probe:** look for "coming soon" / "roadmap" features presented as if
  shipped.
- **Probe:** check the CHANGELOG vs commit log — does the timeline of
  "added" features match commits?

**Fail mode:** ≥1 documented feature is fictional or aspirational without
disclosure. Mark as `MARKETING-AUDIT: fail (<feature>)`.

### 4. License compatibility

ai-kit is MIT. Catalog entries must be one of:

- **MIT** or other permissive (Apache-2.0, BSD-2/3, ISC) — safe to recommend.
- **HTTP / MCP-client-only contact** — if downstream projects only call the
  tool over HTTP/MCP (never vendor source), the upstream license does not
  bind them. Note: this still requires data-locality disclosure (#6).

Disqualifying:

- **GPL-3.0 / AGPL-3.0** — incompatible with MIT for any vendored or
  embedded use. Recommending a self-host of an AGPL service is allowed
  **only** if no downstream code touches the source — pure
  HTTP/MCP-client contact. Document the AGPL boundary explicitly in the
  catalog entry.
- **Source-available** (BSL, Elastic v2, Confluent CC) — recommend only
  with an explicit "non-OSS" tag.
- **Unspecified / no LICENSE file** — fail. Trust requires a stated license.

Mark in audit as `LICENSE: <SPDX> + <safe|HTTP-only|fail-reason>`.

### 5. Category-appropriate maturity

Different categories carry different floors.

| Category | Maturity floor |
| -------- | -------------- |
| Vector store / RAG | Production index format, schema versioning, entity resolution |
| Code-running / sandbox | Sandboxed execution, resource limits, kill-switch |
| Memory / agent state | Documented retention, deletion API, on-disk format spec |
| Observability | Stable wire format, documented backend dependencies |
| Formatter / linter | Stable rule set, deterministic output |
| MCP server | stdio + JSON-RPC compliance, declared tools list, timeout handling |
| Hook | Single-purpose, fast (<100ms typical), never blocks Claude |

A candidate that is excellent on its own terms but below the floor for its
category fails. Mark as `MATURITY: fail (<floor missed>)`.

### 6. Data-locality disclosure

Where does user data go?

- **Probe:** is the storage local-only, self-hosted, or vendor-hosted?
- **Probe:** if vendor-hosted, what region(s), what retention, what
  deletion guarantee?
- **Probe:** does the tool phone home (telemetry, license check, model
  pulls)? If yes, can it be disabled?

A tool with unclear data-locality is unsafe to recommend across an
unknown installed base. Mark as `DATA-LOCALITY: <local|self-host|vendor:<region>|opaque>`.

### 7. Provenance pin-by-SHA

Catalog entries are vendored signal tables, not live fetches. The upstream
must be pinnable.

- **Probe:** is there a stable git URL or release artifact?
- **Probe:** does the entry's `_meta` block carry `source_url`,
  `source_license`, `pinned_sha`, and `vendored_at`?

A candidate without a pinnable upstream cannot be vendored — fall back to
HTTP/MCP-client recommendation only, or skip. Mark as `PROVENANCE:
<sha>|<unpinnable>`.

## Audit format

Every entry that lives in a `standards/external/*.json` table must have a
matching row in this file's [Audit log](#audit-log) below. Format:

```
<entry-name> · <category> · added <YYYY-MM-DD>
  MARKETING-PARITY: pass|fail (<note>)
  BENCHMARK:        pass|fail|n/a (<note>)
  MARKETING-AUDIT:  pass|fail (<note>)
  LICENSE:          <SPDX> + <safe|HTTP-only|fail-reason>
  MATURITY:         pass|fail (<note>)
  DATA-LOCALITY:    local|self-host|vendor:<region>|opaque
  PROVENANCE:       <sha>|n/a (built-in)
  VERDICT:          ADD|REJECT|REVISIT (<reason>)
```

`n/a` is allowed only where a criterion does not apply (e.g., a built-in
formatter recipe with no upstream repo to pin — `PROVENANCE: n/a`).
"Allowed" means cleared, not skipped.

## Re-audit cadence

- **On every new catalog addition** — run the seven criteria, append to the
  audit log, commit alongside the entry. PRs adding entries without an
  audit row are blocked.
- **Annually** — re-walk existing entries; flag any whose upstream has
  drifted (license change, abandonment, claim shift). Move drifted entries
  to a `REVISIT` section.
- **On any `/should-i-use` finding** — if a usage check surfaces a parity
  gap, update the entry's audit row inline.

## Audit log

Initial pass against the seven criteria as of 2026-05-23. Existing entries
in `mcp-servers.json` and `hooks-patterns.json` audited together because
they share the same upstream provenance — `anthropics/claude-plugins-official
@ 3449c10c` (Apache-2.0).

### `mcp-servers.json` (15 entries)

All 15 entries are **MCP-server recommendations** — downstream projects
call them over stdio/JSON-RPC, never vendor source. Treated as a single
batch — the criteria apply to the *recommendation table*, not to each
upstream MCP server individually (each has its own license; user picks
per-install).

```
mcp-servers.json batch · category=mixed · added 2026-05-23
  MARKETING-PARITY: pass (signals → server map distilled, no embellishment)
  BENCHMARK:        n/a (no numeric claims in the table itself)
  MARKETING-AUDIT:  pass (entries describe what the upstream does, not what it might)
  LICENSE:          Apache-2.0 (upstream signal table) — recommended MCP servers carry their own licenses, surfaced at install time
  MATURITY:         pass (each recommended server is a published MCP package; floor enforced by Anthropic-curated source)
  DATA-LOCALITY:    varies per recommended server — disclosed at install time, not at table level
  PROVENANCE:       3449c10cd1f254c2529a4a7e96a094ef118a00a5
  VERDICT:          ADD (already landed, retroactively approved)
```

Follow-up: when expanding the table for #19 (vector-DB / observability /
AI-memory categories), each *new* category gets its own per-category
audit row covering criteria #1, #2, #3, #5, #6 against the *category
floor* — not against each individual server. Per-server vetting moves
downstream to `/should-i-use` at install time.

### `hooks-patterns.json` (16 entries)

Same upstream provenance as `mcp-servers.json`. Hooks are pure recipes —
no runtime daemon, no data persistence — so criteria #5 (maturity) and #6
(data-locality) reduce to "is the recipe safe and bounded?"

```
hooks-patterns.json batch · category=mixed · added 2026-05-23
  MARKETING-PARITY: pass (each hook is a one-line shell pattern, claim = code)
  BENCHMARK:        n/a (no numeric claims)
  MARKETING-AUDIT:  pass (no aspirational entries)
  LICENSE:          Apache-2.0 (upstream signal table)
  MATURITY:         pass (single-purpose, fast, non-blocking matchers; floor met)
  DATA-LOCALITY:    n/a (hooks run locally on user machine, no data leaves)
  PROVENANCE:       3449c10cd1f254c2529a4a7e96a094ef118a00a5
  VERDICT:          ADD (already landed, retroactively approved)
```

### `claude-mem` — evaluated 2026-05-23 (catalog candidate, deferred)

`/should-i-use claude-mem` 2026-05-23. Apache-2.0 Claude Code plugin
(github.com/thedotmack/claude-mem, v6.5.0, 77.6k★, created 2025-08-31).
Hooks session lifecycle → captures tool usage → compresses with Claude
agent-sdk → local SQLite + Chroma vector index → injects context on new
sessions. Runtime web viewer at `:37777`.

```
claude-mem · category=memory/agent-state · evaluated 2026-05-23
  MARKETING-PARITY: pass-with-caveat (`npm install -g` installs SDK only, not
                    plugin hooks — disclosed in README but a parity gap on
                    the standard distribution channel)
  BENCHMARK:        n/a (no numeric claims in README)
  MARKETING-AUDIT:  pass (32 README translations + Trendshift badge are
                    promotional but not fictional)
  LICENSE:          Apache-2.0 — safe for MIT consumer
  MATURITY:         partial — 9 months old, v6.5.0 (rapid iteration), `<private>`
                    exclusion tag + retention documented; on-disk schema-
                    versioning not visible in README (source dive needed
                    before promotion)
  DATA-LOCALITY:    hybrid — local SQLite + Chroma vector index BUT
                    compression goes through Anthropic agent-sdk
                    (conversation summaries leave the machine).
                    Must be disclosed in any catalog surfacing.
  PROVENANCE:       pinnable (github.com/thedotmack/claude-mem) — would
                    pin a SHA at catalog-add time
  VERDICT (catalog):       REVISIT — blocked on #19 (broaden signal tables to
                           AI-memory category) + boundary doc (built-in CC
                           memory vs llm-wiki vs claude-mem)
  VERDICT (ai-kit-the-repo): REJECT — redundant with built-in CC auto-memory +
                           graphify + llm-wiki; agent-sdk compression
                           adds API spend; `:37777` daemon adds operational
                           surface ADR-0006 scopes out
```

Deferred to a future AI-memory catalog category once #19 lands. Surfaced
here as documented prior art for the bar that category will need to clear.

### External rule — `laravel-php-83.mini.md`

Separate vendored artifact under `standards/rules/external/`, not a
catalog entry — included here for symmetry, since vetting applies to any
vendored external source.

```
standards/rules/external/laravel-php-83.mini.md · category=rule · added 2026-05-22
  MARKETING-PARITY: pass (rule body matches PatrickJS upstream)
  BENCHMARK:        n/a
  MARKETING-AUDIT:  pass
  LICENSE:          CC0-1.0 — safe (public domain dedication)
  MATURITY:         pass (curated awesome-list, widely referenced)
  DATA-LOCALITY:    n/a (markdown file, no runtime)
  PROVENANCE:       4467ad4 (PatrickJS/awesome-cursorrules)
  VERDICT:          ADD (already landed, retroactively approved)
```

## Relationship to `/should-i-use`

`/should-i-use` is the *runtime gate* — it evaluates one candidate against
*one project* in real time, with project context. This document is the
*catalog gate* — it evaluates whether a candidate becomes part of the
recommended-to-everyone surface.

A candidate can pass `/should-i-use` for a specific project (verdict
**Wire** or **Vendor**) without clearing this document's bar — that
just means it's right for that one project, not that it belongs in the
catalog.

When `/should-i-use` returns **Adopt-as-pattern** with explicit catalog
implication (e.g. "this should land in `standards/external/`"), that's
the signal to run the seven criteria here.
