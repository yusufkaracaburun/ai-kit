# Decisions

- 2026-11-16: Heavy runs are serialised by a wrapper, `ai-kit-heavy-run.sh <cmd>`, that takes an atomic `mkdir` lock at `~/.config/ai-kit/heavy-run.lock/` (holder file with PID, repo, command) and releases it with a trap; a lock whose PID is dead counts as free. A PreToolUse Bash hook denies bare heavy commands and points to the wrapper. A hook alone races because it exits before the command starts. (source: grill #288 + #275)
- 2026-11-16: When the lock is held, the wrapper refuses at once with exit 75 and names the holder; it does not wait. (source: grill #288 + #275)
- 2026-11-16: Heavy means full suites: pest, paratest, phpunit, vitest, jest, playwright, patrol, maestro, xcodebuild, gradle, plus the aliases npm/pnpm/yarn/bun [run] test, composer test, php artisan test. A run with --filter, -t, or a test-file path stays free. (source: grill #288 + #275)
- 2026-11-16: No override. Hooks fire only on Claude's Bash calls, so the user runs a suite in their own terminal or with `!`. (source: grill #288 + #275)
- 2026-11-16: #275 and #288 ship as one slice, Claude Code only; Cursor and Codex follow later, as review-gate did. (source: grill #288 + #275)
- 2026-11-16: heavy-run-gate is not marker-gated, unlike ADR-0018's hooks: the lock is machine-wide, so every repo with the plugin takes it. (source: review #288 + #275)
