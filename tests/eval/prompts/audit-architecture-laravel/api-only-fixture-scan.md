---
id: api-only-fixture-scan
skill: audit-architecture-laravel
expects:
  - detects api-only mode via routes/api.php non-empty + no Inertia/Blade
  - emits report header line `**Laravel mode:** api-only`
  - surfaces all 22 heuristics L1-L22 as dimension-keyed findings
  - applies severity floor 🟡 (no 🟢) with 🟠 floor on L13-L18
  - tools-ingested header line lists Larastan / composer outdated / artisan about with ✓/✗
  - does NOT write the report itself (hands markdown back to the core skill)
---

# Prompt

Run the Laravel audit extension against `tests/fixtures/audit-laravel-api-only/`. Report the mode you detected, the 22 findings dimension-keyed, and the severity-floor enforcement (strict mode; API findings floor at 🟠).
