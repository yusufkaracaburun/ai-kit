#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

WRAP="$AIKIT/bin/ai-kit-heavy-run.sh"
HOOK="$AIKIT/bin/hooks/heavy-run-gate.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"
LOCK="$HOME/.config/ai-kit/heavy-run.lock"

echo "=== heavy-run: wrapper ==="
# section: heavy-run-wrapper
set +e
bash "$WRAP" bash -c 'echo ran >"$1"; [ -d "$2" ]' _ "$TMP/ran" "$LOCK"
RC=$?
set -e
assert "free lock: command runs while the lock is held" '[ "$RC" -eq 0 ] && [ -f "$TMP/ran" ]'
assert "free lock: lock dir gone afterwards" '[ ! -e "$LOCK" ]'
set +e
bash "$WRAP" bash -c 'exit 3'
RC=$?
set -e
assert "failing command: wrapper returns its exit code" '[ "$RC" -eq 3 ]'
assert "failing command: lock dir gone afterwards" '[ ! -e "$LOCK" ]'

mkdir -p "$LOCK"
printf '%s\n%s\n%s\n' "$$" otherrepo "pnpm test" >"$LOCK/holder"
rm -f "$TMP/ran"
set +e
START=$SECONDS
OUT=$(AI_KIT_HEAVY_WAIT=0 bash "$WRAP" touch "$TMP/ran" 2>&1)
RC=$?
set -e
assert "live holder, AI_KIT_HEAVY_WAIT=0: exit 75 at once" '[ "$RC" -eq 75 ] && [ $((SECONDS - START)) -lt 2 ]'
assert "live holder: message names repo, command and pid" \
  'grep -q otherrepo <<<"$OUT" && grep -q "pnpm test" <<<"$OUT" && grep -q "$$" <<<"$OUT"'
assert "live holder: command not run" '[ ! -e "$TMP/ran" ]'
assert "live holder: lock left in place" '[ -f "$LOCK/holder" ]'

set +e
START=$SECONDS
OUT=$(AI_KIT_HEAVY_WAIT=1 bash "$WRAP" touch "$TMP/ran" 2>&1)
RC=$?
set -e
assert "live holder past the wait limit: exit 75 after waiting" '[ "$RC" -eq 75 ] && [ $((SECONDS - START)) -ge 1 ]'
assert "live holder past the wait limit: waiting line and refusal name the holder" \
  'grep -q "waiting" <<<"$OUT" && grep -q "not started" <<<"$OUT" && grep -q otherrepo <<<"$OUT"'
assert "live holder past the wait limit: command not run" '[ ! -e "$TMP/ran" ]'

sleep 2 &
SHORT=$!
printf '%s\n%s\n%s\n' "$SHORT" otherrepo "pnpm test" >"$LOCK/holder"
set +e
OUT=$(AI_KIT_HEAVY_WAIT=10 bash "$WRAP" bash -c 'touch "$1"; exit 4' _ "$TMP/ran" 2>&1)
RC=$?
set -e
wait "$SHORT" || true
assert "holder exits within the limit: wrapper waits, runs, returns the command's exit" \
  '[ "$RC" -eq 4 ] && [ -f "$TMP/ran" ] && [ ! -e "$LOCK" ]'
assert "holder exits within the limit: one waiting line names the holder" \
  '[ "$(grep -c "waiting" <<<"$OUT")" -eq 1 ] && grep -q "pid $SHORT" <<<"$OUT"'
rm -f "$TMP/ran"
mkdir -p "$LOCK"
printf '%s\n%s\n%s\n' "$$" otherrepo "pnpm test" >"$LOCK/holder"

true &
DEAD=$!
wait "$DEAD"
printf '%s\n%s\n%s\n' "$DEAD" otherrepo "pnpm test" >"$LOCK/holder"
set +e
bash "$WRAP" touch "$TMP/ran"
RC=$?
set -e
assert "dead holder: lock taken and command run" '[ "$RC" -eq 0 ] && [ -f "$TMP/ran" ] && [ ! -e "$LOCK" ]'

mkdir -p "$LOCK"
rm -f "$TMP/ran"
set +e
AI_KIT_HEAVY_WAIT=0 bash "$WRAP" touch "$TMP/ran" 2>/dev/null
RC=$?
set -e
assert "fresh lock dir without holder file counts as held" '[ "$RC" -eq 75 ] && [ ! -e "$TMP/ran" ] && [ -d "$LOCK" ]'
touch -t 202601010000 "$LOCK"
bash "$WRAP" touch "$TMP/ran"
assert "lock dir without holder older than a minute counts as free" '[ -f "$TMP/ran" ] && [ ! -e "$LOCK" ]'
assert "stale takeover leaves no .stale dir behind" '[ -z "$(ls -d "$LOCK".stale.* 2>/dev/null)" ]'

mkdir -p "$LOCK"
echo "$$" >"$LOCK/holder"
set +e
OUT=$(AI_KIT_HEAVY_WAIT=0 bash "$WRAP" true 2>&1)
set -e
assert "holder with only a pid still names it" 'grep -q "pid $$" <<<"$OUT"'
rm -rf "$LOCK"

echo "=== heavy-run: gate hook ==="
# section: heavy-run-gate
fire() {
  jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}, cwd: "/tmp"}' |
    bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true
}
for c in "pnpm test" "cd app && composer test" "vendor/bin/pest" "npm run test" "php artisan test" \
  "npx vitest run" "(cd app; yarn test)" "FOO=1 ./vendor/bin/phpunit" "git status; ./gradlew build"; do
  OUT=$(fire "$c")
  assert "deny with the wrapper path: $c" 'grep -qF "$WRAP" <<<"$OUT"'
