# audit-laravel-api-only fixture

Fixture for `tests/bin/cases/audit-extensions.sh`. Composer shape resolves to `api-only` via `bin/audit-laravel-helpers.sh::detect_mode` (non-empty `routes/api.php` + empty `resources/views/`).

Every Laravel heuristic L1-L22 has a triggering snippet under `app/` or `routes/`, marked with an inline `// L<N>:` token so the test harness can verify presence via `grep`. The snippets are not full Laravel code — they exist to assert fixture shape, not to be runnable.

When the `audit-architecture-laravel` extension runs against this fixture (post-tracer-bullet), it should surface all 22 findings.
