#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== usage-logging ==="
# section: usage-logging
USAGE_STATE=$(mktemp -d)
unset AI_KIT_USAGE
"$AIKIT/bin/log-skill.sh" diagnose start 2>/dev/null
assert "log-skill no-op without env" '[ ! -f "$USAGE_STATE/ai-kit/usage.jsonl" ]'

XDG_STATE_HOME="$USAGE_STATE" AI_KIT_USAGE=1 "$AIKIT/bin/log-skill.sh" diagnose start
XDG_STATE_HOME="$USAGE_STATE" AI_KIT_USAGE=1 "$AIKIT/bin/log-skill.sh" diagnose "done"
assert "log-skill writes one line per event" '[ "$(wc -l < "$USAGE_STATE/ai-kit/usage.jsonl" | tr -d " ")" = "2" ]'
assert "log line has skill" 'grep -q "\"skill\":\"diagnose\"" "$USAGE_STATE/ai-kit/usage.jsonl"'
assert "log line has no absolute path" '! grep -q "/Users/" "$USAGE_STATE/ai-kit/usage.jsonl"'

STATS_OUT="$(XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-stats.sh" --since=all)"
assert "usage-stats reports diagnose" 'echo "$STATS_OUT" | grep -q "diagnose"'

JSON_OUT="$(XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-stats.sh" --json)"
assert "usage-stats --json parses" 'echo "$JSON_OUT" | grep -q "\"events\":2"'

XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-purge.sh" --yes >/dev/null
assert "usage-purge removes log" '[ ! -f "$USAGE_STATE/ai-kit/usage.jsonl" ]'
rm -rf "$USAGE_STATE"


echo "=== hook-post-skill-log ==="
# section: hook-post-skill-log
HOOK="$AIKIT/bin/hooks/post-skill-log.sh"
assert "hook script exists" '[ -x "$HOOK" ]'

HOOK_STATE=$(mktemp -d)

# Opt-out: hook must no-op without AI_KIT_USAGE=1.
unset AI_KIT_USAGE
echo '{"tool_name":"Skill","tool_input":{"skill":"diagnose","args":""}}' \
  | XDG_STATE_HOME="$HOOK_STATE" "$HOOK"
assert "hook no-op without env" '[ ! -f "$HOOK_STATE/ai-kit/usage.jsonl" ]'

# Happy path: Skill payload + env → exactly one done event.
echo '{"tool_name":"Skill","tool_input":{"skill":"diagnose","args":""}}' \
  | AI_KIT_USAGE=1 XDG_STATE_HOME="$HOOK_STATE" "$HOOK"
assert "hook writes one line on Skill" '[ "$(wc -l < "$HOOK_STATE/ai-kit/usage.jsonl" | tr -d " ")" = "1" ]'
assert "hook logs event=done" 'grep -q "\"event\":\"done\"" "$HOOK_STATE/ai-kit/usage.jsonl"'
assert "hook logs correct skill" 'grep -q "\"skill\":\"diagnose\"" "$HOOK_STATE/ai-kit/usage.jsonl"'

# Non-Skill tool: matcher would normally gate, but the wrapper also guards.
rm -f "$HOOK_STATE/ai-kit/usage.jsonl"
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | AI_KIT_USAGE=1 XDG_STATE_HOME="$HOOK_STATE" "$HOOK"
assert "hook ignores non-Skill tool" '[ ! -f "$HOOK_STATE/ai-kit/usage.jsonl" ]'

# Empty stdin / malformed payload: silent no-op, no crash.
: | AI_KIT_USAGE=1 XDG_STATE_HOME="$HOOK_STATE" "$HOOK"
assert "hook handles empty stdin" '[ ! -f "$HOOK_STATE/ai-kit/usage.jsonl" ]'

echo '{"tool_name":"Skill","tool_input":{"args":"x"}}' \
  | AI_KIT_USAGE=1 XDG_STATE_HOME="$HOOK_STATE" "$HOOK"
assert "hook handles missing skill field" '[ ! -f "$HOOK_STATE/ai-kit/usage.jsonl" ]'

rm -rf "$HOOK_STATE"


