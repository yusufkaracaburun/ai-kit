#!/usr/bin/env bash
# Claude Code SessionStart hook: say when a distilled idea source (today
# mattpocock/skills) has a GitHub release newer than the pin in
# standards/external/vendored.json, with each changed upstream SKILL.md
# classified by bin/ai-kit-upstream-drift.sh.
#
# Only the ai-kit repo carries a `distilled` manifest, so every other project
# stays silent. The check runs at most once per 24 h; the cached result
# (empty when current) serves the sessions in between, so a
# session start costs no network call most of the time and never more than
# the script's two 3 s curl timeouts. A pin bump in the manifest invalidates
# the cache.
#
# Silent by design, like peer-sessions-check.sh: any failure exits 0 with no
# output.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
cwd="$(python3 -c 'import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    d = {}
v = d.get("cwd") if isinstance(d, dict) else None
print(v if isinstance(v, str) else "")' "$payload" 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
manifest="$root/standards/external/vendored.json"
[ -f "$manifest" ] || exit 0
python3 -c 'import json, sys; sys.exit(0 if "distilled" in json.load(open(sys.argv[1])) else 1)' \
  "$manifest" 2>/dev/null || exit 0
# The script comes from this hook's own tree, never from the opened repo.
drift="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/ai-kit-upstream-drift.sh"
[ -x "$drift" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/ai-kit/upstream-release.txt"
if [ -z "$(find "$cache" -mmin -1440 2>/dev/null)" ] || [ ! "$cache" -nt "$manifest" ]; then
  report="$("$drift" --distilled-only "$root" 2>/dev/null)"
  # Unchecked (offline, rate-limited) is not cached, so the next session retries.
  grep -q '^?? ' <<<"$report" && exit 0
  mkdir -p "$(dirname "$cache")" 2>/dev/null || exit 0
  if ! awk '/^-> /{p=1; print; next} /^[^ ]/ || /^$/ {p=0} p && /^   /' <<<"$report" > "$cache.$$" 2>/dev/null \
     || ! command mv -f "$cache.$$" "$cache" 2>/dev/null; then
    command rm -f "$cache.$$"
    exit 0
  fi
fi

notice="$(cat "$cache" 2>/dev/null)"
[ -n "$notice" ] || exit 0

ctx="ai-kit: a new mattpocock/skills release is out. Merge it per #297's pattern: ideas into the mapped skills, never a verbatim resync.
$notice"

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  esc="${ctx//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
