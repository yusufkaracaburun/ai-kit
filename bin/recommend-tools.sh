#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/recommend-tools-lib.sh
source "$AIKIT/bin/lib/recommend-tools-lib.sh"

usage() {
  cat <<EOF
Usage: $0 <project> [--json] [--kind mcp|hook|all]

Score MCP servers + Claude Code hook recipes (from
standards/external/{mcp-servers,hooks-patterns}.json) for relevance to a
target project. Detection runs via bin/detect-tooling.sh; file-presence
signals are checked against the project root.

Output: ranked table (default) or JSON. Filter kind with --kind.

This is the deterministic scorer. The /ai:recommend-tools skill
invokes it for stack-specific MCP + hook suggestions, then surfaces the
results to the user with the same trust model as /ai:recommend-rules.
EOF
  exit 1
}

JSON=false
KIND="all"
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=true; shift ;;
    --kind)
      [ $# -ge 2 ] || usage
      KIND="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *)
      if [ -n "$PROJECT" ]; then echo "Unexpected: $1" >&2; usage; fi
      PROJECT="$1"; shift ;;
  esac
done

[ -z "$PROJECT" ] && usage
[ -d "$PROJECT" ] || { echo "Project not found: $PROJECT" >&2; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"

case "$KIND" in
  all|mcp|hook) ;;
  *) echo "--kind must be mcp|hook|all" >&2; exit 2 ;;
esac

ROWS="$(recommend_tools_external "$AIKIT" "$PROJECT")"

# Filter by kind when not "all". Rows: name<TAB>score<TAB>category<TAB>kind<TAB>reason.
if [ "$KIND" != "all" ]; then
  ROWS="$(printf "%s\n" "$ROWS" | awk -F'\t' -v k="$KIND" '$4==k')"
fi

if [ "$JSON" = true ]; then
  printf '%s' "$ROWS" | python3 -c '
import json, sys
items = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    parts = line.split("\t", 4)
    if len(parts) < 5:
        continue
    name, score, category, kind, reason = parts
    items.append({"name": name, "score": int(score), "category": category, "kind": kind, "reason": reason})
print(json.dumps({"recommendations": items}, indent=2))
'
  exit 0
fi

printf "%-22s %5s  %-14s  %-4s  %s\n" "Tool" "Score" "Category" "Kind" "Reason"
printf "%-22s %5s  %-14s  %-4s  %s\n" "----" "-----" "--------" "----" "------"
printf "%s\n" "$ROWS" | while IFS=$'\t' read -r name score category kind reason; do
  [ -z "$name" ] && continue
  printf "%-22s %5s  %-14s  %-4s  %s\n" "$name" "$score" "$category" "$kind" "$reason"
done
