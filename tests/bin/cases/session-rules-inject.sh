#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/session-rules-inject.sh"
CTX() {
  # CTX <project_dir> -> prints additionalContext, empty if silent. Honours
  # any env already set on the calling command (e.g. AI_KIT_SESSION_RULES_MAX_WORDS=N CTX ...).
  CLAUDE_PROJECT_DIR="$1" "$HOOK" </dev/null | python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null || true
}

echo "=== session-rules-inject: basics ==="
# section: session-rules-inject-basics
assert "hook script exists + executable" '[ -x "$HOOK" ]'

TMP_NONE=$(mktemp -d)
assert "no .claude/rules -> report is empty" \
  '[ "$(CLAUDE_PROJECT_DIR="$TMP_NONE" "$HOOK" --report </dev/null)" = "rules=0 words=0 (no .claude/rules in project)" ]'
assert "no .claude/rules -> silent JSON output" '[ -z "$(CTX "$TMP_NONE")" ]'
rm -rf "$TMP_NONE"


echo "=== session-rules-inject: selection (weight + mode gates) ==="
# section: session-rules-inject-selection
TMP_SEL=$(mktemp -d)
# secrets-hygiene: universal, weight high, default_mode always-on.
"$AIKIT/bin/emit-rules.sh" "$TMP_SEL" --rules secrets-hygiene --agents claude-code >/dev/null
# testing-pyramid: universal, weight medium, default_mode always-on — must
# NOT be injected even though the project emitted it as always-on.
"$AIKIT/bin/emit-rules.sh" "$TMP_SEL" --rules testing-pyramid --agents claude-code >/dev/null
# refactoring: universal, weight medium, default_mode on-demand by default;
# force always-on via --mode to isolate the weight gate from the mode gate.
"$AIKIT/bin/emit-rules.sh" "$TMP_SEL" --rules refactoring --agents claude-code --mode always-on >/dev/null
# aposd: universal, weight medium, on-demand by default — left on-demand, to
# prove the mode gate independently of weight (aposd would otherwise be
# excluded by weight anyway, so also emit a high-weight rule forced on-demand).
"$AIKIT/bin/emit-rules.sh" "$TMP_SEL" --rules pre-write-discipline --agents claude-code --mode on-demand >/dev/null

OUT_SEL="$(CTX "$TMP_SEL")"
assert "high-weight always-on rule is injected" 'grep -q "# secrets-hygiene" <<<"$OUT_SEL"'
assert "medium-weight always-on rule is excluded" '! grep -q "# testing-pyramid" <<<"$OUT_SEL"'
assert "medium-weight forced-always-on rule still excluded (weight gate)" '! grep -q "# refactoring" <<<"$OUT_SEL"'
assert "high-weight rule emitted as on-demand is excluded (mode gate)" '! grep -q "# pre-write-discipline" <<<"$OUT_SEL"'
assert "selection emits valid JSON" \
  'CLAUDE_PROJECT_DIR="$TMP_SEL" "$HOOK" </dev/null | python3 -c "import json,sys; json.load(sys.stdin)"'
rm -rf "$TMP_SEL"


echo "=== session-rules-inject: budget cutoff, smallest-first ==="
# section: session-rules-inject-budget
TMP_BUD=$(mktemp -d)
"$AIKIT/bin/emit-rules.sh" "$TMP_BUD" --rules secrets-hygiene,context7,domain-model-first --agents claude-code >/dev/null
# Real word counts (stripped body): secrets-hygiene ~316, context7 ~288,
# domain-model-first ~709 — secrets-hygiene and context7 both fit a small
# budget that domain-model-first alone would blow past.
REPORT_TIGHT="$(AI_KIT_SESSION_RULES_MAX_WORDS=650 CLAUDE_PROJECT_DIR="$TMP_BUD" "$HOOK" --report </dev/null)"
assert "tight budget selects 2 of 3 candidates" 'grep -q "^rules=2 " <<<"$REPORT_TIGHT"'
assert "tight budget stays at or under the cap" \
  'w=$(sed -n "s/^rules=[0-9]* words=\([0-9]*\).*/\1/p" <<<"$REPORT_TIGHT"); [ "$w" -le 650 ]'

OUT_TIGHT="$(AI_KIT_SESSION_RULES_MAX_WORDS=650 CTX "$TMP_BUD")"
assert "smallest two rules included under tight budget" \
  'grep -q "# secrets-hygiene" <<<"$OUT_TIGHT" && grep -q "# context7" <<<"$OUT_TIGHT"'
assert "largest rule dropped under tight budget" '! grep -q "# domain-model-first" <<<"$OUT_TIGHT"'

REPORT_ZERO="$(AI_KIT_SESSION_RULES_MAX_WORDS=1 CLAUDE_PROJECT_DIR="$TMP_BUD" "$HOOK" --report </dev/null)"
assert "budget of 1 word selects nothing (every candidate exceeds it)" 'grep -q "^rules=0 " <<<"$REPORT_ZERO"'
rm -rf "$TMP_BUD"


echo "=== session-rules-inject: opt-out ==="
# section: session-rules-inject-opt-out
TMP_OO=$(mktemp -d)
"$AIKIT/bin/emit-rules.sh" "$TMP_OO" --rules secrets-hygiene --agents claude-code >/dev/null
TMP_OO_HOME=$(mktemp -d)
mkdir -p "$TMP_OO_HOME/.config/ai-kit"
: > "$TMP_OO_HOME/.config/ai-kit/no-rule-injection"

assert "opt-out marker silences the hook" \
  '[ -z "$(HOME="$TMP_OO_HOME" CLAUDE_PROJECT_DIR="$TMP_OO" "$HOOK" </dev/null)" ]'