echo "=== hook-post-skill-log-via-plugin-layout ==="
# section: hook-post-skill-log-via-plugin-layout
# Simulate the Claude Code plugin install — only the workflow/hooks/ tree is
# reachable from the hook's POV. The script must locate the sibling
# log-skill.sh (not the bin/ copy) and still log correctly.
PLUGIN_ROOT=$(mktemp -d)
mkdir -p "$PLUGIN_ROOT/hooks"
cp "$AIKIT/workflow/hooks/post-skill-log.sh" "$PLUGIN_ROOT/hooks/"
cp "$AIKIT/workflow/hooks/log-skill.sh" "$PLUGIN_ROOT/hooks/"
chmod +x "$PLUGIN_ROOT/hooks/"*.sh
PLUGIN_HOOK="$PLUGIN_ROOT/hooks/post-skill-log.sh"
PLUGIN_STATE=$(mktemp -d)

unset AI_KIT_USAGE
echo '{"tool_name":"Skill","tool_input":{"skill":"diagnose","args":""}}' \
  | XDG_STATE_HOME="$PLUGIN_STATE" "$PLUGIN_HOOK"
assert "plugin hook no-op without env" '[ ! -f "$PLUGIN_STATE/ai-kit/usage.jsonl" ]'

echo '{"tool_name":"Skill","tool_input":{"skill":"diagnose","args":""}}' \
  | AI_KIT_USAGE=1 XDG_STATE_HOME="$PLUGIN_STATE" "$PLUGIN_HOOK"
assert "plugin hook writes log entry" '[ -f "$PLUGIN_STATE/ai-kit/usage.jsonl" ]'
assert "plugin hook logs correct skill" 'grep -q "\"skill\":\"diagnose\"" "$PLUGIN_STATE/ai-kit/usage.jsonl"'
assert "plugin hook log is valid JSON" 'python3 -c "
import json
for line in open(\"$PLUGIN_STATE/ai-kit/usage.jsonl\"):
    json.loads(line)
"'

# The hook MUST resolve its sibling log-skill.sh, not the bin/ copy — prove
# it by removing the sibling and asserting the next invocation no-ops.
rm "$PLUGIN_ROOT/hooks/log-skill.sh"
rm -f "$PLUGIN_STATE/ai-kit/usage.jsonl"
echo '{"tool_name":"Skill","tool_input":{"skill":"diagnose","args":""}}' \
  | AI_KIT_USAGE=1 XDG_STATE_HOME="$PLUGIN_STATE" "$PLUGIN_HOOK"
assert "plugin hook no-op when sibling missing" '[ ! -f "$PLUGIN_STATE/ai-kit/usage.jsonl" ]'

rm -rf "$PLUGIN_ROOT" "$PLUGIN_STATE"


echo "=== hook-context-drift ==="
# section: hook-context-drift
CD_HOOK="$AIKIT/bin/hooks/context-drift-check.sh"
assert "context-drift hook is executable" '[ -x "$CD_HOOK" ]'
# Opt-in: the hook fires only where the marker records it wired.
cd_wire() { echo '{"branches": {"context_drift_hook": "wired"}}' > "$1/.ai-kit-setup"; }

CD_PROJ=$(mktemp -d)
cd_wire "$CD_PROJ"
mkdir -p "$CD_PROJ/src"
echo "code" > "$CD_PROJ/src/session.ts"
echo "Session logic lives in src/session.ts and handles auth." > "$CD_PROJ/CONTEXT.md"

OUT_CD="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PROJ/src/session.ts\"}}" | CLAUDE_PROJECT_DIR="$CD_PROJ" "$CD_HOOK")"
assert "context-drift fires for a doc-referenced file" 'echo "$OUT_CD" | grep -q "context-drift"'
assert "context-drift names the doc" 'echo "$OUT_CD" | grep -q "CONTEXT.md"'
assert "context-drift emits valid JSON" 'echo "$OUT_CD" | python3 -c "import json,sys; json.load(sys.stdin)"'

echo "unrelated" > "$CD_PROJ/src/other.ts"
OUT_CD_NONE="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PROJ/src/other.ts\"}}" | CLAUDE_PROJECT_DIR="$CD_PROJ" "$CD_HOOK")"
assert "context-drift silent for an unreferenced file" '[ -z "$OUT_CD_NONE" ]'

