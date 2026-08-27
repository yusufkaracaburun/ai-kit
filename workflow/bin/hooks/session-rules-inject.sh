#!/usr/bin/env bash
# Claude Code SessionStart hook: inject a project's always-on rules into
# context. Closes the enforcement gap in issue #144 — `default_mode:
# always-on` is real on Cursor (alwaysApply: true) but was inert on Claude
# Code (a comment in .claude/rules/<name>.md nothing read back).
#
# Selection (all four gates must pass):
#   1. Project already emitted the rule — only files under .claude/rules/
#      are considered. A project that never ran bin/emit-rules.sh gets
#      nothing injected.
#   2. The emitted file's own header records "Mode: always-on" (today's
#      emit-time value — a rule re-emitted with --mode on-demand drops out
#      without needing this hook to change).
#   3. The rule's SOURCE frontmatter (standards/rules/**/*.mini.md, resolved
#      by name) carries weight: high. Medium/low universal rules stay
#      on-demand-only here; Cursor still enforces them regardless.
#   4. Budget: candidates are added smallest word-count first — weight
#      already ranks importance, size is the only signal left to decide who
#      fits — until the next one would push the running total over
#      $MAX_WORDS. The rest stay out; nothing is deleted, they are still
#      readable on demand in .claude/rules/.
#
# $MAX_WORDS mirrors the order of magnitude bin/ai-kit-context-lean.sh
# already tolerates for a root CLAUDE.md/AGENTS.md (200 lines ~ 2k words) —
# this hook does not open a second, bigger always-loaded budget. `--report`
# prints "rules=N words=W" instead of hook JSON, so
# bin/ai-kit-context-lean.sh (and tests) can check the real budget without
# duplicating the selection above.
#
# Opt-out (machine-wide, no uninstall needed):
#   bin/ai-kit-no-rule-injection.sh on
#
# Silent by design — a hook must never break a session. Any missing/
# malformed input (no .claude/rules, no standards/rules, unreadable rule
# file, missing weight) drops that candidate rather than erroring.
#
# Wired via workflow/hooks/hooks.json (plugin install). Source layout, by
# hand in .claude/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/bin/hooks/session-rules-inject.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

# Overridable for tests only (tests/bin/cases/session-rules-inject.sh) — not
# a documented user-facing knob.
MAX_WORDS="${AI_KIT_SESSION_RULES_MAX_WORDS:-2000}"
OPT_OUT_FILE="${HOME}/.config/ai-kit/no-rule-injection"

# Read + discard stdin (Claude Code passes a session payload; we don't need
# any field from it — the project root comes from $CLAUDE_PROJECT_DIR like
# every other ai-kit hook).
# Only drain when stdin is a pipe. A bare `cat` blocks forever on a tty
# waiting for an EOF that never arrives — and this is a SessionStart hook, so
# a hang here stalls the user's session start, not just this script. Reached
# by anyone running the hook by hand to diagnose it.
if [ ! -t 0 ]; then
  cat >/dev/null 2>&1 || true
fi

REPORT=false
[ "${1:-}" = "--report" ] && REPORT=true

report() {
  $REPORT && echo "rules=$1 words=$2${3:+ ($3)}"
}

if [ -f "$OPT_OUT_FILE" ]; then
  report 0 0 "opt-out active: $OPT_OUT_FILE"
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
rules_dir="$root/.claude/rules"
if [ ! -d "$rules_dir" ]; then
  report 0 0 "no .claude/rules in project"
  exit 0
fi

# Locate the standards/rules/ this hook ships alongside, to read a
# candidate's source `weight`. Two layouts, same fallback as
# hooks/post-skill-log.sh: sibling (plugin — workflow/hooks/ +
# workflow/standards/) or one dir up (source — bin/hooks/ + standards/, via
# bin/../standards).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || true)"
STANDARDS_DIR=""
for cand in "$HOOK_DIR/../standards" "$HOOK_DIR/../../standards"; do
  if [ -d "$cand/rules" ]; then
    STANDARDS_DIR="$cand"
    break
  fi
done
if [ -z "$STANDARDS_DIR" ]; then
  report 0 0 "no standards/rules found"
  exit 0
fi

extract_weight() {
  awk '
    BEGIN { in_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm && $1 == "weight:" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }
  ' "$1" 2>/dev/null
}

resolve_source() {
  local name="$1" dir ext
  for dir in "$STANDARDS_DIR/rules" "$STANDARDS_DIR/rules/feedback"; do
    for ext in mini.md nano.md; do
      if [ -f "$dir/${name}.${ext}" ]; then
        echo "$dir/${name}.${ext}"
        return 0
      fi
    done
  done
  return 1
}

# Candidates: parallel arrays (name, word-count, body). Only rules the
# project itself emitted as always-on, resolvable to a high-weight source.
names=()
words=()
bodies=()
for f in "$rules_dir"/*.md; do
  [ -f "$f" ] || continue
  head -2 "$f" 2>/dev/null | grep -q "Mode: always-on" || continue

  name="$(basename "$f" .md)"
  src="$(resolve_source "$name")" || continue
  [ -n "$src" ] || continue
  [ "$(extract_weight "$src")" = "high" ] || continue

  body="$(tail -n +4 "$f" 2>/dev/null)"
  [ -n "$body" ] || continue

  names+=("$name")
  words+=("$(printf '%s' "$body" | wc -w | tr -d ' ')")
  bodies+=("$body")
done

if [ "${#names[@]}" -eq 0 ]; then
  report 0 0
  exit 0
fi

# Smallest word-count first, so the budget below fits as many high-weight
# rules as it can rather than being decided by filename or file order.
order=()
while IFS= read -r idx; do
  order+=("$idx")
done < <(for i in "${!names[@]}"; do printf '%s %s\n' "${words[$i]}" "$i"; done | sort -n -k1 | awk '{print $2}')

total=0
sel_names=()
sel_bodies=()
for i in "${order[@]}"; do
  w="${words[$i]}"
  next_total=$((total + w))
  [ "$next_total" -gt "$MAX_WORDS" ] && break
  total="$next_total"
  sel_names+=("${names[$i]}")
  sel_bodies+=("${bodies[$i]}")
done

report "${#sel_names[@]}" "$total" "of ${#names[@]} candidates, cap ${MAX_WORDS}"
$REPORT && exit 0

[ "${#sel_names[@]}" -eq 0 ] && exit 0

ctx="ai-kit: the following project rules are always-on (enforced) — same standing as Cursor's alwaysApply, treat them as binding for this session:"
for i in "${!sel_names[@]}"; do
  ctx+=$'\n\n---\n'"# ${sel_names[$i]}"$'\n\n'"${sel_bodies[$i]}"
done

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
