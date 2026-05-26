# `audit-architecture` extension contract

Single source of truth for per-stack extensions that layer on top of the stack-agnostic [`audit-architecture`](../../workflow/skills/audit-architecture/SKILL.md) skill.

An extension adds stack-specific heuristics under the existing 9 audit dimensions (see [`code-audit.mini.md`](../rules/code-audit.mini.md)). Extensions never introduce a new dimension; new heuristics live under one of the 9.

## Folder convention

```
workflow/skills/audit-architecture-<stack>/SKILL.md
```

`<stack>` is lower-case kebab — `laravel`, `react`, `typescript`, `flutter`, `vue`, `nextjs`, etc. The folder name doubles as a sanity check against the frontmatter `applies_to` field; a folder named `audit-architecture-laravel/` whose frontmatter declares `applies_to.frameworks: ["react"]` is a bug.

Companion artifacts per extension:

- `standards/rules/code-audit-<stack>.mini.md` — dimension-by-dimension heuristics, auto-loaded into the core walk via existing `applies_to.frameworks` / `applies_to.languages` matching (consumed by `bin/emit-rules.sh`).
- `bin/audit-<stack>-helpers.sh` — optional, wraps external tools (linters, static analysers) with `command -v` graceful-degrade gates.

## Frontmatter requirements

Every extension SKILL.md MUST declare:

```yaml
---
name: audit-architecture-<stack>
description: <one-line summary of the heuristics this extension adds>
extends: audit-architecture
applies_to:
  frameworks: ["<stack>", ...]   # one OR both of frameworks/languages must be non-empty
  languages: ["<lang>", ...]
strictness: default              # OR `strict`; defaults to `default` if omitted
---
```

Field rules:

- `extends: audit-architecture` — exact literal. Loader rejects anything else.
- `applies_to.frameworks` and/or `applies_to.languages` — at least one MUST contain a value the loader can match against `bin/detect-tooling.sh --json`. Both empty = orphan extension, loader skips with stderr warning.
- `strictness` — optional. `strict` extensions enforce their own severity floor (see Severity-floor protocol) and disable certain opt-outs. Use only when the stack's audit posture warrants it (Laravel backend = strict).

## Output markdown shape

Extension returns markdown that the core skill stitches into the final report. Two top-level blocks per extension run:

```markdown
## Per-stack findings — <stack>

### Dimension <N> · <dimension name>
- <path>:<line> · <severity> · <one-line problem> · <one-line evidence> · <one-line fix-direction>
- <path>:<line> · <severity> · <one-line problem> · <one-line evidence> · <one-line fix-direction>

### Dimension <M> · <dimension name>
- <path>:<line> · <severity> · ...

## Per-stack appendix — <stack>

(optional: stack-specific tables or sub-sections that don't fit the 9 dimensions — e.g. "N+1 risk per Eloquent relation", "props-bloat leaderboard", "package-cycle map")
```

Rules:

- Use the canonical dimension numbers + names from [`code-audit.mini.md`](../rules/code-audit.mini.md). Renumbering breaks the merge.
- Skip dimensions with zero extension findings — do not pad with "covered, no findings".
- The appendix block is optional; omit when there's nothing stack-specific to surface.
- All paths in finding rows MUST be relative to the audited project root, not to the extension's own location.

## Finding-row format

Identical to the core finding-row format. One line per finding:

```
<path>:<line> · <severity emoji> · <one-line problem statement> · <one-line evidence summary> · <one-line fix direction>
```

- `<path>:<line>` — relative to project root. Multi-line findings: list the *first* offending line.
- `<severity emoji>` — one of 🔴 Blocker · 🟠 High · 🟡 Medium · 🟢 Low. Extensions with `strictness: strict` may forbid 🟢.
- Each clause separated by ` · ` (space-middot-space). The core merge expects this separator to keep the row scannable.
- Rows MUST NOT contain newlines — multi-line evidence collapses to a one-line summary.