done
for c in "pnpm --filter web test" "pnpm -C app test" "npm --prefix app test" "timeout 600 pnpm test" \
  "timeout 10m vendor/bin/pest" "cd x && $WRAP pnpm test; pnpm test"; do
  OUT=$(fire "$c")
  assert "deny with the wrapper path: $c" 'grep -qF "$WRAP" <<<"$OUT"'
done
for c in "vite build" "npx vite build" "pnpm exec next build" "./node_modules/.bin/astro build" "pnpm vite build" \
  "pnpm build" "yarn build" "npm run build" "bun run build" "pnpm -C app build" \
  "pnpm install --frozen-lockfile" "pnpm i" "npm ci" "npm install" "npm i" "yarn install" "bun install" \
  "npm --prefix app ci" "cd app && pnpm install" "pnpm build --filter web" "npm run build -- -t x"; do
  OUT=$(fire "$c")
  assert "deny build or install with the wrapper path: $c" 'grep -qF "$WRAP" <<<"$OUT"'
done
OUT=$(fire "cd app && composer test")
assert "deny echoes the full command with only the heavy segment wrapped" \
  'grep -qF "Rerun as: cd app && $WRAP composer test" <<<"$OUT"'
for pair in "if true; then pnpm test; fi|if true; then $WRAP pnpm test; fi" \
  "for x in a; do pnpm test; done|for x in a; do $WRAP pnpm test; done" \
  "{ pnpm test; }|{ $WRAP pnpm test; }" "! pnpm test|! $WRAP pnpm test" \
  "timeout 600 pnpm test|$WRAP timeout 600 pnpm test"; do
  OUT=$(fire "${pair%%|*}")
  assert "deny wraps right before the command: ${pair%%|*}" 'grep -qF "Rerun as: ${pair#*|}" <<<"$OUT"'
done
OUT=$(fire "FOO=1 pnpm test 2>&1 | tail -3")
assert "deny keeps env assignments in front of the wrapper" \
  'grep -qF "Rerun as: FOO=1 $WRAP pnpm test 2>&1 | tail -3" <<<"$OUT"'
ESCAPED_QUOTE_LOAD_CHECK=$(cat <<'EOF'
grep -rE "operations\[ *[\"'\`][A-Za-z.]+_[0-9]+" src | grep -v types/api.d.ts; echo "criterion1 exit=$?"; ps -Ao args | grep -E 'pes[t]|paratest|phpunit|playwright|patrol|maestro|xcodebuild|gradle' | grep -v grep; echo "load-check done"
EOF
)
OUT=$(fire 'echo "a\"b'"'"'c"; pnpm test')
assert "deny after an escaped quote inside double quotes" \
  'grep -qF "Rerun as: echo \"a\\\"b'"'"'c\"; $WRAP pnpm test" <<<"$OUT"'
for c in "$WRAP pnpm test" "cd app && $WRAP composer test" "$WRAP vendor/bin/pest" \
  "vendor/bin/pest --filter Foo" "vendor/bin/pest --filter=Foo" "pnpm vitest run src/a.test.ts" \
  "pnpm test -t name" "vendor/bin/pest tests/Feature/FooTest.php" "npx playwright test e2e/login.spec.ts" \
  "pnpm --filter web test --filter Foo" "npx playwright install" "npx playwright install --with-deps chromium" \
  "npx playwright show-report" "npx playwright codegen" "vitest --version" "xcodebuild -version" \
  "xcodebuild -workspace App.xcworkspace -list" "xcodebuild -list" "git status" "ls" "git commit -m 'run pnpm test; then jest'" "grep -r vitest package.json" "pnpm test:unit" \
  'git commit -m "run pnpm test"' "$ESCAPED_QUOTE_LOAD_CHECK" \
  "vite" "pnpm vite" "npx vite --port 3000" "next dev" "npx next dev" "astro dev" "tsc --noEmit" \
  "pnpm exec tsc --noEmit" "eslint ." "npx eslint ." "pnpm add zod" "pnpm build:css" "$WRAP pnpm install" \
  "composer build" "php artisan build"; do
  OUT=$(fire "$c")
  assert "allow: $c" '[ -z "$OUT" ]'
done
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1)
EMPTY_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
PLUGIN_OUT=$(jq -n '{tool_input: {command: "pnpm test"}}' | bash "$AIKIT/workflow/bin/hooks/heavy-run-gate.sh" |
  jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
assert "plugin path resolves the wrapper in bin/" \
  'grep -qF "$AIKIT/workflow/bin/ai-kit-heavy-run.sh pnpm test" <<<"$PLUGIN_OUT"'

echo "=== heavy-run: plugin delivery ==="
# section: heavy-run-plugin
assert "hooks.json registers heavy-run-gate once, on PreToolUse matcher Bash" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
hits = [(ev, b[\"matcher\"]) for ev, bs in d[\"hooks\"].items() for b in bs for h in b[\"hooks\"]
        if h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/bin/hooks/heavy-run-gate.sh\"]
assert hits == [(\"PreToolUse\", \"Bash\")], hits
"'
assert "no agent or skill still carries the ps heavy-run check" \
  '! grep -rlE "ps -Ao args \| grep" "$AIKIT/workflow/agents" "$AIKIT/workflow/skills"'

print_summary_and_exit