OUT_CD_EMPTY="$(: | CLAUDE_PROJECT_DIR="$CD_PROJ" "$CD_HOOK")"
assert "context-drift handles empty stdin" '[ -z "$OUT_CD_EMPTY" ]'
rm -rf "$CD_PROJ"

CD_NODOCS=$(mktemp -d)
cd_wire "$CD_NODOCS"
echo "x" > "$CD_NODOCS/foo.ts"
OUT_CD_NODOCS="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_NODOCS/foo.ts\"}}" | CLAUDE_PROJECT_DIR="$CD_NODOCS" "$CD_HOOK")"
assert "context-drift silent when no docs exist" '[ -z "$OUT_CD_NODOCS" ]'
rm -rf "$CD_NODOCS"

# Path-pattern triggers — #26 Tier 1. The new code path nudges on edits to
# stack-conventional locations (Laravel models, migrations, policies, etc.)
# even when the file is not yet named in any tracked doc, with a per-category
# reminder message.

echo "=== hook-context-drift-path-pattern-triggers ==="
# section: hook-context-drift-path-pattern-triggers
CD_PP=$(mktemp -d)
cd_wire "$CD_PP"
mkdir -p "$CD_PP/app/Models" "$CD_PP/database/migrations" "$CD_PP/database/seeders" \
         "$CD_PP/app/Policies" "$CD_PP/routes"
touch "$CD_PP/app/Models/User.php" \
      "$CD_PP/database/migrations/2026_01_01_create_users.php" \
      "$CD_PP/database/seeders/UserSeeder.php" \
      "$CD_PP/app/Policies/PostPolicy.php" \
      "$CD_PP/routes/web.php"

OUT_PP_MODEL="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/app/Models/User.php\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: model edit fires drift nudge" 'echo "$OUT_PP_MODEL" | grep -q "context-drift (model)"'
assert "path-pattern: model reminder mentions model docs" 'echo "$OUT_PP_MODEL" | grep -q "model wijziging"'

OUT_PP_MIG="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/database/migrations/2026_01_01_create_users.php\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: migration fires" 'echo "$OUT_PP_MIG" | grep -q "context-drift (migration)"'
assert "path-pattern: migration reminder differs from model" 'echo "$OUT_PP_MIG" | grep -q "stale schema-refs"'

OUT_PP_SEED="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/database/seeders/UserSeeder.php\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: seeder fires with persona-drift reminder" 'echo "$OUT_PP_SEED" | grep -q "persona-drift"'

OUT_PP_POL="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/app/Policies/PostPolicy.php\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: policy fires with authorisatie reminder" 'echo "$OUT_PP_POL" | grep -q "authorisatie-policy"'

OUT_PP_ROUTE="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/routes/web.php\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: route fires with route reminder" 'echo "$OUT_PP_ROUTE" | grep -q "route-definitie"'

# Silent on unrelated path even without any tracked docs present — the
# path-pattern code path must not nudge on every edit.
mkdir -p "$CD_PP/src/components"
touch "$CD_PP/src/components/Header.tsx"
OUT_PP_NONE="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_PP/src/components/Header.tsx\"}}" | CLAUDE_PROJECT_DIR="$CD_PP" "$CD_HOOK")"
assert "path-pattern: silent on non-matching path" '[ -z "$OUT_PP_NONE" ]'

# JSON shape still valid when path-pattern path is the only firer.
assert "path-pattern: emits valid JSON" 'echo "$OUT_PP_MODEL" | python3 -c "import json,sys; json.load(sys.stdin)"'
rm -rf "$CD_PP"

# Project override — .ai-kit/drift-triggers.json replaces built-in defaults.
CD_OV=$(mktemp -d)
cd_wire "$CD_OV"
mkdir -p "$CD_OV/.ai-kit" "$CD_OV/lib/custom"
touch "$CD_OV/lib/custom/widget.ts"
cat > "$CD_OV/.ai-kit/drift-triggers.json" <<'EOF'
{
  "triggers": [
    { "pattern": "lib/custom/", "category": "widget" }
  ],
  "messages": {
    "widget": "widget gewijzigd — bijwerk widget-catalogus"
  }
}
EOF
OUT_OV="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_OV/lib/custom/widget.ts\"}}" | CLAUDE_PROJECT_DIR="$CD_OV" "$CD_HOOK")"
assert "override: project triggers fire" 'echo "$OUT_OV" | grep -q "context-drift (widget)"'
assert "override: project reminder text used" 'echo "$OUT_OV" | grep -q "widget-catalogus"'

