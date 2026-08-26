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
