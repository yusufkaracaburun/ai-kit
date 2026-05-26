---
name: code-audit-laravel
description: Laravel-specific audit heuristics — 22 strict checks across the 9 canonical audit dimensions, with api-only/full-stack mode-applicability. Loaded when the project contains `composer.json` with `laravel/framework`.
applies_to:
  frameworks: ["laravel"]
  languages: ["php"]
  architectures: []
universal: false
default_mode: on-demand
weight: high
repo_age_min_years: 0
---

# OBEY Laravel audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when the project is Laravel-shaped. Layers on top of the stack-agnostic [`code-audit.mini.md`](code-audit.mini.md). Never introduces a new dimension — every heuristic targets one of the canonical 9.

Out of scope: pre-merge diff review (use `/ai:review`), runtime / performance profiling (separate discipline), security scanning (Snyk / composer audit / `/ai:review` security-deep-pass).

## Strictness

Always-on strict mode. Severity floor: 🟡 on all heuristics; 🟢 forbidden. API-tier heuristics (L13-L18) floor at 🟠.

Surfaced in report header: `**Extensions loaded:** audit-architecture-laravel (strict, floor=🟡, api=🟠)`.

## Mode-applicability

Modes (resolved by `bin/audit-laravel-helpers.sh::detect_mode`):

- `api-only` — `routes/api.php` non-empty; `resources/views/` empty/minimal; no Inertia/Livewire in `composer.json`.
- `full-stack` — Inertia/Livewire markers OR non-empty `resources/views/`.
- Both signals → `full-stack` (safer default).
- Override: `AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack`.

Heuristics tagged `api-only` (L14, L16, L18) fire only in api-only mode. Others fire in both modes.

## The 22 heuristics

### Dimension 1 · Design patterns

**L7 — Service-vs-Action-vs-Job confusion (🟠, both)**
A class named `*Service` that contains exactly one public method invoked from exactly one callsite is an Action (single-use case), not a Service. Conversely, a class named `*Action` with >3 unrelated public methods is a Service. Grep evidence: `class .*Service\b` with one public non-constructor method.

**L18 — Sanctum/Passport not configured but `routes/api.php` non-trivial (🟠, api-only)**
`routes/api.php` defines >1 endpoint AND `config/auth.php` has no `api` guard pointing at `sanctum` or `passport`. Evidence: missing `'driver' => 'sanctum'` in `config/auth.php` `guards.api`.

### Dimension 2 · SOLID

**L2 — God-Model > 300 LOC (🟠, both)**
`app/Models/*.php` with > 300 LOC. Smell: model owns queries, business rules, casts, scopes, events, and validation. Split into Model + Query + Lifecycle. Evidence: `wc -l app/Models/*.php`.

**L9 — Controller method > 25 LOC (🟠, both)**
`app/Http/Controllers/**/*.php` method body > 25 LOC. Extract into Action / Service. Evidence: parse method-body LOC.

**L22 — Eloquent model with empty `$fillable` + no `$guarded` (🔴, both)**
Mass-assignment vulnerability. Either `$fillable = ['…']` or `$guarded = []` must be set explicitly. Evidence: grep for `class .* extends Model` and verify presence.

### Dimension 3 · DRY (knowledge-duplication)

**L6 — Validation duplicated across FormRequest + `$casts` + migration (🟠, both)**
Same domain rule encoded in ≥2 places: FormRequest `rules()`, model `$casts`, and migration column constraints. Pick one source of truth (typically FormRequest); the others mirror via reflection or are dropped. Evidence: same field name with matching rules across the three files.

### Dimension 4 · YAGNI / dead-code

**L5 — Unused scopes / Policies / Actions / Jobs / Listeners (🟡, both)**
Public method on a Laravel primitive (scope / Policy / Action / Job / Listener) with no callsite outside the defining module. Evidence: `grep -r "->methodName\|@method" app/`.

**L11 — Migration without reversible `down()` (🟡, both)**
`database/migrations/*.php` with empty or `Schema::dropIfExists()`-only `down()` for a schema change that adds columns/tables. Production rollback breaks. Evidence: grep `public function down()` body length / content.

### Dimension 5 · Naming + comment-drift

**L21 — `TrimStrings`/`ConvertEmptyStringsToNull` middleware removed from Kernel (🟡, both)**
`app/Http/Kernel.php` (or `bootstrap/app.php` in Laravel 11+) is missing one of Laravel's default global middlewares. Likely a leftover from a copy-paste fix; the framework expects them. Evidence: grep `\\TrimStrings::class` and `\\ConvertEmptyStringsToNull::class`.

### Dimension 6 · Coupling / cohesion

**L1 — Eloquent N+1 in loops (🔴, both)**
Relation accessed inside `foreach` / `->each()` without prior `->with()` eager-load on the parent query. Evidence: `$collection->each(fn ($x) => $x->relation->…)` or `foreach ($items as $i) { $i->relation->… }` AND the parent query lacks `->with(['relation'])`.