The core skill auto-prefixes each row with `[<stack>]` when merging into the final report. Extensions do not need to include the prefix themselves.

## Severity-floor protocol

An extension may declare a per-finding severity floor via the `strictness:` frontmatter field:

- `strictness: default` (or field omitted) — no floor; per-heuristic severity stands.
- `strictness: strict` — floor of 🟡 on all findings; 🟢 forbidden. Individual extensions may further raise the floor for finding sub-classes (e.g. Laravel's API findings floor at 🟠).

The floor is enforced by the extension itself (the loader does not post-process severity), and surfaced in the report header:

```
**Extensions loaded:** audit-architecture-laravel (strict, floor=🟡, api=🟠)
```

## Mode-detect protocol

An extension may expose runtime modes that adjust which heuristics fire. Modes are detected by the extension's helper-script and surfaced in the report header so a reader knows which heuristic set ran.

```
**<Stack> mode:** <mode-name>
```

Examples:
- `**Laravel mode:** api-only` (only API endpoints + `routes/api.php` present; skips view-layer heuristics)
- `**Laravel mode:** full-stack` (Inertia / Livewire / Blade views present)

Mode-detection rules:

- The extension is responsible for the detection logic; the core does not infer modes.
- Modes can be overridden by env var, naming convention `AI_KIT_AUDIT_<STACK>_MODE=<mode-name>` (uppercase stack, lowercase mode).
- An extension with no modes simply does not emit the header line.

## Tool-gate protocol

Helper-scripts wrap external tools (linters, static analysers, package-manager probes). All tool invocations MUST be gated and gracefully degrade when the tool is absent.

```bash
if command -v phpstan >/dev/null 2>&1; then
  # run + parse
  TOOL_STATUS_phpstan="✓"
else
  TOOL_STATUS_phpstan="✗"
fi
```

The extension surfaces tool status in the report header:

```
**Tools ingested:** Larastan ✓ · php artisan about ✓ · composer outdated ✗
```

Rules:

- Tool absence is never fatal — the audit completes without the tool's signal.
- Tool output MUST be cached to `$TMPDIR/ai-kit-audit-<stack>-<timestamp>/` for debuggability (the loader sets the timestamp).
- Format tools (Pint, Prettier, dart format) are out of scope; do not wrap them as findings sources.
- Security scanners (Snyk, npm audit, composer audit) are out of scope; route to `/ai:review` security-deep-pass.

## Loader contract (consumer of this contract)

The core skill calls `bin/audit-extension-loader.sh <project-path>`, which:

1. Globs `workflow/skills/audit-architecture-*/SKILL.md`.
2. Parses each candidate's frontmatter; rejects any whose `extends:` field is missing or not equal to `audit-architecture` (stderr warning, non-fatal skip).
3. Runs `bin/detect-tooling.sh --json` against `<project-path>` for the framework array. Derives a minimal language set from the project shape (current heuristics: `tsconfig.json` → `typescript`; `pubspec.yaml` → `dart`). Future extensions can grow this heuristic without breaking the contract.
4. Matches each extension on `applies_to.frameworks ∪ applies_to.languages` (either intersects → match). At least one of the two lists must be non-empty in the extension's frontmatter.
5. Returns the matched extension paths (one per line on stdout), in stable filename-sorted order.
6. Honours `AI_KIT_AUDIT_NO_EXTEND=1` by returning an empty list (opt-out path).

The core skill is responsible for invoking each matched extension via the Skill tool, capturing the markdown output, and merging it per the rules above.

### Frontmatter list forms

Both YAML list forms are accepted by the loader's parser:

```yaml
# inline
applies_to:
  frameworks: ["react", "nextjs"]

# block
applies_to:
  frameworks:
    - react
    - nextjs
```

### Testing hooks (internal, not part of the public contract)

- `AI_KIT_AUDIT_SKILLS_DIR=<path>` — override the skills directory the loader globs against. Test-only knob; production callers must leave it unset so the loader picks up the bundled extensions.
