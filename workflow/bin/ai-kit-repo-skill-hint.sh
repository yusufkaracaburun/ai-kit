#!/usr/bin/env bash
# Surface project-scoped hygiene-style skills the user can run separately.
#
# Generic discovery — never bakes repo-specific knowledge into ai-kit.
# If a project keeps its own skills under .agents/skills/, list any that
# match hygiene-style triggers in their description so the hygiene flow
# points at them instead of duplicating their content.
#
# Triggers matched (case-insensitive substring in SKILL.md description):
#   docs-sync, doc-drift, docs-drift, repo-hygiene, housekeep, prune,
#   cleanup, audit
#
# Exit codes:
#   0 — clean (no candidates, or candidates listed as info only)
#
# Report-only. Never invokes anything.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
SKILLS_DIR="$PROJECT_PATH/.agents/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "repo-skill-hint: no .agents/skills/ — skipped."
  exit 0
fi

shopt -s nullglob
hits=()
for d in "$SKILLS_DIR"/*/; do
  skill_file="$d/SKILL.md"
  [ -f "$skill_file" ] || continue
  name="$(basename "$d")"

  desc="$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_file" 2>/dev/null)"
  haystack="$(printf '%s %s' "$name" "$desc" | tr '[:upper:]' '[:lower:]')"

  for needle in docs-sync doc-drift docs-drift repo-hygiene housekeep prune cleanup audit; do
    if printf '%s' "$haystack" | grep -q "$needle"; then
      first_line_desc="$(printf '%s' "$desc" | cut -c1-100)"
      hits+=("$name — $first_line_desc")
      break
    fi
  done
done
shopt -u nullglob

if [ "${#hits[@]}" -eq 0 ]; then
  echo "repo-skill-hint: no project-scoped hygiene skills found."
  exit 0
fi

echo "Project-scoped skills overlap with hygiene scope. Run separately if relevant:"
for h in "${hits[@]}"; do
  echo "  - /$h"
done
echo "(These stay project-local — ai-kit's hygiene won't duplicate their content.)"
exit 0
