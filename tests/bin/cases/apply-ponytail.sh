#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# apply-ponytail.sh reads ~/.claude/settings.json and writes ponytail's own
# config. Every case here runs with HOME + XDG_CONFIG_HOME redirected into a
# temp dir, so the developer's real machine is never touched.
#
# NOT COVERED: the install path itself (`claude plugin marketplace add` /
# `claude plugin install`). It shells out to the real Claude Code CLI and would
# hit the network, so it is exercised by hand. What IS covered is everything
# around it: state detection, mode validation, malformed-input refusal, and
# idempotency — plus the two deliberate divergences from apply-caveman.sh
# (a different VALID mode set, and no dedupe path).

ponytail() {
  # ponytail <sandbox_home> [args...]
  local home="$1"; shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" bash "$AIKIT/bin/apply-ponytail.sh" "$@"
}

seed_settings() {
  # seed_settings <sandbox_home> <plugin_enabled:true|false> [marketplace:yes|no]
  local home="$1" enabled="$2" mkt="${3:-no}"
  mkdir -p "$home/.claude"
  python3 - "$home/.claude/settings.json" "$enabled" "$mkt" <<'PY'
import json, sys
path, enabled, mkt = sys.argv[1:4]
data = {"enabledPlugins": {"ponytail@ponytail": enabled == "true"}}
if mkt == "yes":
    data["extraKnownMarketplaces"] = {"ponytail": {"source": {"source": "github"}}}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
}

echo "=== status-reporting ==="

H="$(mktemp -d)"; seed_settings "$H" false
OUT="$(ponytail "$H" --status)"
assert "status reports plugin not enabled" 'echo "$OUT" | grep -qE "plugin enabled    : no"'
assert "status reports marketplace unknown" 'echo "$OUT" | grep -qE "marketplace known : no"'
assert "status reports unset mode fallback" 'echo "$OUT" | grep -q "falls back to ponytail"'
assert "status changes nothing" '[ ! -f "$H/.config/ponytail/config.json" ]'
rm -rf "$H"

H="$(mktemp -d)"; seed_settings "$H" true yes
OUT="$(ponytail "$H" --status)"
assert "status detects enabled plugin" 'echo "$OUT" | grep -qE "plugin enabled    : yes"'
assert "status detects known marketplace" 'echo "$OUT" | grep -qE "marketplace known : yes"'
rm -rf "$H"

echo "=== malformed-input refusal ==="

H="$(mktemp -d)"; mkdir -p "$H/.claude"
echo '{ this is not json' > "$H/.claude/settings.json"
RC=0; ERR="$(ponytail "$H" --status 2>&1)" || RC=$?
assert "malformed settings.json refused, non-zero exit" '[ "$RC" -ne 0 ]'
assert "refusal names the file" 'echo "$ERR" | grep -q "refusing to touch it"'
rm -rf "$H"

# Divergence from apply-caveman.sh: ponytail's own config is the ONLY file this
# script writes, so a malformed one must refuse rather than reset — it may hold
# keys we do not own (hideStatus, quietStartup).
H="$(mktemp -d)"; seed_settings "$H" true
mkdir -p "$H/.config/ponytail"
echo 'not json at all' > "$H/.config/ponytail/config.json"
RC=0; ERR="$(ponytail "$H" --mode lite 2>&1)" || RC=$?
assert "malformed ponytail config refused, non-zero exit" '[ "$RC" -ne 0 ]'
assert "refusal says it will not overwrite" 'echo "$ERR" | grep -q "refusing to overwrite"'
assert "malformed config left untouched" 'grep -q "not json at all" "$H/.config/ponytail/config.json"'
rm -rf "$H"

echo "=== mode validation ==="

# Validation must happen BEFORE the install path runs, so an invalid mode never
# reaches `claude plugin install`.
H="$(mktemp -d)"; seed_settings "$H" false
RC=0; ERR="$(ponytail "$H" --mode blorp 2>&1)" || RC=$?
assert "invalid mode exits 2" '[ "$RC" -eq 2 ]'
assert "invalid mode names the valid set" 'echo "$ERR" | grep -q "off, lite, full, ultra"'
assert "invalid mode did not add a marketplace" '! grep -q extraKnownMarketplaces "$H/.claude/settings.json"'
rm -rf "$H"

# 'review' is a runtime-only mode upstream (RUNTIME_MODES in
# hooks/ponytail-config.js) — deliberately not persistable as a default.
H="$(mktemp -d)"; seed_settings "$H" false
RC=0; ponytail "$H" --mode review >/dev/null 2>&1 || RC=$?
assert "runtime-only mode 'review' is rejected as a default" '[ "$RC" -eq 2 ]'
rm -rf "$H"

echo "=== uninstall + idempotency ==="

H="$(mktemp -d)"; seed_settings "$H" false
mkdir -p "$H/.config/ponytail"
echo '{"defaultMode": "full", "hideStatus": true}' > "$H/.config/ponytail/config.json"
ponytail "$H" --uninstall >/dev/null 2>&1
assert "uninstall sets defaultMode off" 'grep -q "\"defaultMode\": \"off\"" "$H/.config/ponytail/config.json"'
assert "uninstall preserves unrelated keys" 'grep -q "hideStatus" "$H/.config/ponytail/config.json"'

OUT="$(ponytail "$H" --uninstall 2>&1)"
assert "second uninstall is idempotent" 'echo "$OUT" | grep -q "already .off.; config unchanged"'
rm -rf "$H"

echo "=== no dedupe surface ==="

# apply-caveman.sh strips duplicate hooks its upstream installer leaves in
# settings.json. ponytail ships no standalone installer, so this script must not
# grow a dedupe path — and must never write to settings.json at all.
assert "script declares no dedupe flag" '! grep -q -- "--dedupe-only" "$AIKIT/bin/apply-ponytail.sh"'
assert "script never writes settings.json" '! grep -qE "json.dump\(.*SETTINGS|> *\"\$SETTINGS\"" "$AIKIT/bin/apply-ponytail.sh"'

H="$(mktemp -d)"; seed_settings "$H" true yes
BEFORE="$(md5 -q "$H/.claude/settings.json" 2>/dev/null || md5sum "$H/.claude/settings.json" | cut -d' ' -f1)"
ponytail "$H" --mode ultra >/dev/null 2>&1 || true
AFTER="$(md5 -q "$H/.claude/settings.json" 2>/dev/null || md5sum "$H/.claude/settings.json" | cut -d' ' -f1)"
assert "settings.json byte-identical after a mode write" '[ "$BEFORE" = "$AFTER" ]'
assert "mode landed in ponytail's own config" 'grep -q "\"defaultMode\": \"ultra\"" "$H/.config/ponytail/config.json"'
rm -rf "$H"

echo "=== catalog wiring ==="

assert "companions.json entry names the applier" \
  'grep -q "bin/apply-ponytail.sh" "$AIKIT/standards/external/companions.json"'
assert "plugins.json carries ponytail so the ecosystem audit sees it as OWNED" \
  'grep -q "ponytail@ponytail" "$AIKIT/standards/external/plugins.json"'
assert "VETTING.md carries an audit row" \
  'grep -q "ponytail · category=code-discipline" "$AIKIT/standards/external/VETTING.md"'

print_summary_and_exit
