---
name: audit-architecture-laravel
description: Laravel-specific architecture audit — 22 strict heuristics across the 9 audit dimensions, with api-only / full-stack mode detection. Always-on strict mode; backend correctness > convenience. Use when `/ai:audit-architecture` runs against a Laravel project (auto-loaded by the extension loader).
extends: audit-architecture
applies_to:
  frameworks: ["laravel"]
  languages: []
strictness: strict
---

# Audit Architecture — Laravel extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). The core skill walks the 9 canonical dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md); this extension adds 22 Laravel-specific heuristics under those same dimensions. **Never introduces a new dimension.**

Loaded automatically by `bin/audit-extension-loader.sh` when `bin/detect-tooling.sh --json` reports `laravel` in the `frameworks` array. Skip with `AI_KIT_AUDIT_NO_EXTEND=1`.

## Strictness

**Strict mode is always on** (`strictness: strict` in frontmatter). Severity floor: 🟡 on all Laravel findings (no 🟢). API findings (L13-L18) floor at 🟠.

Report header surfaces the posture:

```
**Extensions loaded:** audit-architecture-laravel (strict, floor=🟡, api=🟠)
```

## Mode detection

Two modes, surfaced in the report header as `**Laravel mode:** <mode>`:

- `api-only` — `routes/api.php` present + non-trivial; `resources/views/` empty or absent; no Inertia/Livewire markers in `composer.json`.
- `full-stack` — Inertia (`inertiajs/inertia-laravel`), Livewire (`livewire/livewire`), or non-empty `resources/views/` present.

When both signals fire, `full-stack` wins (safer default). Override via `AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack`.

Detection logic lives in `bin/audit-laravel-helpers.sh::detect_mode()`. The core skill is responsible for calling the helper and surfacing the mode in the header.

## Heuristics

22 heuristics encoded in [`standards/rules/code-audit-laravel.mini.md`](../../../standards/rules/code-audit-laravel.mini.md). Each heuristic carries a stable ID `L<N>`, a target dimension, a severity, and a mode-applicability marker.

Summary table (canonical content lives in the rule):

| ID | Dim | Severity | Mode | Heuristic |
|---|---|---|---|---|
| L1 | 6 | 🔴 | both | Eloquent N+1 in loops (relation-in-loop without eager-load) |
| L2 | 2 | 🟠 | both | God-Model > 300 LOC |
| L3 | 7 | 🔴 | both | Domain code importing `Illuminate\Http\Request` |
| L4 | 9 | 🟠 | both | FormRequest absent on POST/PUT/PATCH/DELETE |
| L5 | 4 | 🟡 | both | Unused scopes / Policies / Actions / Jobs / Listeners |
| L6 | 3 | 🟠 | both | Validation duplicated across FormRequest + `$casts` + migration |
| L7 | 1 | 🟠 | both | Service-vs-Action-vs-Job confusion |
| L8 | 8 | 🔴 | both | Job without `failed()` + non-zero retry count |
| L9 | 2 | 🟠 | both | Controller method > 25 LOC |
| L10 | 9 | 🟠 | both | Missing Policy on Eloquent model with public-facing routes |
| L11 | 4 | 🟡 | both | Migration without reversible `down()` |
| L12 | 6 | 🔴 | both | Multi-tenant detected + query without tenant-scope |
| L13 | 8 | 🔴 | both | API route without `throttle:` middleware |
| L14 | 9 | 🟠 | api-only | API endpoint returning Eloquent model directly (no `JsonResource`) |
| L15 | 8 | 🔴 | both | List endpoint without `paginate()` / `cursorPaginate()` |
| L16 | 7 | 🟠 | api-only | API routes missing `/api/v{N}/` prefix |
| L17 | 8 | 🔴 | both | Mutating route without auth middleware |
| L18 | 1 | 🟠 | api-only | Sanctum/Passport not configured but `routes/api.php` non-trivial |
| L19 | 8 | 🟠 | both | Queue driver = `sync` in non-local env |
| L20 | 8 | 🟠 | both | Database driver = `sqlite` in non-local env |
| L21 | 5 | 🟡 | both | `TrimStrings`/`ConvertEmptyStringsToNull` middleware removed from Kernel |
| L22 | 2 | 🔴 | both | Eloquent model with empty `$fillable` + no `$guarded` |