**L12 — Multi-tenant detected + query without tenant-scope (🔴, both)**
`composer.json` contains `stancl/tenancy` OR `spatie/multitenancy`. Then any Eloquent query in a tenant-context that uses `Model::query()` directly (not via a global scope or `->where('tenant_id', …)`) is a tenant-bleed risk. Evidence: grep `::query()` in `app/` paired with absent global-scope.

### Dimension 7 · Layer / dependency direction

**L3 — Domain code importing `Illuminate\Http\Request` (🔴, both)**
Files under `app/Domain/` / `app/Services/` / `app/Actions/` that `use Illuminate\Http\Request;` couple domain to the HTTP transport. Inject DTOs or primitives. Evidence: grep `use Illuminate\\Http\\Request` outside `app/Http/`.

**L16 — API routes missing `/api/v{N}/` prefix (🟠, api-only)**
`routes/api.php` defines top-level routes without a `Route::prefix('v1')` (or similar versioned) wrapper. First breaking change has no upgrade path. Evidence: grep route definitions and the surrounding `prefix()` calls.

### Dimension 8 · Error handling / failure modes

**L8 — Job without `failed()` + non-zero retry count (🔴, both)**
`app/Jobs/*.php` class without a `failed(Throwable $e)` method AND with `$tries > 1` (default is 1). Retries swallow the failure without a hook. Evidence: grep `class .* implements ShouldQueue` and class-body for `public function failed`.

**L13 — API route without `throttle:` middleware (🔴, both, both modes)**
Any route registered in `routes/api.php` (or any `Route::middleware('api', ...)` group) without `throttle:N,M` middleware. Public abuse vector. Evidence: walk routes + their middleware chain. Note: the heuristic applies in both modes — the canonical API surface always needs throttling.

**L15 — List endpoint without `paginate()` / `cursorPaginate()` (🔴, both)**
Controller returns `Model::all()` or `Model::where(...)->get()` from a route handler that visibly returns a collection (no `take(N)` upstream). Unbounded response. Evidence: grep `return .*->get()` / `->all()` in controllers.

**L17 — Mutating route (POST/PUT/PATCH/DELETE) without auth middleware (🔴, both)**
Route definition for a mutating verb without `auth`, `auth:sanctum`, `auth:passport`, or equivalent in its middleware chain. Evidence: walk route definitions, classify by HTTP verb, check middleware stack.

**L19 — Queue driver = `sync` in non-local env (🟠, both)**
`.env.production` / `.env.staging` (or `config/queue.php` default) resolves to `sync`. Jobs run on the request thread; the queue exists but isn't used. Evidence: grep `QUEUE_CONNECTION=sync`.

**L20 — Database driver = `sqlite` in non-local env (🟠, both)**
`.env.production` / `.env.staging` resolves to `DB_CONNECTION=sqlite`. Concurrency lock-up risk. Evidence: grep `DB_CONNECTION=sqlite` outside `.env` / `.env.local`.

### Dimension 9 · Type safety / contract clarity

**L4 — FormRequest absent on POST/PUT/PATCH/DELETE (🟠, both)**
Mutating controller method accepts `Request $request` instead of a typed `FooRequest` subclass. Validation responsibility leaks into the controller. Evidence: walk controller methods, classify by route's HTTP verb.

**L10 — Missing Policy on Eloquent model with public-facing routes (🟠, both)**
Model bound to a route via `Route::resource()` or implicit binding lacks a registered Policy in `app/Providers/AuthServiceProvider::$policies`. Evidence: walk route-model bindings, cross-check `$policies` map.

**L14 — API endpoint returning Eloquent model directly (no `JsonResource`) (🟠, api-only)**
Controller `return $model` or `return $collection` without wrapping in a `JsonResource` / `ResourceCollection`. Leaks internal column names + accidental fields. Evidence: grep `return .*Model::find` and similar without `new .*Resource(`.

## Severity floor enforcement

Strict mode: all findings ≥ 🟡, all API-tier (L13-L18) findings ≥ 🟠. If a heuristic's "default" severity would resolve below the floor, raise it. Don't pad with 🟢s.

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the Laravel extension emits `## Per-stack findings — laravel` blocks dimension-keyed, the core merges into the final report under each `## N. <dimension>` section, with `[laravel]` row prefix.

## Anti-patterns

- Flagging "no Repository pattern" on a project that has explicitly chosen plain Eloquent (read `docs/adr/` first).
- Re-reporting findings the core already wrote — Laravel-specific lens, not a duplicate dimension walk.
- Promoting 🟡 to 🔴 to "make the audit look serious" — re-triage instead.

## Final checklist

- All 22 heuristics walked (or explicitly skipped with reason — e.g. project is full-stack, skip L14/L16/L18)?
- Severity floor enforced (🟡 minimum, 🟠 minimum on L13-L18)?
- De-duplicated by root-cause, not by symptom?
- Output blocks dimension-keyed per the extension contract?
