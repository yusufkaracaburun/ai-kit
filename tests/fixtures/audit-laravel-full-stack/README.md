# audit-laravel-full-stack fixture

Fixture for `tests/bin/cases/audit-extensions.sh`. Composer shape resolves to `full-stack` via `bin/audit-laravel-helpers.sh::detect_mode` (Inertia present in `composer.json` + a Blade view exists under `resources/views/`).

Every Laravel heuristic that fires in `full-stack` mode has a triggering snippet — that's L1-L13, L15, L17, L19-L22 (19 heuristics).

The three api-only-only heuristics (L14, L16, L18) intentionally have **no** trigger markers in this fixture, so the test asserting "full-stack omits api-only triggers" passes.