# Override REPLACES built-ins — a Laravel-shaped path should NOT fire when
# the override is in effect.
mkdir -p "$CD_OV/app/Models"
touch "$CD_OV/app/Models/User.php"
OUT_OV_LARAVEL="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_OV/app/Models/User.php\"}}" | CLAUDE_PROJECT_DIR="$CD_OV" "$CD_HOOK")"
assert "override: built-in triggers suppressed" '[ -z "$OUT_OV_LARAVEL" ]'
rm -rf "$CD_OV"

# Combined firing — both literal-doc path AND path-pattern can fire on the
# same edit; both messages should appear.
CD_COMB=$(mktemp -d)
cd_wire "$CD_COMB"
mkdir -p "$CD_COMB/app/Models"
echo "code" > "$CD_COMB/app/Models/User.php"
echo "The User model in app/Models/User.php is central to auth." > "$CD_COMB/CONTEXT.md"
OUT_COMB="$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_COMB/app/Models/User.php\"}}" | CLAUDE_PROJECT_DIR="$CD_COMB" "$CD_HOOK")"
assert "combined: literal-doc match still fires" 'echo "$OUT_COMB" | grep -q "CONTEXT.md"'
assert "combined: path-pattern match also fires" 'echo "$OUT_COMB" | grep -q "context-drift (model)"'
assert "combined: emits valid JSON" 'echo "$OUT_COMB" | python3 -c "import json,sys; json.load(sys.stdin)"'
rm -rf "$CD_COMB"


echo "=== hook-context-drift-marker-gate ==="
# section: hook-context-drift-marker-gate
CD_G=$(mktemp -d)
echo "Session logic lives in src/session.ts." > "$CD_G/CONTEXT.md"
CD_G_PAYLOAD="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CD_G/src/session.ts\"}}"
OUT_G="$(echo "$CD_G_PAYLOAD" | CLAUDE_PROJECT_DIR="$CD_G" "$CD_HOOK")"
assert "context-drift silent without .ai-kit-setup" '[ -z "$OUT_G" ]'
echo '{"branches": {}}' > "$CD_G/.ai-kit-setup"
OUT_G="$(echo "$CD_G_PAYLOAD" | CLAUDE_PROJECT_DIR="$CD_G" "$CD_HOOK")"
assert "context-drift silent when the marker has no context_drift_hook" '[ -z "$OUT_G" ]'
"$AIKIT/bin/write-setup-marker.sh" "$CD_G" --context-drift-hook=skipped >/dev/null
OUT_G="$(echo "$CD_G_PAYLOAD" | CLAUDE_PROJECT_DIR="$CD_G" "$CD_HOOK")"
assert "context-drift silent when marker says skipped" '[ -z "$OUT_G" ]'
"$AIKIT/bin/write-setup-marker.sh" "$CD_G" --context-drift-hook=wired >/dev/null
OUT_G="$(echo "$CD_G_PAYLOAD" | CLAUDE_PROJECT_DIR="$CD_G" "$AIKIT/workflow/hooks/context-drift-check.sh")"
assert "plugin copy fires when marker says wired" 'echo "$OUT_G" | grep -q "CONTEXT.md"'
assert "hooks.json registers context-drift on PostToolUse(Edit|Write|MultiEdit)" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
b = [b for b in d[\"hooks\"][\"PostToolUse\"] if any(h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/hooks/context-drift-check.sh\" for h in b[\"hooks\"])]
assert len(b) == 1 and b[0][\"matcher\"] == \"Edit|Write|MultiEdit\", b
"'
rm -rf "$CD_G"


echo "=== privacy ==="
# section: privacy
NET_HITS="$(grep -REn 'curl|wget|/dev/tcp|nc ' "$AIKIT/bin/log-skill.sh" "$AIKIT/bin/usage-stats.sh" "$AIKIT/bin/usage-purge.sh" "$AIKIT/bin/hooks/post-skill-log.sh" "$AIKIT/workflow/hooks/post-skill-log.sh" "$AIKIT/workflow/hooks/log-skill.sh" || true)"
assert "no network calls in usage scripts" '[ -z "$NET_HITS" ]'

print_summary_and_exit
