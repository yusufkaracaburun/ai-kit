#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/emitter-lib.sh
source "$AIKIT/bin/lib/emitter-lib.sh"
# shellcheck source=lib/recommend-lib.sh
source "$AIKIT/bin/lib/recommend-lib.sh"

usage() {
  cat <<EOF
Usage: $0 <project> [--json]

Score canonical rules in standards/rules/ for relevance to a project.
Reads detect-tooling.sh output (frameworks, architecture) + git history
(repo age) and applies the scoring rules in bin/lib/recommend-lib.sh.

Output: ranked table (default) or JSON.

For web-search-augmented recommendations (stack-specific community rules),
invoke /recommend-rules as a skill from your AI agent — the skill calls
this script for canonical scoring, then layers a search step on top.
EOF
  exit 1
}

JSON=false
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=true; shift ;;
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

ROWS="$(recommend_rules "$AIKIT" "$PROJECT")"

if [ "$JSON" = true ]; then
  printf '%s' "$ROWS" | python3 -c '
import json, sys
rules = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    parts = line.split("\t", 3)
    if len(parts) < 4:
        continue
    name, score, weight, reason = parts
    rules.append({"name": name, "score": int(score), "weight": weight, "reason": reason})
print(json.dumps({"recommendations": rules}, indent=2))
'
  exit 0
fi

printf "%-20s %5s  %-7s  %s\n" "Rule" "Score" "Weight" "Reason"
printf "%-20s %5s  %-7s  %s\n" "----" "-----" "------" "------"
# Trailing newline ensures the final row is read (command substitution strips them).
printf "%s\n" "$ROWS" | while IFS=$'\t' read -r name score weight reason; do
  [ -z "$name" ] && continue
  printf "%-20s %5s  %-7s  %s\n" "$name" "$score" "$weight" "$reason"
done
