#!/usr/bin/env bash
# Dump a skill's fixture prompt + SKILL.md + a rating template to stdout, for
# pasting into Claude/Cursor and rating the output by hand.
# Not used by CI — eval-structure.sh handles the deterministic checks.

set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  echo "Usage: $0 <skill> [<scenario>]" >&2
  echo "" >&2
  echo "Available scenarios per skill:" >&2
  for d in "$AIKIT/tests/eval/prompts"/*/; do
    [ -d "$d" ] || continue
    s="$(basename "$d")"
    echo "  $s:" >&2
    for f in "$d"*.md; do
      [ -f "$f" ] || continue
      echo "    - $(basename "$f" .md)" >&2
    done
  done
  exit 2
}

if [ $# -lt 1 ]; then usage; fi

SKILL="$1"
SCENARIO="${2:-}"

skill_dir="$AIKIT/workflow/skills/$SKILL"
fx_dir="$AIKIT/tests/eval/prompts/$SKILL"

if [ ! -f "$skill_dir/SKILL.md" ]; then
  echo "No skill at $skill_dir" >&2
  exit 1
fi
if [ ! -d "$fx_dir" ]; then
  echo "No fixtures for skill '$SKILL'. Create $fx_dir/<scenario>.md to add one." >&2
  exit 1
fi

if [ -z "$SCENARIO" ]; then
  # Pick the first fixture if not specified.
  first="$(find "$fx_dir" -maxdepth 1 -name '*.md' -type f | sort | head -1)"
  if [ -z "$first" ]; then
    echo "No fixtures in $fx_dir" >&2
    exit 1
  fi
  SCENARIO="$(basename "$first" .md)"
fi

fx_file="$fx_dir/$SCENARIO.md"
if [ ! -f "$fx_file" ]; then
  echo "No fixture at $fx_file" >&2
  exit 1
fi

today="$(date +%Y-%m-%d)"

cat <<EOF
=== FIXTURE: $SKILL / $SCENARIO ===
EOF
cat "$fx_file"

cat <<EOF

=== SKILL: workflow/skills/$SKILL/SKILL.md ===
EOF
cat "$skill_dir/SKILL.md"

cat <<EOF

=== RATING TEMPLATE — paste into tests/eval/results/${today}-${SKILL}-${SCENARIO}.md ===

---
id: $SCENARIO
skill: $SKILL
date: $today
agent: <claude-code | cursor | other>
verdict: <pass | partial | fail>
---

## Checklist

EOF

awk '/^expects:/{flag=1; next} /^[A-Za-z_]+:/{flag=0} flag && /^[[:space:]]+- /{
  sub(/^[[:space:]]+- /, "");
  print "- [ ] " $0
}' "$fx_file"

cat <<EOF

## Notes

<what was good, what surprised you, what to change in the skill>
EOF
