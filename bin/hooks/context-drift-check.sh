#!/usr/bin/env bash
# Claude Code PostToolUse hook: nudge when edited code drifts from the docs.
#
# Two trigger code paths, both non-blocking:
#
#   1. Literal-filename match — if the edited file's repo-relative path is
#      referenced in CONTEXT.md, CONTEXT-MAP.md, or docs/adr/*.md, emit a
#      reminder pointing at the doc(s).
#
#   2. Path-pattern match — if the edited path matches one of the
#      stack-aware trigger patterns (e.g. Laravel /app/Models/,
#      /database/migrations/, /app/Policies/, /database/seeders/,
#      /routes/), emit a category-aware reminder ("seeder (mogelijk
#      persona-drift)", "migration (mogelijk stale ref drift)", etc.).
#      Closes the gap that the literal-name match misses — a brand-new
#      model is never named in CONTEXT.md until after it lands.
#
# Both paths can fire on the same edit; messages are concatenated.
#
# Path-pattern triggers come from `.ai-kit/drift-triggers.json` if present
# (project override); otherwise built-in defaults cover Laravel, Rails,
# Next/Node, and Django. Override file shape:
#
#   { "triggers": [ { "pattern": "app/Models/", "category": "model" }, ... ],
#     "messages": { "model": "model wijziging — bijwerk model-doc?", ... } }
#
# Silent no-op when payload empty, edited file unresolvable, or nothing
# matches. Always exits 0 — a hook must never break a session.
#
# Wire it up with bin/apply-context-drift-hook.sh, or by hand in
# .claude/settings.json:
#
#   {
#     "hooks": {
#       "PostToolUse": [{
#         "matcher": "Edit|Write|MultiEdit",
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/context-drift-check.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

# Project root: Claude Code exports CLAUDE_PROJECT_DIR; fall back to cwd.
root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Edited file — Edit, Write and MultiEdit all carry tool_input.file_path.
file_path="$(
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    print(json.loads(sys.stdin.read()).get("tool_input", {}).get("file_path", ""))
except Exception:
    pass' <<<"$payload" 2>/dev/null
  fi
)"
[ -z "$file_path" ] && exit 0

# Repo-relative path: strip the root prefix and any leading "./".
rel="${file_path#"$root"/}"
rel="${rel#./}"
[ -z "$rel" ] && exit 0

messages=()

# ---------------------------------------------------------------------------
# Path 1 — literal-filename match in tracked docs.
# ---------------------------------------------------------------------------
docs=()
for d in "$root/CONTEXT.md" "$root/CONTEXT-MAP.md"; do
  [ -f "$d" ] && docs+=("$d")
