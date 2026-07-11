#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# apply-caveman.sh writes to ~/.claude/settings.json and caveman's own config.
# Every case here runs with HOME + XDG_CONFIG_HOME redirected into a temp dir,
# so the developer's real machine is never touched.
#
# NOT COVERED: the install path itself (`claude plugin marketplace add` /
# `claude plugin install`). It shells out to the real Claude Code CLI and would
# hit the network, so it is exercised by hand, not here. What IS covered is
# everything around it: state detection, the de-duplication guard, mode
# validation, and idempotency.

caveman() {
  # caveman <sandbox_home> [args...]
  local home="$1"; shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" bash "$AIKIT/bin/apply-caveman.sh" "$@"
}

seed_settings() {
  # seed_settings <sandbox_home> <plugin_enabled:true|false> <with_dupe_hooks:yes|no>
  local home="$1" enabled="$2" dupes="$3"
  mkdir -p "$home/.claude"
  python3 - "$home/.claude/settings.json" "$enabled" "$dupes" <<'PY'
import json, sys
path, enabled, dupes = sys.argv[1:4]
data = {"enabledPlugins": {"caveman@caveman": enabled == "true"}}
if dupes == "yes":
    data["hooks"] = {
        "SessionStart": [
            {"hooks": [{"type": "command", "command": "node ~/.claude/hooks/caveman-activate.js"}]},
            {"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/rename-detector.sh"}]},
        ],
        "UserPromptSubmit": [
            {"hooks": [{"type": "command", "command": "node ~/.claude/hooks/caveman-mode-tracker.js"}]}
        ],
    }
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
}

echo "=== apply-caveman --status ==="
# section: apply-caveman-status
TMP_S=$(mktemp -d)
seed_settings "$TMP_S" true yes
OUT=$(caveman "$TMP_S" --status)
assert "status reports plugin enabled" 'grep -q "plugin enabled    : yes" <<<"$OUT"'
assert "status counts duplicate hooks" 'grep -qE "duplicate hooks   : 2" <<<"$OUT"'
assert "status reports unset mode" 'grep -q "default mode      : (unset" <<<"$OUT"'
assert "status mutates nothing" '! grep -q "removed" <<<"$OUT"'
rm -rf "$TMP_S"

echo "=== apply-caveman --dedupe-only ==="
# section: apply-caveman-dedupe
# caveman's own installer writes standalone hook copies into settings.json while
# the plugin manifest already declares the same hooks — so they fire twice per
# event. Strip the standalone copies, keep everything else.
TMP_D=$(mktemp -d)
seed_settings "$TMP_D" true yes
caveman "$TMP_D" --dedupe-only >/dev/null
assert "caveman hooks stripped, unrelated hook kept" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_D/.claude/settings.json\"))
hooks = d.get(\"hooks\", {})
cmds = [h[\"command\"] for e in hooks.get(\"SessionStart\", []) for h in e[\"hooks\"]]
assert not any(\"caveman-\" in c for c in cmds), cmds
assert any(\"rename-detector\" in c for c in cmds), cmds
assert \"UserPromptSubmit\" not in hooks, hooks
"'
assert "backup written before mutating" '[ -d "$TMP_D/.claude/.backups" ]'

OUT=$(caveman "$TMP_D" --dedupe-only)
assert "dedupe is idempotent" 'grep -q "no duplicate caveman hooks" <<<"$OUT"'
rm -rf "$TMP_D"

echo "=== apply-caveman: dedupe guard when plugin is NOT enabled ==="
# Removing the standalone hooks on a machine WITHOUT the plugin would disable
# caveman outright — the plugin manifest is what keeps it alive after the strip.
TMP_G=$(mktemp -d)
seed_settings "$TMP_G" false yes
OUT=$(caveman "$TMP_G" --dedupe-only)
assert "refuses to strip when plugin is absent" 'grep -q "Leaving them alone" <<<"$OUT"'
assert "hooks still present" \
  'grep -q "caveman-activate" "$TMP_G/.claude/settings.json"'
rm -rf "$TMP_G"

echo "=== apply-caveman: malformed settings.json ==="
TMP_M=$(mktemp -d)
mkdir -p "$TMP_M/.claude"
echo 'not json {{{' > "$TMP_M/.claude/settings.json"
assert "refuses to touch malformed settings.json" \
  '! caveman "$TMP_M" --status >/dev/null 2>&1'
rm -rf "$TMP_M"

echo "=== apply-caveman: mode validation ==="
# section: apply-caveman-mode
# An invalid mode must fail loudly. caveman's config resolver silently ignores an
# unknown defaultMode and falls back to 'full' — so a typo would otherwise write
# a config that looks applied but does nothing.
TMP_V=$(mktemp -d)
seed_settings "$TMP_V" true no
assert "invalid mode is rejected" \
  '! caveman "$TMP_V" --mode=blorp >/dev/null 2>&1'
assert "no config written on rejection" \
  '[ ! -f "$TMP_V/.config/caveman/config.json" ] || ! grep -q blorp "$TMP_V/.config/caveman/config.json"'
rm -rf "$TMP_V"

print_summary_and_exit
