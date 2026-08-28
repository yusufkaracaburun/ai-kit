---
name: laravel-conventions
description: Laravel idioms — Eloquent, Artisan, queues, validation, multi-tenancy patterns the framework expects
applies_to:
  frameworks: ["laravel"]
  languages: []
  architectures: ["backend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Laravel conventions

Laravel rewards working *with* the framework's grain. Code that fights it
becomes brittle the moment you touch Eloquent, queues, or middleware.

## Eloquent

- Prefer **query scopes** over chained `where()` repeated across the app.
  Name them as the business operation (`->active()`, `->forTenant($id)`).
- Eager-load with `with(['relation:id,name'])` — narrow column list.
  N+1 queries are debt, not optimisation.
- Use **route-model binding** (`Route::get('/users/{user}', ...)`) instead
  of `User::findOrFail($id)` in every controller.
- Cast types on the model (`protected $casts = ['settings' => 'array']`),
  not in callers.
- `$fillable` over `$guarded = []`. Mass-assignment vulnerabilities are
  free if you skip this.

## Validation

- Form Requests, not inline `Validator::make()`. One per action.
- Validation messages live in `lang/<locale>/validation.php` overrides, not
  inline string literals.
- Authorize first (`authorize()` method), then validate. Never the
  opposite.

## Queues + jobs

- Long-running work goes in a Job dispatched with `dispatch()` /
  `dispatch_sync()` for tests. Never block an HTTP request on > 1 s of work.
- Jobs are **idempotent** — assume they'll be retried after timeout.
- Use `WithoutOverlapping` middleware on jobs that touch shared state.
- Failure handling lives in `failed()` on the Job, not in the consumer.

## Artisan + console

- Custom commands live in `app/Console/Commands/`. Schedule them in
  `app/Console/Kernel.php` `schedule()` — never via crontab outside the app.
- Long output goes through `$this->info()`/`$this->warn()`, not `echo`.

## Multi-tenancy

- Scope **at the Eloquent layer** with a Global Scope or `BelongsToTenant`
  trait. Never re-implement `where('tenant_id', ...)` in every query.
- Tenant resolution belongs in middleware that runs before any controller.
- Tests use a per-test tenant; never share tenant state across tests.
- **Uniqueness on a tenant-supplied value is compound with the tenant key**,
  never global. A globally unique column on a tenant-owned table lets the
  first tenant to use a value lock every other tenant out, and it surfaces as
  a constraint violation on a value the second tenant has never seen.
- **Isolation needs two tenants in the fixture.** A test with one tenant
  passes whether or not scoping works — there is nothing to leak. The
  assertion that proves it is "tenant A's query does not return tenant B's
  row", and that requires B to exist. Same for the uniqueness rule above:
  assert both that two tenants may hold the same value and that one tenant
  may not hold it twice.

## Stack-specific don'ts

- Don't `DB::table(...)` when an Eloquent model exists — bypasses casts,
  scopes, events, observers.
- Don't put business logic in controllers. Action / Service classes or
  invokable jobs are the right home.
- Don't subclass `Model` to add cross-cutting behaviour — use traits or
  base abstract models per bounded context.

## See also

- [`api-design.mini.md`](./api-design.mini.md) — Laravel API resources +
  Sanctum/Passport conventions.
- [`twelve-factor.mini.md`](./twelve-factor.mini.md) — config-in-env via
  Laravel's `.env`, not committed.
- Laravel docs: https://laravel.com/docs