REPORT_OO="$(HOME="$TMP_OO_HOME" CLAUDE_PROJECT_DIR="$TMP_OO" "$HOOK" --report </dev/null)"
assert "opt-out report says rules=0 words=0" 'grep -q "^rules=0 words=0" <<<"$REPORT_OO"'
assert "opt-out report names the marker" 'grep -q "opt-out active" <<<"$REPORT_OO"'

rm -rf "$TMP_OO" "$TMP_OO_HOME"


echo "=== session-rules-inject: toggle script ==="
# section: session-rules-inject-toggle
TOGGLE="$AIKIT/bin/ai-kit-no-rule-injection.sh"
assert "toggle script exists" '[ -x "$TOGGLE" ]'

TMP_TOGGLE_HOME=$(mktemp -d)
assert "toggle status OFF by default" 'HOME="$TMP_TOGGLE_HOME" "$TOGGLE" status | grep -q "Opt-out: OFF"'
HOME="$TMP_TOGGLE_HOME" "$TOGGLE" on >/dev/null
assert "toggle on: creates marker" '[ -f "$TMP_TOGGLE_HOME/.config/ai-kit/no-rule-injection" ]'
assert "toggle status ON after on" 'HOME="$TMP_TOGGLE_HOME" "$TOGGLE" status | grep -q "Opt-out: ON"'
HOME="$TMP_TOGGLE_HOME" "$TOGGLE" off >/dev/null
assert "toggle off: removes marker" '[ ! -f "$TMP_TOGGLE_HOME/.config/ai-kit/no-rule-injection" ]'
rm -rf "$TMP_TOGGLE_HOME"


echo "=== session-rules-inject: malformed / missing input never crashes ==="
# section: session-rules-inject-malformed
TMP_MAL=$(mktemp -d)
mkdir -p "$TMP_MAL/.claude/rules"
printf 'garbage\nno header at all\njust text\n' > "$TMP_MAL/.claude/rules/bogus.md"
assert "malformed header: silent, no crash" \
  'OUT=$(CLAUDE_PROJECT_DIR="$TMP_MAL" "$HOOK" </dev/null); RC=$?; [ -z "$OUT" ] && [ "$RC" -eq 0 ]'

printf '<!-- Generated by ai-kit @ 1.0 from standards/rules/does-not-exist.mini.md -->\n<!-- Mode: always-on. Re-emit with: bin/emit-rules.sh <project> -->\n\nbody\n' \
  > "$TMP_MAL/.claude/rules/does-not-exist.md"
assert "unresolvable source rule: silent, no crash" \
  'OUT=$(CLAUDE_PROJECT_DIR="$TMP_MAL" "$HOOK" </dev/null); RC=$?; [ -z "$OUT" ] && [ "$RC" -eq 0 ]'
rm -rf "$TMP_MAL"

TMP_NOSTD=$(mktemp -d)
mkdir -p "$TMP_NOSTD/.claude/rules"
"$AIKIT/bin/emit-rules.sh" "$TMP_NOSTD" --rules secrets-hygiene --agents claude-code >/dev/null
BROKEN_HOOK_DIR=$(mktemp -d)
mkdir -p "$BROKEN_HOOK_DIR/hooks"
cp "$HOOK" "$BROKEN_HOOK_DIR/hooks/"
REPORT_NOSTD="$(CLAUDE_PROJECT_DIR="$TMP_NOSTD" "$BROKEN_HOOK_DIR/hooks/session-rules-inject.sh" --report </dev/null)"
assert "no bundled standards/ dir: reports 0, no crash" 'grep -q "^rules=0 words=0" <<<"$REPORT_NOSTD"'
assert "no bundled standards/ dir: names the reason" 'grep -q "no standards/rules found" <<<"$REPORT_NOSTD"'
rm -rf "$TMP_NOSTD" "$BROKEN_HOOK_DIR"

: | "$HOOK" >/dev/null 2>&1
assert "empty stdin exits clean" '[ "$?" -eq 0 ]'


echo "=== session-rules-inject: plugin layout (workflow/) resolves the same ==="
# section: session-rules-inject-plugin-layout
TMP_PLUGIN=$(mktemp -d)
cp -r "$AIKIT/workflow/hooks" "$TMP_PLUGIN/hooks"
cp -r "$AIKIT/workflow/standards" "$TMP_PLUGIN/standards"
TMP_PROJ_PL=$(mktemp -d)
"$AIKIT/bin/emit-rules.sh" "$TMP_PROJ_PL" --rules secrets-hygiene --agents claude-code >/dev/null
REPORT_PLUGIN="$(CLAUDE_PROJECT_DIR="$TMP_PROJ_PL" "$TMP_PLUGIN/hooks/session-rules-inject.sh" --report </dev/null)"
assert "plugin-layout copy selects the same rule" 'grep -q "^rules=1 " <<<"$REPORT_PLUGIN"'
rm -rf "$TMP_PLUGIN" "$TMP_PROJ_PL"


echo "=== session-rules-inject: hooks.json wiring ==="
# section: session-rules-inject-hooks-json
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "hooks.json is valid JSON" 'python3 -c "import json; json.load(open(\"$HOOKS_JSON\"))"'
assert "hooks.json registers SessionStart" \
  'python3 -c "
import json
d = json.load(open(\"$HOOKS_JSON\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"SessionStart\"] for h in b[\"hooks\"]]
assert any(\"session-rules-inject.sh\" in c for c in cmds), cmds
"'
assert "hooks.json PostToolUse entry untouched" \
  'python3 -c "
import json
d = json.load(open(\"$HOOKS_JSON\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"PostToolUse\"] for h in b[\"hooks\"]]
assert any(\"post-skill-log.sh\" in c for c in cmds), cmds
"'

print_summary_and_exit