done
if [ -d "$root/docs/adr" ]; then
  for d in "$root/docs/adr"/*.md; do
    [ -f "$d" ] && docs+=("$d")
  done
fi

if [ "${#docs[@]}" -gt 0 ]; then
  hits=()
  for d in "${docs[@]}"; do
    if grep -qF "$rel" "$d" 2>/dev/null; then
      hits+=("${d#"$root"/}")
    fi
  done
  if [ "${#hits[@]}" -gt 0 ]; then
    joined="$(IFS=', '; echo "${hits[*]}")"
    messages+=("context-drift: \`${rel}\` is referenced in ${joined}. If this edit changed documented behaviour, update the doc(s) or run /ai:grill-with-docs.")
  fi
fi

# ---------------------------------------------------------------------------
# Path 2 — path-pattern match with per-category reminder text.
#
# Built-in defaults cover the four most common ai-kit consumer stacks. A
# project may override the entire table by dropping a JSON file at
# .ai-kit/drift-triggers.json — when present, the built-ins are skipped
# and only the project entries fire.
# ---------------------------------------------------------------------------

# patterns_categories: parallel arrays of (regex, category-label).
patterns=()
categories=()
# messages_keys / messages_vals: parallel arrays for category → reminder.
messages_keys=()
messages_vals=()

override="$root/.ai-kit/drift-triggers.json"
if [ -f "$override" ] && command -v python3 >/dev/null 2>&1; then
  # Load override via python3 — bash arrays populated from null-delimited
  # output to keep entries with spaces intact.
  while IFS= read -r -d '' pat; do
    IFS= read -r -d '' cat
    patterns+=("$pat")
    categories+=("$cat")
  done < <(python3 -c "
import json, sys
try:
    data = json.load(open('$override'))
except Exception:
    sys.exit(0)
for t in data.get('triggers', []) or []:
    p = t.get('pattern'); c = t.get('category')
    if p and c:
        sys.stdout.write(p + '\0' + c + '\0')
" 2>/dev/null)
  while IFS= read -r -d '' k; do
    IFS= read -r -d '' v
    messages_keys+=("$k")
    messages_vals+=("$v")
  done < <(python3 -c "
import json, sys
try:
    data = json.load(open('$override'))
except Exception:
    sys.exit(0)
for k, v in (data.get('messages') or {}).items():
    if k and v:
        sys.stdout.write(k + '\0' + v + '\0')
" 2>/dev/null)
else
  # Built-in defaults — stack-aware patterns covering the most common
  # consumer stacks. Order matters only insofar as the first match wins
  # per category; categories are independent of each other so multiple
  # categories can match the same edit (rare in practice).

  # Laravel
  patterns+=("app/Models/")         ; categories+=("model")
  patterns+=("app/Policies/")       ; categories+=("policy")
  patterns+=("app/Enums/")          ; categories+=("enum")
  patterns+=("database/migrations/"); categories+=("migration")
  patterns+=("database/seeders/")   ; categories+=("seeder")
  patterns+=("routes/")             ; categories+=("route")
  # Rails
  patterns+=("app/models/")         ; categories+=("model")
  patterns+=("db/migrate/")         ; categories+=("migration")
  patterns+=("db/seeds")            ; categories+=("seeder")
  patterns+=("config/routes")       ; categories+=("route")
  # Next.js / generic Node
  patterns+=("pages/api/")          ; categories+=("route")
  patterns+=("app/api/")            ; categories+=("route")
  # Django
  patterns+=("/models.py")          ; categories+=("model")
  patterns+=("/migrations/")        ; categories+=("migration")
  patterns+=("/urls.py")            ; categories+=("route")

  # Category → reminder template. One per category; multiple patterns
  # may share a category.
  messages_keys+=("model")    ; messages_vals+=("model wijziging — check of bestaande docs (CONTEXT.md / ERD / model-overzicht) bijwerken nodig is")
  messages_keys+=("policy")   ; messages_vals+=("authorisatie-policy aangepast — controleer of permissions-tabel / rollen-doc nog klopt")
  messages_keys+=("enum")     ; messages_vals+=("enum gewijzigd — vaak gebruikt in API-contracts en seeders; verifieer downstream gebruik")
  messages_keys+=("migration"); messages_vals+=("migration aangeraakt — kans op stale schema-refs in docs / fixtures / ERD")
  messages_keys+=("seeder")   ; messages_vals+=("seeder aangepast — mogelijk persona-drift; controleer PII-grep en geanonimiseerde namen")
  messages_keys+=("route")    ; messages_vals+=("route-definitie gewijzigd — routes-overzicht / API-doc mogelijk stale")
fi

# Score the edited path against each pattern. First category-hit per
# category wins (avoid duplicate reminders when multiple patterns share
# a category).
seen_categories=()
contains() {
  local needle="$1"; shift
  local x
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

i=0
while [ "$i" -lt "${#patterns[@]}" ]; do
  pat="${patterns[$i]}"
  cat="${categories[$i]}"
  i=$((i + 1))
  case "$rel" in
    *"$pat"*)
      if ! contains "$cat" "${seen_categories[@]:-}"; then
        seen_categories+=("$cat")
        # Lookup message for category.
        msg=""
        j=0
        while [ "$j" -lt "${#messages_keys[@]}" ]; do
          if [ "${messages_keys[$j]}" = "$cat" ]; then
            msg="${messages_vals[$j]}"
            break
          fi
          j=$((j + 1))
        done
        [ -z "$msg" ] && msg="drift-nudge (${cat}) — controleer of documentatie nog klopt"
        messages+=("context-drift (${cat}): \`${rel}\` — ${msg}.")
      fi
      ;;
  esac
done

[ "${#messages[@]}" -eq 0 ] && exit 0

# Concatenate with blank lines between distinct findings.
final_msg=""
for m in "${messages[@]}"; do
  if [ -z "$final_msg" ]; then
    final_msg="$m"
  else
    final_msg+=$'\n\n'"$m"
  fi
done

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$final_msg" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
else
  # Hand-rolled JSON fallback — escape backslashes, double quotes, newlines.
  esc="${final_msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
