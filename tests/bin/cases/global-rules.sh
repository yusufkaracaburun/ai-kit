#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ADR-0015: the plugin ships every universal always-on rule pre-emitted in
# workflow/rules/, and a SessionStart hook keeps ~/.claude/rules/ai-kit
# pointing there. Everything below runs against a throwaway HOME.
SYNC="$AIKIT/bin/sync-plugin-rules.sh"
HOOK="$AIKIT/bin/hooks/global-rules-link.sh"
TOGGLE="$AIKIT/bin/ai-kit-no-global-rules.sh"
RULES="$AIKIT/workflow/rules"

echo "=== sync-plugin-rules: payload matches standards/rules ==="
# section: global-rules-payload
SYNC_CHECK=0; bash "$SYNC" --check >/dev/null 2>&1 || SYNC_CHECK=$?
assert "workflow/rules is in sync with standards/rules (--check exits 0)" '[ "$SYNC_CHECK" -eq 0 ]'
EXPECTED=$(grep -l '^universal: true' "$AIKIT"/standards/rules/*.mini.md "$AIKIT"/standards/rules/feedback/*.mini.md \
  | xargs grep -l '^default_mode: always-on' | wc -l | tr -d ' ')
ACTUAL=$(find "$RULES" -name '*.md' | wc -l | tr -d ' ')
assert "one file per universal always-on rule ($EXPECTED)" '[ "$ACTUAL" = "$EXPECTED" ]'
assert "on-demand universal rule is not in the payload" '[ ! -f "$RULES/code-audit.md" ]'
assert "non-universal stack rule is not in the payload" '[ ! -f "$RULES/laravel-conventions.md" ]'
assert "paths: frontmatter passes through" 'head -2 "$RULES/semver.md" | grep -q "^paths:"'
assert "pathless rule has no frontmatter" '! head -1 "$RULES/pre-write-discipline.md" | grep -q "^---"'
assert "header carries the description" 'head -4 "$RULES/pre-write-discipline.md" | grep -q "ai-kit global rule (ADR-0015): Four gates"'
assert "no ai-kit frontmatter keys leak" '! grep -l "^universal:\|^default_mode:\|^weight:" "$RULES"/*.md | grep -q .'

echo "=== global-rules-link hook ==="
# section: global-rules-hook
TMP_H=$(mktemp -d)
export HOME="$TMP_H"
LINK="$TMP_H/.claude/rules/ai-kit"
PAYLOAD='{"session_id":"s1","cwd":"/x","hook_event_name":"SessionStart","source":"startup"}'
OUT=$(bash "$HOOK" <<<"$PAYLOAD")
assert "hook is silent" '[ -z "$OUT" ]'
assert "hook links ~/.claude/rules/ai-kit at the payload" '[ "$(readlink "$LINK")" = "$RULES" ]'
assert "linked rules are readable through the link" '[ -f "$LINK/pre-write-discipline.md" ]'

ln -sfn "$TMP_H/gone-version/rules" "$LINK"
bash "$HOOK" <<<"$PAYLOAD"
assert "stale link (old plugin version) is re-pointed" '[ "$(readlink "$LINK")" = "$RULES" ]'

rm -f "$LINK"; mkdir -p "$LINK"; : > "$LINK/mine.md"
bash "$HOOK" <<<"$PAYLOAD"
assert "a real directory in the way is never clobbered" '[ ! -L "$LINK" ] && [ -f "$LINK/mine.md" ]'
rm -rf "$LINK"

echo "=== opt-out toggle ==="
# section: global-rules-optout
bash "$HOOK" <<<"$PAYLOAD"
bash "$TOGGLE" on >/dev/null
assert "toggle on writes the marker" '[ -f "$TMP_H/.config/ai-kit/no-global-rules" ]'
assert "toggle on removes the link" '[ ! -e "$LINK" ]'
bash "$HOOK" <<<"$PAYLOAD"
assert "hook respects the opt-out" '[ ! -e "$LINK" ]'
bash "$TOGGLE" off >/dev/null
bash "$HOOK" <<<"$PAYLOAD"
assert "toggle off: next hook run restores the link" '[ "$(readlink "$LINK")" = "$RULES" ]'

echo "=== doctor reports the link ==="
# section: global-rules-doctor
DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"
P="$TMP_H/proj"; mkdir -p "$P/.claude"
doctor_line() { AI_KIT_ROOT="$AIKIT" bash "$DOCTOR" "$P" 2>&1 | grep -i "global rules" || true; }
bash "$HOOK" <<<"$PAYLOAD"
assert "doctor: no global channel → info, not warn" 'doctor_line | grep -q "^  info .*no global channel"'
mkdir -p "$TMP_H/.claude/plugins/cache/yusufkaracaburun/ai"   # plugin installed = global channel
assert "doctor: linked → ok with rule count" 'doctor_line | grep -qE "^  ok .*global rules linked.*\($EXPECTED rules"'
rm -f "$LINK"
assert "doctor: missing → warn" 'doctor_line | grep -q "^  warn .*missing"'
mkdir -p "$TMP_H/.config/ai-kit"
: > "$TMP_H/.config/ai-kit/no-globals"   # the skill-symlink opt-out must not hide the rules check
assert "doctor: still reported under the no-globals opt-out" 'doctor_line | grep -q "^  warn .*missing"'
rm -f "$TMP_H/.config/ai-kit/no-globals"
DOCTOR_PO="$(AI_KIT_ROOT="$AIKIT" bash "$DOCTOR" "$P" --project-only 2>&1 | grep -ci "global rules" || true)"
assert "doctor: --project-only skips the check" '[ "$DOCTOR_PO" = "0" ]'
bash "$TOGGLE" on >/dev/null
assert "doctor: opt-out marker → info" 'doctor_line | grep -q "^  info .*opted out"'
bash "$TOGGLE" off >/dev/null

echo "=== context-lean names the global set ==="
# section: global-rules-context-lean
bash "$HOOK" <<<"$PAYLOAD"
printf '# p\n' > "$P/CLAUDE.md"
LEAN_OUT="$(bash "$AIKIT/bin/ai-kit-context-lean.sh" "$P" 2>&1 || true)"
assert "context-lean prints one note for the global rules" 'echo "$LEAN_OUT" | grep -q "^note: [0-9]* global ai-kit rule(s), [0-9]* words"'

rm -rf "$TMP_H"
print_summary_and_exit