Mode-applicability:
- `both` — fires regardless of mode.
- `api-only` — fires only when mode resolves to `api-only` (L14, L16, L18).

## Process

When invoked by `/ai:audit-architecture` after the core walk:

1. **Detect mode.** Call `bash "$AI_KIT_ROOT/bin/audit-laravel-helpers.sh" detect_mode <project-path>`. Emit `**Laravel mode:** <mode>` in the report header.
2. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-laravel-helpers.sh" run_tools <project-path>` to ingest optional tool output (Larastan, `composer outdated`, `php artisan about`). Tool output is cached under `$TMPDIR/ai-kit-audit-laravel-<timestamp>/` and surfaced as `**Tools ingested:** Larastan ✓ · composer outdated ✗ · ...` in the header.
3. **Walk the heuristics.** For each heuristic in the rule, `grep`/`Read` the project per the rule's evidence pattern. De-duplicate by root-cause: one god-model affecting 12 controllers = one finding with 12 paths, not 12 findings.
4. **Apply severity floor.** Strict mode forbids 🟢. API findings (L13-L18) floor at 🟠. If a heuristic match would resolve below the floor, raise it.
5. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — laravel

### Dimension 6 · Coupling / cohesion
- app/Services/OrderService.php:42 · 🔴 · L1 Eloquent N+1 in loop · `$orders->each(fn ($o) => $o->customer->name)` · eager-load `with(['customer'])` at the query

### Dimension 2 · SOLID
- app/Models/Order.php:1 · 🟠 · L2 God-Model 412 LOC · 6 unrelated jobs (queries + business + casts + scopes + events) · split into `Order` + `OrderQueries` + `OrderLifecycle`

## Per-stack appendix — laravel

### N+1 risk per Eloquent relation
| Relation | Sites | Worst path |
|---|---|---|
| Order->customer | 3 | app/Services/OrderService.php:42 |
```

6. **Hand the markdown back to the core skill.** Do NOT write the report — the core skill stitches per-stack output into the final report via the merge protocol.

## Helper-script

[`bin/audit-laravel-helpers.sh`](../../../bin/audit-laravel-helpers.sh) — three sub-commands:

- `detect_mode <project-path>` — emits `api-only` or `full-stack` on stdout.
- `run_tools <project-path>` — runs Larastan, `composer outdated`, `php artisan about`, all gated by `command -v`. Emits a one-line `Tools ingested: …` header on stdout. Caches per-tool raw output to `$TMPDIR/ai-kit-audit-laravel-<ts>/`.
- `phpstan_level_check <project-path>` — reads `phpstan.neon` / `phpstan.neon.dist`; emits a finding under dimension 9 if `level < 9`.

Tool absence is never fatal. Format tools (Pint) and security scanners (Snyk / composer audit) are out of scope.

## Anti-patterns

- **Re-flagging dimensions the core already handled.** The core walk already surfaced dimension-1 design-pattern violations; Laravel's L7 (Service-vs-Action confusion) adds a Laravel-specific lens on dimension 1 — but don't re-report the same finding the core already wrote.
- **Pre-existing-pattern envy.** Flagging "should use Repositories" in a codebase that has explicitly chosen plain Eloquent (read `docs/adr/` first).
- **Auto-promoting findings into fixes.** This is audit-time, not fix-time. Pipe through `/ai:audit-fix` afterwards.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill (invokes this extension).
- [`code-audit-laravel.mini.md`](../../../standards/rules/code-audit-laravel.mini.md) — 22 heuristics with evidence patterns.
- [`bin/audit-laravel-helpers.sh`](../../../bin/audit-laravel-helpers.sh) — mode-detect + tool-gate helpers.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract spec.
