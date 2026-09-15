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

## The eight criteria

A candidate **must clear all eight** before it lands in any
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

- **Probe:** if the candidate is a **verbatim copy** of upstream files (not a
  catalog entry describing them), is it registered in
  `standards/external/vendored.json`? That manifest is what
  `bin/ai-kit-upstream-drift.sh` reads; a copy missing from it is a copy
  nothing ever checks for staleness. Record `repo`, `ref`, `pinned_sha`,
  `paths`, and — the field that makes a later re-vendor safe — `local_deltas`,
  the edits ai-kit made on purpose.

### 8. Security / malicious-pattern scan

The first seven criteria check whether a candidate is *honest* and *compatible*.
This one checks whether it is *safe to execute*. Skills, plugins, and hooks run
with implicit trust — a category-correct, license-clean, accurately-marketed
skill can still ship a prompt injection or an exfil payload.

Surfaced by `/should-i-use` on NVIDIA/SkillSpector 2026-06-26 (verdict: Ignore
for the catalog, wire as ai-kit's own gate — #111). The tool itself is not
required; the *check* is.

- **Probe:** run a static skill-security scan over the candidate's source —
  `skillspector scan <dir> --no-llm` (zero-API, no network beyond OSV.dev) or
  an equivalent. Triage prompt-injection, data-exfiltration,
  privilege-escalation, supply-chain, excessive-agency, and tool-poisoning hits.
- **Probe:** read `SKILL.md` / system prompts by hand for instruction
  injection, system-prompt-leak phrasing, anti-refusal / trigger-abuse wording.
- **Probe (least privilege):** does the candidate request broader tool,
  filesystem, or network scope than its stated job needs? Unexplained breadth
  is a finding even with no overt payload.

**Fail mode:** any high-severity malicious pattern, or unjustified broad agency.
Mark as `SECURITY-SCAN: pass|fail (<finding>)`.

**Scope:** applies to candidates whose source is vendored or whose skill files
are fetchable. An MCP server contacted purely over the wire is not
source-scannable — mark `SECURITY-SCAN: n/a (remote)` and defer to a runtime
least-privilege review at install time.

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
  SECURITY-SCAN:    pass|fail|n/a (<note>)
  VERDICT:          ADD|REJECT|REVISIT (<reason>)
```

Rows audited before criterion #8 landed (2026-06-26) carry
`SECURITY-SCAN: not-run (pre-#8)` until the next annual re-walk — they are not
retroactively rewritten, only re-scanned on cadence.

`n/a` is allowed only where a criterion does not apply (e.g., a built-in
formatter recipe with no upstream repo to pin — `PROVENANCE: n/a`).
"Allowed" means cleared, not skipped.

## Re-audit cadence

- **On every new catalog addition** — run the eight criteria, append to the
  audit log, commit alongside the entry. PRs adding entries without an
  audit row are blocked.
- **Annually** — re-walk existing entries; flag any whose upstream has
  drifted (license change, abandonment, claim shift) and run the #8 security
  scan on any row still marked `not-run (pre-#8)`. Move drifted entries
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

### `diagram-design` — added 2026-08-23 (plugins.json)

`/should-i-use https://github.com/cathrynlavery/diagram-design` 2026-08-23.
First verdict was Ignore (person-scope, no repo signal); reversed same session
on owner decision after the signal gap closed — the scorer gained a `content`
signal type, and "repo markdown already contains ` ```mermaid ` blocks" is an
honest, deterministic project-scope signal for a diagram renderer. Entry
discloses the GitHub caveat: output is standalone HTML+SVG that GitHub does
not render inline — Mermaid stays the in-repo source of truth; this is the
publication-quality export path (it redraws Mermaid/draw.io sources).

```
diagram-design · category=diagrams · added 2026-08-23
  MARKETING-PARITY: pass (README claims 39 types; 39 distinct static types on
                    disk in skills/diagram-design/assets/ — 149 example HTML
                    files incl. dark/full variants + animated/terminal/import
                    extras; per-type reference docs match 1:1)
  BENCHMARK:        n/a (no numeric performance claims; "60 seconds" is
                    marketing phrasing, not a benchmark)
  MARKETING-AUDIT:  pass (v2.x changelog claims match shipped assets; install
                    paths for all four hosts verified present in repo)
  LICENSE:          MIT + bundled third-party icons properly carved out in
                    THIRD_PARTY_LICENSES.md (Tabler MIT, Simple Icons CC0,
                    log-z/logos MIT, Devicon MIT) — safe
  MATURITY:         pass (25.8k★, active — pushed 2026-08-21; marketplace
                    plugin for Claude Code/Codex/Factory Droid/Pi; no build
                    step, no runtime deps; skill scripts are stdlib-only)
  DATA-LOCALITY:    local — pure Markdown skill + static HTML output; only
                    external touch is Google Fonts in generated pages and the
                    user-initiated brand-onboarding fetch of a URL the user
                    names (gated behind an explicit question)
  PROVENANCE:       648c2a597839301e06df1e7434a08bde9f42eed3
  SECURITY-SCAN:    pass — skillspector static-only reported risk 100/CRITICAL,
                    160 findings; ALL sampled HIGHs are false positives:
                    "IGNORE ALL PREVIOUS INSTRUCTIONS" hits are the repo's OWN
                    adversarial import-sanitization test fixtures
                    (scripts/fixtures/sample-adversarial.mmd + verify drivers);
                    "access token" = OAuth sequence example labels; "NO
                    WARNING" = user-journey sentiment copy; env/subprocess
                    hits = repo CI verify scripts, not the skill (the skill's
                    three Python scripts are stdlib-only, no subprocess, no
                    network). Second data point after copywriter (2026-08-19)
                    that static skillspector is noise on prose/SVG-heavy
                    skills — reinforces the #111 re-scope.
  VERDICT:          ADD (signal-gated: content:```mermaid)
```

### `skillui` — added 2026-09-14 (companions.json)

Owner-directed add (`/ai-kit skillui`, not a `/should-i-use` run) after the
owner found they already use the CLI locally
(`skillui --url <site> --mode ultra`). Source-dove the published npm tarball
(`skillui@1.3.4`, 105k-line bundled `dist/cli.js`) plus the upstream GitHub
repo before landing it, since a catalog entry is an endorsement to every
downstream project, not just this one.

```
skillui · category=design-extraction · added 2026-09-14
  MARKETING-PARITY: fail — README states (twice, incl. the tagline): "No AI,
                    no API keys, no cloud - everything runs locally." False:
                    `src/font-resolver.ts` (bundled into dist/cli.js) hardcodes
                    a live key — `GOOGLE_FONTS_API_KEY =
                    "AIzaSyCETey82fDURE2zp-MPF2lb_R-9PeAcPjY"` — and calls
                    `https://www.googleapis.com/webfonts/v1/webfonts` on every
                    scan that finds a font family to resolve font files. Not
                    user-supplied, not disclosed. Everything else checked out:
                    no LLM/agent-sdk calls found, no telemetry/analytics
                    strings, `--repo` clones via `simple-git` (argv-based, no
                    shell-string injection), `--url` crawl falls back to plain
                    `fetch` and only uses Playwright (optional peerDependency)
                    when present — that part of the static-analysis claim
                    holds.
  BENCHMARK:        n/a (no numeric performance claims)
  MARKETING-AUDIT:  fail, same finding as MARKETING-PARITY (one claim, two
                    criteria) — no other aspirational/unshipped features found
                    in a spot-check of `--help` against `dist/cli.js`'s mode
                    dispatch (`default`/`ultra`, `--url`/`--repo`/`--dir`,
                    `--screens`, `--format`, `--no-skill` all present and wired)
  LICENSE:          MIT asserted in `package.json`, but
                    `github.com/amaancoderx/npxskillui` root has no LICENSE
                    file (`GET /repos/.../contents/` 404s on it; GitHub API
                    itself reports `license: null`) — fails criterion #4's
                    "unspecified = fail" bar as written. Treat as MIT-asserted,
                    not MIT-confirmed, until upstream adds the file.
  MATURITY:         caution — repo created 2026-04-14, 25 npm versions shipped
                    in one month (2026-04-08 → 2026-05-07), then quiet: no
                    push and no npm publish since 2026-05-07 (4+ months as of
                    this audit). 2256★, 231 forks, 4 open issues, single
                    named author ("Amaan"). Works today; no evidence of
                    active maintenance if something breaks.
  DATA-LOCALITY:    vendor — every scan that detects a font family sends that
                    family name to Google's webfonts API using the author's
                    embedded key (see MARKETING-PARITY). Low sensitivity
                    (font family strings, not user/page content) but real and
                    undisclosed; the key is unauthenticated-caller-scoped
                    (public Fonts listing API), not a credential leak of the
                    ai-kit user's own secrets.
  PROVENANCE:       repo default branch `main`, no tags/releases found at
                    audit time — pin is "npm dist-tag latest @ 1.3.4"
                    (unpacked via `npm pack skillui@1.3.4`), not a git SHA
  SECURITY-SCAN:    pass, hand-read (not skillspector — this is a CLI tool,
                    not an agent-facing skill/prompt, so the injection-pattern
                    scanner doesn't apply; same reasoning as the MCP-server
                    carve-out in criterion #8's scope note). Checked for
                    `child_process`/`exec`/`eval`/credential-env-reads across
                    the full 105k-line bundle: the only `child_process` uses
                    are `commander`'s own bundled subcommand-spawn (argv array,
                    unused — skillui defines no subcommands) and a fixed-string
                    `execSync("npm root -g")` from a bundled dependency; no
                    `eval(`; no `process.env.*_KEY`/`*_TOKEN`/`*_SECRET` reads;
                    `--repo` goes through `simple-git` (reputable, argv-based).
  VERDICT:          ADD, with caveats (owner-approved after the two fails were
                    surfaced: MARKETING-PARITY/-AUDIT and LICENSE do not clear
                    the "must pass all eight" bar as written). Disclosed
                    verbatim in companions.json's `risk`/`install.notes`/
                    `license` fields and in the Phase 3 offer text in
                    recommend-tools/SKILL.md — never silently presented as a
                    clean pass. Revisit if upstream adds a LICENSE file, drops
                    the hardcoded key, or goes fully dormant (no push in 12
                    months).
```

### `scrapling` — added 2026-09-14 (companions.json)

`/should-i-use https://github.com/d4vinci/Scrapling` 2026-09-14, same session
as `skillui` above. Owner already runs it in production via a personal
wrapper (`~/Sites/localhost/ws/site-scrapers`, built on
`scrapling[fetchers]`) that scraped the SnelStart B2B API docs for emeq-hub —
Track B was a confirmed **Wire** before this audit even started. This row
covers Track A: does ai-kit's own catalog get a companion out of it.

```
scrapling · category=web-fetch · added 2026-09-14
  MARKETING-PARITY: pass — spot-checked every headline claim against source
                    (local unpacked repo, not just the README): adaptive
                    element relocation (`scrapling/parser.py::relocate()`,
                    real), Cloudflare Turnstile solving (real, present across
                    4 engine files), spider/crawl framework
                    (`scrapling/spiders/spider.py::CrawlSpider`, real),
                    "~3,500 known ad and tracker domains" (ad_domains.py:
                    3528 entries — matches), `--ai-targeted` CLI flag wired to
                    `main_content_only` sanitization (real, scrapling/cli.py).
                    Zero false claims found — direct contrast with skillui's
                    "no API keys" fail in the row above.
  BENCHMARK:        n/a (no numeric performance claims in the README/skill;
                    benchmarks.py ships but is opt-in, not a marketing figure)
  MARKETING-AUDIT:  pass (official MCP server doc — agent-skill/Scrapling-
                    Skill/references/mcp-server.md — lists 10 tools; all 10
                    confirmed wired in the bundled skill's tool-selection
                    table; no "coming soon" features presented as shipped)
  LICENSE:          BSD-3-Clause. LICENSE file present at repo root, matches
                    pyproject.toml's `license = {file = "LICENSE"}` — parity,
                    unlike skillui. Safe for MIT-consumer use.
  MATURITY:         pass — created 2024-10-13 (2 years old), 80,915★, 8,166
                    forks, 7 open issues (very low ratio for the star count),
                    pushed 2026-09-13 (1 day before this audit), latest
                    release v0.4.15 (2026-08-23). `.bandit.yml` present with
                    per-skip justification comments — active security
                    hygiene, not blanket lint suppression.
  DATA-LOCALITY:    local — no telemetry/analytics calls found in a source
                    scan; the only "telemetry" string hits are third-party
                    hostnames in the tool's own ad/tracker BLOCKLIST
                    (ad_domains.py), not outbound calls Scrapling makes
                    itself. Network activity is exactly what the user asks it
                    to fetch, nothing more.
  PROVENANCE:       48da61d1ee85cea7bbbdff013d98c90602e1d93f (main, 2026-09-14)
  SECURITY-SCAN:    pass, hand-read (same n/a-for-skillspector reasoning as
                    skillui — CLI/library, not an agent-facing skill prompt).
                    Grepped the full unpacked repo for hardcoded
                    keys/telemetry/analytics — zero hits beyond the ad-domain
                    blocklist noted above. `.bandit.yml` skip list is narrow
                    and each entry justified inline (e.g. B113 skip scoped to
                    "benchmark and examples scripts only").
  VERDICT:          ADD (companions.json, category web-fetch). Clean pass on
                    all eight — no caveats to disclose, unlike skillui.
                    Project-judgement-gated like graphify/llm-wiki, not
                    universal like context7: fires when the project does
                    external research, API-doc ingestion, or reference-site
                    work, not for every repo.
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
the signal to run the eight criteria here.

### `copywriter` skill — evaluated 2026-08-19 (VENDORED)

Copy + humanizer skill vendored into `workflow/skills/copywriter/` from
`mikiarlo3/ai-copywriter`. Vendored rather than recommended-external on an
explicit owner decision: ai-kit will extend it (Dutch AI-tell patterns, a
per-project copy-context) and a fork cannot track upstream anyway. Deliberately
**not** added to `plugins.json` — vendoring and recommending the upstream
install at the same time would double-bundle.

```
copywriter · category=content · vendored 2026-08-19
  STORAGE-PARITY:   n/a (no storage layer; pure Markdown prompt)
  BENCHMARK:        n/a (no numeric claims)
  MARKETING-AUDIT:  pass with notes — 33 patterns claimed, 33 present (verified
                    by section numbering). README understates size: claims
                    "about 8,000 tokens", actual SKILL.md is 48,451 bytes
                    (~12-13k tokens). README trails SKILL.md by one release.
  LICENSE:          MIT AND CC-BY-SA-4.0. Three-layer chain: Wikipedia "Signs of
                    AI writing" (CC BY-SA 4.0) -> blader/humanizer v2.9.1
                    (MIT, (c) 2025 Siqi Chen) -> mikiarlo3/ai-copywriter
                    (MIT, (c) 2026 Mickey Haslavsky). Because the pattern text
                    is Wikipedia-derived, this ONE file is carved out of
                    ai-kit's repo-wide MIT. The attribution block at the foot of
                    SKILL.md is load-bearing: it must travel with any copy.
  MATURITY:         caution — not age, release surface. Upstream default branch
                    is an agent working branch
                    (`claude/humanizer-copywriting-skill-u5x4vd`); `main` sits
                    one commit behind and misses v1.6.0. Six releases in 24h
                    (2026-07-24/25), quiet since 2026-08-01. Vendoring removes
                    this risk for ai-kit; it is why the SHA is pinned.
  DATA-LOCALITY:    pass — pure Markdown. No network calls, no telemetry, no
                    API keys, no runtime.
  PROVENANCE:       08b53b1ad39887cd94cbaab61cac3b6aae2d8518 (upstream v1.6.0)
  SECURITY-SCAN:    pass — skillspector 2.3.7, static-only. Score 49/MEDIUM,
                    safe_to_install=true, 5 findings, ALL 5 false positives:
                    2x HIGH "Anti-Refusal" matched the literal words "without
                    warning" inside an example sentence demonstrating em-dash
                    removal; 1x "Excessive Agency" matched contributor advice in
                    AGENTS.md; 1x "Scope Creep" matched the MIT warranty
                    disclaimer boilerplate; 1x LP3 wants an MCP `permissions`
                    field that Claude Code skills do not have. No real risk.
  VERDICT:          VENDOR
```

Two follow-ups this audit produced:

- **Known gap — Dutch.** The 33 patterns derive from English Wikipedia. Dutch
  AI-tells ("daarnaast", "bovendien", "het is belangrijk om te vermelden") are
  not in the list. Voice calibration partly covers it; a native NL pattern layer
  does not exist yet and is the first planned ai-kit extension.
- **Evidence against #111.** skillspector static mode returned 5/5 false
  positives on a prose-heavy Markdown skill, matching example text and licence
  boilerplate. Wiring it as a CI gate over ai-kit's own Markdown skills would
  produce noise, not signal. Re-scope #111 before building on it.

### `ponytail` — added 2026-08-26 (companions.json + plugins.json)

`/ai:should-i-use https://github.com/DietrichGebert/ponytail` 2026-08-26.
Second verdict. The first (2026-07-25) was **Ignore**, on the ground that it
duplicated ai-kit's own always-on `pre-write-discipline.mini.md`. Re-checking
that ground against the code overturned it: `workflow/.claude-plugin/plugin.json`
declares no `hooks` key, and `bin/lib/emitters/claude-code.sh` writes rules to
`.claude/rules/<name>.md` — "read by agent on demand" in its own header — so on
Claude Code the `always-on` label has no delivery mechanism. There was no double
injection to protect. Full reversal record with the counter-evidence:
`plugins-excluded.json` → `reversed[]`.

Scope correction found in review: the label **is** load-bearing on Cursor —
`bin/lib/emitters/cursor.sh` maps `always-on` to `alwaysApply: true`. The rule
therefore stays `always-on`; ponytail covers the Claude Code side only, and the
two are complementary rather than a hand-off.

```
ponytail · category=code-discipline · added 2026-08-26
  MARKETING-PARITY: pass (README's ladder matches skills/ponytail/SKILL.md; the
                    three declared hooks all call getPonytailInstructions(), so
                    the injection claim holds. UserPromptSubmit injects the full
                    body only in the Qoder branch and on explicit /ponytail
                    commands — not every prompt on Claude Code)
  BENCHMARK:        pass (benchmarks/promptfooconfig.yaml + benchmarks/agentic/
                    checked in, baselines named, reproducible via promptfoo.
                    Headline -54% LOC / 100% safe. Author revised the earlier
                    80-94% single-shot figure DOWN after upstream issue #126
                    called it a conversational-baseline artifact — corrected
                    against interest, which raises rather than lowers trust)
  MARKETING-AUDIT:  pass (spot-checked: config path, defaultMode key and
                    RUNTIME_MODES=off|lite|full|ultra all match
                    hooks/ponytail-config.js; no standalone hook installer, so
                    the caveman double-fire hazard does not apply here)
  LICENSE:          MIT — safe, no carve-outs (contrast caveman: MIT +
                    BSL-1.1 on Engine dirs, now tagged non_oss in its entry)
  MATURITY:         pass (hook floor: single-purpose, local, no network,
                    <100ms typical; 112k stars, 63 contributors, 15 releases,
                    active 2026-08-07)
  DATA-LOCALITY:    local (config in ${XDG_CONFIG_HOME:-~/.config}/ponytail/;
                    no telemetry, no network calls in hooks/*.js)
  PROVENANCE:       2ed6c52c9d7e5e56942508591085fd45dea277d3
                    CAVEAT: the SHA is recorded, not enforced — `claude plugin
                    install` takes marketplace HEAD (4.9.0 locally). Same
                    exposure as every other plugin row; not specific to this one
  SECURITY-SCAN:    pass (skillspector static, --no-llm, whole repo: risk 100 /
                    DO_NOT_INSTALL / 27 HIGH — triaged and rejected. ZERO
                    findings in the shipped runtime (hooks/, skills/, bin/);
                    every HIGH sits in benchmarks/, tests/, README.md or docs/.
                    Sampled: "Agent Snooping" on the README table documenting
                    which files ponytail writes; "Anti-Refusal" on the phrase
                    "without judgment" in a path-traversal benchmark result.
                    Hand-read of hooks/*.js: no network, no child_process, no
                    credential env reads — only own config + host-detection vars)
  VERDICT:          ADD (companions.json universal + plugins.json recommendation)
```

### `web-quality-skills` — added 2026-08-27 (plugins.json)

`/ai:should-i-use addyosmani/web-quality-skills` 2026-08-27. Surfaced while
mining `wilwaldon/Claude-Code-Frontend-Design-Toolkit` for leads; that link
list itself was excluded (`plugins-excluded.json`), along with `ui-skills`.
Figma MCP was declined by the owner (does not use Figma).

Gap it closes, measured in this repo: a recursive grep for `core web vitals`,
`lighthouse`, `LCP`, `CLS` and `INP` across `standards/`, `workflow/`,
`context/`, `orchestration/` and `docs/` returns **zero** hits.
`standards/rules/a11y.mini.md` prescribes axe-core in E2E but performs
nothing, and `/ai:qa` smoke-tests function, not quality. This is the only
frontend dimension the kit had no coverage for.

```
web-quality-skills · category=quality · added 2026-08-27
  MARKETING-PARITY: pass (README lists 6 skills; 6 skill dirs on disk —
                    web-quality-audit, performance, core-web-vitals,
                    accessibility, seo, best-practices, each with SKILL.md +
                    references/. "Measurement-first" holds: the skills separate
                    CrUX field data, first-party RUM, lab trace and static
                    inspection as distinct evidence types rather than
                    collapsing them)
  BENCHMARK:        n/a (no numeric performance claims of its own; the CWV
                    thresholds it cites are Google's published values)
  MARKETING-AUDIT:  pass (install paths verified: .claude-plugin/marketplace.json
                    declares marketplace `addy-web-quality-skills` → plugin
                    `web-quality-skills`; Codex and Gemini manifests present as
                    the README claims. Self-labelled "unofficial" — no false
                    Google/Chrome endorsement)
  LICENSE:          MIT, LICENSE file present (Copyright (c) 2026 Addy Osmani);
                    plugin.json restates MIT — parity, no carve-outs
  MATURITY:         pass (2713★, MIT, pushed 2026-08-24 — 3 days before audit;
                    v2.0.0; pure Markdown skills + one shell script, no build
                    step, no runtime deps)
  DATA-LOCALITY:    local for the skills themselves. DISCLOSE: the measurement
                    path drives chrome-devtools-mcp against a URL the user
                    names, and the field-data guidance queries Google's CrUX
                    API — both user-initiated, neither bundled or automatic
  PROVENANCE:       afa8da942115 (2026-08-24)
  SECURITY-SCAN:    pass — hand-read, not skillspector (third data point that
                    static scanning is noise on prose-heavy Markdown skills;
                    see copywriter 2026-08-19 and diagram-design 2026-08-23).
                    Sole executable is skills/web-quality-audit/scripts/
                    analyze.sh: `set -euo pipefail`, header declares "Read-only
                    HTML quality analyzer. No filesystem mutations", and the
                    body bears it out — grep/find/jq only, no eval, no network,
                    no writes, output bounded by MAX_FINDINGS=100 and a
                    per-category-per-file cap
  VERDICT:          ADD (signals mirror frontend-design: frontend architectures
                    + the 8 JS frameworks. Known limitation: server-rendered
                    stacks without a JS framework — Laravel Blade, Rails ERB —
                    will not trip the signal even though the skills apply to
                    them. Revisit if a downstream project hits it)
```

### `ui-ux-pro-max` — added 2026-08-29 (companions.json; already present in plugins.json)

`/ai:should-i-use https://styles.refero.design/` 2026-08-29. Refero itself
verdicted Ignore (paid MCP, no free tier — user confirmed on the pricing page).
The session surfaced a real gap while assessing it: `/ai:recommend-tools`
companions.json had zero design-category entries, so a fresh project never
got pointed at design tooling at setup time, even though `ui-ux-pro-max` was
already a single-source `plugins.json` recommendation for the same signal.
Promoted it to a full companion (AGENTS.md pointer + Phase 3 wiring), gated on
a project-signal check so it is never offered to backend/CLI repos.

```
ui-ux-pro-max · category=design · added 2026-08-29
  MARKETING-PARITY: pass, with caveat (upstream's own manifests disagree with
                    each other at the same commit: .claude-plugin/marketplace.json
                    says v2.2.1 / 96 palettes / 13 stacks, while
                    .claude-plugin/skill.json in the same tree says v2.5.0 /
                    161 palettes / 15 stacks. Not a live-drift artifact of
                    checking at different times — both files sit at the one
                    pinned commit. plugins.json's pre-existing entry already
                    disclosed this ("counts treated as advisory"); companions.json
                    now carries the same caveat instead of asserting a flat count)
  BENCHMARK:        n/a (reference/taxonomy skill, no numeric performance or
                    output-quality claim of its own to verify)
  MARKETING-AUDIT:  pass (install path verified: .claude-plugin/marketplace.json
                    plugin name `ui-ux-pro-max`, marketplace id
                    `ui-ux-pro-max-skill` — matches the `/plugin install
                    ui-ux-pro-max@ui-ux-pro-max-skill` command in both catalog
                    entries. `source: "./"` — the marketplace ships the whole
                    repo root as the plugin, not only `.claude/skills/ui-ux-pro-max`;
                    see DATA-LOCALITY / SECURITY-SCAN below, both scanned the
                    full tree accordingly)
  LICENSE:          MIT — LICENSE file (Copyright (c) 2024 Next Level Builder)
                    and skill.json both agree, no carve-outs
  MATURITY:         pass (no VETTING.md maturity floor is defined for a
                    "reference skill" category; judged on general-adoption
                    signals instead — 122,726 stars, 13,149 forks, 30
                    contributors, 30 releases, pushed 2026-08-27, two days
                    before this audit)
  DATA-LOCALITY:    local for the reference data (bundled CSVs, no telemetry
                    found). DISCLOSE: `source: "./"` also ships sibling
                    design skills (icon/logo/banner/slide generation under
                    .claude/skills/design/) whose scripts call out to
                    Gemini/Google's image-gen API using a user-supplied
                    GEMINI_API_KEY / GOOGLE_API_KEY — user-initiated per
                    invocation, not automatic or bundled with the core
                    ui-ux-pro-max reference skill
  PROVENANCE:       b7e3af80f6e331f6fb456667b82b12cade7c9d35 (2026-04-03,
                    default branch `main` confirmed via `gh api`)
  SECURITY-SCAN:    pass, after manual triage (`skillspector --no-llm` on the
                    full local checkout: risk 100 / CRITICAL / DO_NOT_INSTALL,
                    177 findings — 56 HIGH, 79 MEDIUM, 42 LOW, spread across
                    cli/, src/, and the design/ui-styling/brand/slides/
                    design-system skill dirs the `source: "./"` bundle ships
                    alongside ui-ux-pro-max itself. Fourth data point that raw
                    skillspector severity on a real, widely-used skill is
                    dominated by noise (see ponytail 2026-08-26,
                    web-quality-skills 2026-08-27). Triaged by category:
                    Credential Access / Env Variable Harvesting (24 findings)
                    is `.env` / `os.environ.get("GEMINI_API_KEY", ...)` loading
                    in the icon/logo/banner generation scripts — the intended
                    way those scripts take an API key, not exfiltration.
                    Direct Prompt Extraction / Hidden Instructions (14) is
                    HTML template comments (`<!-- Progress Bar -->`) and CLI
                    `--help` text, not injected instructions — hand-read
                    SKILL.md + CLAUDE.md for override/anti-refusal/hidden-
                    instruction phrasing separately, zero hits. Self-Modification
                    (3) is the `uipro init` installer CLI's own README/argv
                    parsing, not runtime self-mod. Unvalidated Output Injection
                    (6) is `subprocess.run(cmd, ...)` in
                    ui-styling/scripts/shadcn_add.py with `cmd` as a list
                    (`["npx", "shadcn@latest", "add", *components]`, no
                    `shell=True`) — no shell-string interpolation, so no
                    injection path despite the pattern match. One real,
                    non-noise finding: `grep -rn "shell=True\|exec(\|child_process"`
                    surfaced two spots using shell-string interpolation instead
                    of an argv list — `brand/scripts/sync-brand-to-tokens.cjs:253`
                    (`execSync` building a `node ... --config ...` command from
                    locally-resolved paths) and `cli/src/utils/extract.ts:17-18`
                    (`exec`/`execAsync` building an `unzip`/`Expand-Archive`
                    command from a temp-dir path). Both take their arguments
                    from paths the CLI itself resolves at local install time
                    (`mkdtemp`, `process.cwd()`), not from prompt-injectable or
                    network-supplied input during ordinary skill use — low
                    practical risk, but a genuine defensive-coding gap (should
                    be an argv-array `execFile` call, not a template-literal
                    shell string). Supply-chain: `pytest==8.0.0` /
                    `pytest==7.4.0` pinned in test fixtures with a flagged
                    CVE-2025-71176 (tmpdir handling) — dev/test-only dependency,
                    not shipped to the agent at skill-invocation time)
  VERDICT:          ADD (companions.json design category; plugins.json entry
                    pre-dates this session and is unchanged). Revisit the two
                    shell-string spots if `/ai:should-i-use` or a re-audit
                    ever needs to raise this past a reference-only companion —
                    they are upstream's code to fix, ai-kit vendors none of it)
```

### `inspo-mcp` — added 2026-09-15 (companions.json)

`/ai:should-i-use https://inspomcp.dev/` 2026-09-15. Track A found the same gap
`ui-ux-pro-max`'s own entry above names — "pair with actual reference sites for
concrete visual exemplars" — nothing filled it generically. Queued as
`yusufkaracaburun/ai-kit#168` pending this pass; Track B in the same session
found one confirmed downstream need (`emeq-hub#112` — `design-taste-frontend`
skill names "Linear-style"/"Awwwards-experimental" vibe words with no live
lookup mechanism) against three Ignores (theorieplek/emeq-web/planny-app-mobile
— design-led via Pencil, or wrong category for planny-app-mobile's native-app
screens, already covered by #166's curated mobile-app sources).

```
inspo-mcp · category=design-reference · added 2026-09-15
  MARKETING-PARITY: pass — source-dove the monorepo (github.com/Nutlope/inspo,
                    apps/mcp/src/tools.ts), not just the marketing page. All 15
                    documented tools exist with matching implementations:
                    `find_by_color` genuinely computes OKLAB palette distance
                    (packages/shared, `paletteDistance`), `find_similar` uses
                    real embeddings with an honest fallback to tag-overlap
                    ranking when vectors are still in flight ("waiting for
                    them rather than guess" — own code comment), and the
                    "19 named macrostructures" claim in `find_examples_for_
                    macrostructure`'s docstring matches the /mcp page. The
                    "SSRF protection on external URL fetches" claim (from the
                    /mcp page) holds: `packages/shared/src/study.ts` blocks
                    private/loopback/link-local/CGNAT ranges, IPv4-mapped
                    IPv6, and the cloud-metadata range (169.254.x.x)
                    explicitly, resolves DNS to close the
                    public-name-to-private bypass (nip.io/sslip.io-style), and
                    discloses its own limitation (no-op on Cloudflare Workers,
                    where a compat flag substitutes) rather than hiding it.
  BENCHMARK:        n/a — the 832-sites/2,320-screens catalogue-size figures
                    are inventory counts, not performance/accuracy claims;
                    matched the live /mcp and /screens pages at audit time,
                    expected to grow (repo pushed same day as this audit).
  MARKETING-AUDIT:  pass — no "coming soon" features presented as shipped in
                    `apps/mcp/src/tools.ts`'s 15 registered tools; the per-IP
                    rate limit (`apps/web/src/app/api/mcp/route.ts`) is
                    disclosed by upstream as in-memory/per-lambda-instance, a
                    real ceiling stated plainly rather than oversold as
                    distributed.
  LICENSE:          MIT. LICENSE file present at repo root (`gh api
                    repos/Nutlope/inspo/contents/LICENSE`), matches GitHub
                    API's `license.spdx_id` — parity, no carve-outs.
  MATURITY:         pass for the "MCP server" floor (stdio + JSON-RPC
                    compliance, declared tools list): built on the official
                    `@modelcontextprotocol/sdk`
                    (`server/mcp.js`+`server/stdio.js`), not a hand-rolled
                    protocol shim. 147★, 0 open issues, 249 commits, pushed
                    2026-09-15 (day of this audit) — actively maintained.
  DATA-LOCALITY:    vendor (Vercel-hosted, region unspecified in DEPLOY.md).
                    Read-only design catalogue: the gallery + MCP route serve
                    a static seed (`packages/db/src/static-screens.json`), no
                    live DB read at query time. Query inputs (search text, hex
                    colors, macrostructure/slug names) reach inspo's backend;
                    no project code or private content is sent. No self-host
                    path documented — DEPLOY.md describes Postgres/Fly.io/
                    Vercel as upstream's own deploy, not something a
                    downstream project stands up itself. Retention policy for
                    query text is not documented — disclose as unspecified.
  PROVENANCE:       85acb10f42e433b696fd95a447baf4d47d11021d (main, 2026-09-15)
  SECURITY-SCAN:    n/a (remote) — MCP server contacted purely over the wire
                    (npx installer writes client config, no vendored source),
                    per criterion #8's scope carve-out. The source dive above
                    (marketing-parity + SSRF review) covered the parts of the
                    codebase relevant to trust anyway, in more depth than a
                    static scanner would have.
  VERDICT:          ADD (companions.json design-reference category). Clean
                    pass on all eight — better-engineered than several
                    existing catalog entries (real SSRF hardening with a
                    disclosed platform limitation, honest per-instance
                    rate-limit disclosure). Sole caveat carried into the
                    catalog entry's `risk` field: vendor-hosted-only, no
                    self-host — free/no-API-key today is not a durability
                    guarantee. Revisit if upstream goes quiet (no push in 6+
                    months) or adds auth/pricing.
```
