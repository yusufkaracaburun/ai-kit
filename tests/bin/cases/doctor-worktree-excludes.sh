#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #266: vitest, eslint flat config and tsc do not read .gitignore, so a
# worktree under .agents/worktrees or .claude/worktrees leaks into their runs.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
H="$TMP/home"
mkdir -p "$H/.claude"

run_doctor() {
  HOME="$H" bash "$DOCTOR" "$1" --project-only 2>&1 || true
}

echo "=== configs without worktree excludes ==="
P="$TMP/missing"
mkdir -p "$P"
echo '{}' > "$P/package.json"
printf 'export default defineConfig({ test: { environment: "jsdom" } })\n' > "$P/vite.config.ts"
printf 'export default [{ ignores: ["dist/**"] }]\n' > "$P/eslint.config.js"
printf '{ "exclude": ["node_modules"] }\n' > "$P/tsconfig.json"
OUT="$(run_doctor "$P")"
assert "vitest warned with snippet" \
  'echo "$OUT" | grep -qE "^  warn  vitest .*configDefaults\.exclude, \"\.agents/\*\*\", \"\.claude/\*\*\""'
assert "eslint warned with snippet" \
  'echo "$OUT" | grep -qE "^  warn  eslint .*ignores: \[\"\.agents/\*\*\", \"\.claude/worktrees/\*\*\"\]"'
assert "tsc warned with snippet" \
  'echo "$OUT" | grep -qE "^  warn  tsc .*\"exclude\": \[\"node_modules\", \"\.agents\", \"\.claude\"\]"'

echo "=== vite.config without a test block is not a vitest config ==="
printf 'export default defineConfig({ plugins: [] })\n' > "$P/vite.config.ts"
OUT="$(run_doctor "$P")"
assert "no vitest warn for vite.config without test block" '! echo "$OUT" | grep -q "warn  vitest"'

echo "=== configs that exclude the worktrees ==="
P="$TMP/excluded"
mkdir -p "$P"
echo '{}' > "$P/package.json"
printf 'export default defineConfig({ test: { exclude: [...configDefaults.exclude, ".agents/**", ".claude/**"] } })\n' > "$P/vitest.config.ts"
printf 'export default [{ ignores: [".agents/**", ".claude/worktrees/**"] }]\n' > "$P/eslint.config.mjs"
printf '{ "exclude": ["node_modules", ".agents", ".claude"] }\n' > "$P/tsconfig.json"
OUT="$(run_doctor "$P")"
assert "no worktree warn when configs exclude them" '! echo "$OUT" | grep -qE "warn  (vitest|eslint|tsc) "'
assert "ok line per tool" '[ "$(echo "$OUT" | grep -cE "^  ok    (vitest|eslint|tsc) excludes")" = 3 ]'

echo "=== config covers only one worktree path ==="
printf '{ "exclude": ["node_modules", ".agents"] }\n' > "$P/tsconfig.json"
OUT="$(run_doctor "$P")"
assert "tsc with only .agents warns and names .claude/worktrees" \
  'echo "$OUT" | grep -E "^  warn  tsc " | grep -q "\.claude/worktrees" && ! echo "$OUT" | grep -E "^  warn  tsc " | grep -q "\.agents/worktrees"'

echo "=== no package.json ==="
P="$TMP/nopkg"
mkdir -p "$P"
printf '{ "exclude": ["node_modules"] }\n' > "$P/tsconfig.json"
OUT="$(run_doctor "$P")"
assert "silent without package.json" '! echo "$OUT" | grep -qiE "worktree|warn  tsc"'

print_summary_and_exit
